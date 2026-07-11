import ActivityKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let pluginManager: MobilePluginManager

    @Published private(set) var profile: ClassIslandProfile?
    @Published private(set) var profileFileName = ""
    @Published private(set) var currentSnapshot: ScheduleSnapshot?
    @Published private(set) var statusMessage = ""
    @Published private(set) var activityStatus = "尚未启动"
    @Published private(set) var weather: WeatherSnapshot?
    @Published private(set) var weatherStatusMessage = ""
    @Published private(set) var isRefreshingWeather = false
    @Published private(set) var weatherCitySearchResults: [WeatherCity] = []
    @Published private(set) var weatherCitySearchMessage = ""
    @Published private(set) var isSearchingWeatherCities = false
    @Published var settings: MobileSettings {
        didSet {
            guard hasBootstrapped else { return }
            let weatherSelectionChanged = oldValue.weatherCityID != settings.weatherCityID
            let weatherEnabledChanged = oldValue.weatherEnabled != settings.weatherEnabled
            if weatherSelectionChanged {
                weather = nil
                nextWeatherRefreshDate = .distantPast
            }
            persistSettings()
            Task {
                if settings.weatherEnabled && (weatherSelectionChanged || weatherEnabledChanged) {
                    await refreshCurrentSchedule()
                    await refreshWeather(force: true)
                } else {
                    await refreshCurrentSchedule()
                }
            }
        }
    }

    private let repository: MobileRepository
    private let engine: ScheduleEngine
    private let liveActivityController: LiveActivityController
    private let weatherService: WeatherService
    private var hasBootstrapped = false
    private var profileSourceData: Data?
    private var monitorTask: Task<Void, Never>?
    private var boundaryRefreshTask: Task<Void, Never>?
    private var scheduledBoundaryDate: Date?
    private var lastActivitySignature: ActivitySignature?
    private var scheduledRefreshDate: Date?
    private var hasReconciledBackgroundRefresh = false
    private var nextWeatherRefreshDate = Date.distantPast
    private var weatherCitySearchToken = UUID()
    private var weatherRefreshPending = false
    private var pluginScheduleCheckpoint: MobilePluginScheduleCheckpoint?

    private static let weatherRefreshInterval: TimeInterval = 15 * 60
    private static let weatherRetryInterval: TimeInterval = 5 * 60

    init(
        repository: MobileRepository = MobileRepository(),
        engine: ScheduleEngine = ScheduleEngine(),
        liveActivityController: LiveActivityController? = nil,
        weatherService: WeatherService = WeatherService(),
        pluginManager: MobilePluginManager? = nil
    ) {
        self.repository = repository
        self.engine = engine
        self.liveActivityController = liveActivityController ?? .shared
        self.weatherService = weatherService
        self.pluginManager = pluginManager ?? MobilePluginManager()
        settings = MobileSettings()
    }

    deinit {
        monitorTask?.cancel()
        boundaryRefreshTask?.cancel()
    }

    func bootstrap() async {
        await pluginManager.bootstrap()
        loadPersistedDataIfNeeded()
        await refreshCurrentSchedule()
        await refreshWeather(force: false)
        await pluginManager.dispatch(event: .appActive, context: pluginContext())
        await refreshCurrentSchedule()
        if monitorTask == nil {
            startMonitor()
        }
    }

    func handleAppActive() async {
        await pluginManager.bootstrap()
        await refreshCurrentSchedule()
        await refreshWeather(force: false, synchronizeActivity: false)
        await refreshCurrentSchedule()
        await pluginManager.dispatch(event: .appActive, context: pluginContext())
        await refreshCurrentSchedule()
    }

    func handleBackgroundRefresh() async {
        scheduledRefreshDate = nil
        hasReconciledBackgroundRefresh = false
        await pluginManager.bootstrap()
        loadPersistedDataIfNeeded()
        await refreshCurrentSchedule(
            allowStartingActivity: false,
            awaitPluginEvents: true
        )
        await refreshWeather(
            force: false,
            synchronizeActivity: false,
            awaitPluginEvents: true
        )
        await refreshCurrentSchedule(
            allowStartingActivity: false,
            awaitPluginEvents: true
        )
    }

    private func loadPersistedDataIfNeeded() {
        guard !hasBootstrapped else { return }
        var startupMessages: [String] = []
        do {
            settings = try repository.loadSettings() ?? MobileSettings()
        } catch {
            settings = MobileSettings()
            startupMessages.append("读取移动端设置失败，已恢复默认值：\(error.localizedDescription)")
        }
        do {
            if let data = try repository.loadProfileData() {
                profile = try decodeProfile(data)
                profileSourceData = data
                profileFileName = "Profile.json"
            }
        } catch {
            profile = nil
            profileFileName = ""
            startupMessages.append("读取本地课表失败：\(error.localizedDescription)")
        }
        do {
            if let cachedWeather = try repository.loadWeather(),
               cachedWeather.city.id == settings.weatherCityID {
                weather = cachedWeather
                nextWeatherRefreshDate = cachedWeather.fetchedAt.addingTimeInterval(
                    Self.weatherRefreshInterval
                )
            }
        } catch {
            weatherStatusMessage = "读取天气缓存失败：\(error.localizedDescription)"
        }
        do {
            pluginScheduleCheckpoint = try repository.loadPluginScheduleCheckpoint()
        } catch {
            pluginScheduleCheckpoint = nil
            startupMessages.append("读取插件事件状态失败：\(error.localizedDescription)")
        }
        hasBootstrapped = true
        statusMessage = startupMessages.joined(separator: "\n")
    }

    func snapshot(for date: Date, now: Date = Date()) -> ScheduleSnapshot? {
        guard let profile else { return nil }
        return engine.snapshot(profile: profile, settings: settings, at: now, for: date)
    }

    func importDocument(_ url: URL) async {
        if url.pathExtension.caseInsensitiveCompare("cipx") == .orderedSame {
            await pluginManager.prepareInstallation(from: url)
            return
        }

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = json as? [String: Any] else {
                throw ImportError.unsupportedDocument
            }

            if dictionary["ClassPlans"] != nil,
               dictionary["TimeLayouts"] != nil,
               dictionary["Subjects"] != nil {
                let decoded = try decodeProfile(data)
                try repository.saveProfileData(data)
                if profile?.id != decoded.id {
                    pluginScheduleCheckpoint = nil
                    try? repository.savePluginScheduleCheckpoint(nil)
                }
                profile = decoded
                profileSourceData = data
                profileFileName = url.lastPathComponent
                statusMessage = "已导入课表：\(url.lastPathComponent)"
                await refreshCurrentSchedule()
                return
            }

            if dictionary["SingleWeekStartTime"] != nil
                || dictionary["MultiWeekRotationOffset"] != nil
                || dictionary["MultiWeekRotationMaxCycle"] != nil
                || dictionary["Theme"] != nil
                || dictionary["ColorSource"] != nil
                || dictionary["PrimaryColor"] != nil
                || dictionary["SelectedPlatte"] != nil
                || dictionary["ShowCurrentLessonOnlyOnClass"] != nil
                || dictionary["TimeOffsetSeconds"] != nil
                || dictionary["CityId"] != nil
                || dictionary["CityName"] != nil {
                let windowsSettings = try JSONDecoder().decode(ClassIslandWindowsSettings.self, from: data)
                apply(windowsSettings)
                statusMessage = "已导入 Windows 应用设置"
                return
            }

            throw ImportError.unsupportedDocument
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func loadSampleProfile() async {
        guard let url = Bundle.main.url(forResource: "SampleProfile", withExtension: "json") else {
            statusMessage = "未找到示例课表"
            return
        }
        await importDocument(url)
    }

    @discardableResult
    func createProfile(named name: String) async -> Bool {
        await persistProfile(
            ClassIslandProfile.newProfile(name: name),
            preserving: nil,
            successMessage: "已创建新档案"
        )
    }

    @discardableResult
    func saveProfile(_ updated: ClassIslandProfile) async -> Bool {
        await persistProfile(
            updated,
            preserving: profileSourceData,
            successMessage: "档案已保存"
        )
    }

    func profileDocumentData() throws -> Data {
        guard let profile else { throw ImportError.noProfile }
        return try ProfileDocumentCodec.encode(profile, preserving: profileSourceData)
    }

    func removeProfile() async {
        do {
            try repository.removeProfile()
            profile = nil
            profileSourceData = nil
            profileFileName = ""
            currentSnapshot = nil
            pluginScheduleCheckpoint = nil
            try? repository.savePluginScheduleCheckpoint(nil)
            lastActivitySignature = nil
            reconcileForegroundRefresh(snapshot: nil, now: Date())
            await liveActivityController.endAll()
            reconcileBackgroundRefresh(snapshot: nil, now: Date())
            activityStatus = "已停止"
            statusMessage = "本机课表已删除"
        } catch {
            statusMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func refreshCurrentSchedule(
        now: Date = Date(),
        allowStartingActivity: Bool = true,
        awaitPluginEvents: Bool = false
    ) async {
        guard let profile else {
            currentSnapshot = nil
            if pluginScheduleCheckpoint != nil {
                pluginScheduleCheckpoint = nil
                try? repository.savePluginScheduleCheckpoint(nil)
            }
            reconcileForegroundRefresh(snapshot: nil, now: now)
            let signature = ActivitySignature(
                snapshot: nil,
                settings: settings,
                weather: activityWeather,
                plugin: nil
            )
            if signature != lastActivitySignature {
                await liveActivityController.endAll()
                lastActivitySignature = signature
            }
            reconcileBackgroundRefresh(snapshot: nil, now: now)
            activityStatus = "等待导入课表"
            return
        }

        let snapshot = engine.snapshot(profile: profile, settings: settings, at: now)
        currentSnapshot = snapshot
        let checkpoint = MobilePluginScheduleCheckpoint(snapshot: snapshot)
        let previousCheckpoint = pluginScheduleCheckpoint
        let pluginEvent = scheduleTransitionEvent(from: previousCheckpoint, to: checkpoint)
        pluginScheduleCheckpoint = checkpoint
        reconcileForegroundRefresh(snapshot: snapshot, now: now)
        let pluginPresentation = pluginManager.activityPresentation(
            context: pluginContext(schedule: snapshot, now: now)
        )
        let signature = ActivitySignature(
            snapshot: snapshot,
            settings: settings,
            weather: activityWeather,
            plugin: pluginPresentation
        )
        if signature != lastActivitySignature {
            do {
                let synchronized = try await liveActivityController.synchronize(
                    snapshot: snapshot,
                    settings: settings,
                    weather: activityWeather,
                    plugin: pluginPresentation,
                    now: now,
                    allowStarting: allowStartingActivity
                )
                if synchronized {
                    lastActivitySignature = signature
                }
                activityStatus = Activity<ScheduleActivityAttributes>.activities.isEmpty ? "未显示" : "正在显示"
            } catch {
                activityStatus = "不可用"
                statusMessage = error.localizedDescription
            }
        }
        reconcileBackgroundRefresh(snapshot: snapshot, now: now)
        if let pluginEvent {
            let context = pluginContext(schedule: snapshot, now: now)
            if awaitPluginEvents {
                await pluginManager.dispatch(event: pluginEvent, context: context)
                try? repository.savePluginScheduleCheckpoint(checkpoint)
                await refreshCurrentSchedule(
                    allowStartingActivity: allowStartingActivity,
                    awaitPluginEvents: true
                )
            } else {
                Task { [weak self] in
                    guard let self else { return }
                    await self.pluginManager.dispatch(event: pluginEvent, context: context)
                    try? self.repository.savePluginScheduleCheckpoint(checkpoint)
                    await self.refreshCurrentSchedule()
                }
            }
        } else if previousCheckpoint != checkpoint {
            try? repository.savePluginScheduleCheckpoint(checkpoint)
        }
    }

    func stopLiveActivity() async {
        settings.liveActivitiesEnabled = false
        await liveActivityController.endAll()
        lastActivitySignature = ActivitySignature(
            snapshot: currentSnapshot,
            settings: settings,
            weather: activityWeather,
            plugin: pluginManager.activityPresentation(context: pluginContext())
        )
        reconcileBackgroundRefresh(snapshot: currentSnapshot, now: Date())
        activityStatus = "已停止"
    }

    func setRotationOffset(_ value: Int, for cycle: Int) {
        var updated = settings
        updated.setRotationOffset(value, for: cycle)
        settings = updated
    }

    func setAccent(_ accent: AccentPreference) {
        var updated = settings
        updated.accent = accent
        updated.importedAccentHex = nil
        settings = updated
    }

    func refreshWeather(
        force: Bool = true,
        synchronizeActivity: Bool = true,
        allowStartingActivity: Bool = true,
        awaitPluginEvents: Bool = false
    ) async {
        guard settings.weatherEnabled else {
            if synchronizeActivity {
                await refreshCurrentSchedule(allowStartingActivity: allowStartingActivity)
            }
            return
        }
        if isRefreshingWeather {
            weatherRefreshPending = weatherRefreshPending || force
            return
        }
        let now = Date()
        guard force || now >= nextWeatherRefreshDate else { return }

        let requestedCityID = settings.weatherCityID
        isRefreshingWeather = true
        defer {
            isRefreshingWeather = false
            if weatherRefreshPending {
                weatherRefreshPending = false
                Task { await self.refreshWeather(force: true) }
            }
        }

        do {
            let updatedWeather = try await weatherService.fetchWeather(
                cityID: requestedCityID,
                fetchedAt: now
            )
            guard settings.weatherEnabled,
                  settings.weatherCityID == requestedCityID else {
                weatherRefreshPending = settings.weatherEnabled
                return
            }

            weather = updatedWeather
            nextWeatherRefreshDate = now.addingTimeInterval(Self.weatherRefreshInterval)
            var updatedSettings = settings
            updatedSettings.weatherCityName = updatedWeather.city.displayName
            if updatedSettings != settings {
                settings = updatedSettings
            }
            do {
                try repository.saveWeather(updatedWeather)
                weatherStatusMessage = "天气已更新：\(updatedWeather.city.displayName)"
            } catch {
                weatherStatusMessage = "天气已更新，但缓存保存失败：\(error.localizedDescription)"
            }
            let context = pluginContext(now: now)
            if awaitPluginEvents {
                await pluginManager.dispatch(event: .weatherUpdated, context: context)
            } else {
                Task { [weak self] in
                    guard let self else { return }
                    await self.pluginManager.dispatch(event: .weatherUpdated, context: context)
                    await self.refreshCurrentSchedule()
                }
            }
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                return
            }
            nextWeatherRefreshDate = now.addingTimeInterval(Self.weatherRetryInterval)
            weatherStatusMessage = weather == nil
                ? "天气更新失败：\(error.localizedDescription)"
                : "天气更新失败，继续显示上次结果：\(error.localizedDescription)"
        }

        if synchronizeActivity {
            await refreshCurrentSchedule(allowStartingActivity: allowStartingActivity)
        }
    }

    func searchWeatherCities(query: String) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchToken = UUID()
        weatherCitySearchToken = searchToken
        isSearchingWeatherCities = true
        weatherCitySearchMessage = ""
        defer {
            if weatherCitySearchToken == searchToken {
                isSearchingWeatherCities = false
            }
        }

        do {
            let cities = try await weatherService.searchCities(matching: normalizedQuery)
            guard !Task.isCancelled, weatherCitySearchToken == searchToken else { return }
            weatherCitySearchResults = cities
            if cities.isEmpty {
                weatherCitySearchMessage = normalizedQuery.isEmpty ? "暂无热门城市" : "未找到相关城市"
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, weatherCitySearchToken == searchToken else { return }
            weatherCitySearchResults = []
            weatherCitySearchMessage = "城市搜索失败：\(error.localizedDescription)"
        }
    }

    func clearWeatherCitySearch() {
        weatherCitySearchToken = UUID()
        weatherCitySearchResults = []
        weatherCitySearchMessage = ""
        isSearchingWeatherCities = false
    }

    func selectWeatherCity(_ city: WeatherCity) {
        var updated = settings
        updated.weatherCityID = city.id
        updated.weatherCityName = city.displayName
        settings = updated
        clearWeatherCitySearch()
    }

    private var activityWeather: WeatherPresentation? {
        guard settings.weatherEnabled,
              let weather,
              weather.city.id == settings.weatherCityID else {
            return nil
        }
        return weather.presentation
    }

    private func pluginContext(
        schedule: ScheduleSnapshot? = nil,
        now: Date = Date()
    ) -> MobilePluginRuntimeContext {
        MobilePluginRuntimeContext(
            now: now,
            schedule: schedule ?? currentSnapshot,
            weather: weather
        )
    }

    private func scheduleTransitionEvent(
        from previous: MobilePluginScheduleCheckpoint?,
        to current: MobilePluginScheduleCheckpoint
    ) -> MobilePluginEventName? {
        guard let previous else { return nil }
        return if current.phase == .inClass,
                  previous.phase != .inClass
                    || previous.date != current.date
                    || previous.currentSessionID != current.currentSessionID {
            .scheduleClassStarted
        } else if current.phase == .breakTime,
                  previous.phase != .breakTime
                    || previous.date != current.date
                    || previous.currentBreakID != current.currentBreakID {
            .scheduleBreakStarted
        } else if current.phase == .afterSchool, previous.phase != .afterSchool {
            .scheduleAfterSchool
        } else {
            nil
        }
    }

    private func decodeProfile(_ data: Data) throws -> ClassIslandProfile {
        let decoded = try JSONDecoder().decode(ClassIslandProfile.self, from: data)
        guard !decoded.classPlans.isEmpty,
              !decoded.timeLayouts.isEmpty,
              !decoded.subjects.isEmpty else {
            throw ImportError.incompleteProfile
        }
        return decoded
    }

    private func persistProfile(
        _ updated: ClassIslandProfile,
        preserving originalData: Data?,
        successMessage: String
    ) async -> Bool {
        do {
            let data = try ProfileDocumentCodec.encode(updated, preserving: originalData)
            let decoded = try decodeProfile(data)
            try repository.saveProfileData(data)
            if profile?.id != decoded.id {
                pluginScheduleCheckpoint = nil
                try? repository.savePluginScheduleCheckpoint(nil)
            }
            profileSourceData = data
            profile = decoded
            profileFileName = "Profile.json"
            lastActivitySignature = nil
            statusMessage = successMessage
            await refreshCurrentSchedule()
            return true
        } catch {
            statusMessage = "保存档案失败：\(error.localizedDescription)"
            return false
        }
    }

    private func apply(_ windowsSettings: ClassIslandWindowsSettings) {
        var updated = settings
        if let value = windowsSettings.singleWeekStartTime,
           let date = ClassIslandDateParser.date(from: value) {
            updated.singleWeekStartTime = date
        }
        if let maxCycle = windowsSettings.multiWeekRotationMaxCycle {
            updated.maxRotationCycle = min(max(maxCycle, 2), 12)
        }
        if let offsets = windowsSettings.multiWeekRotationOffset, offsets.count >= 2 {
            updated.rotationOffsets = offsets
            if offsets.count > 2 {
                for cycle in 2..<offsets.count {
                    updated.setRotationOffset(offsets[cycle], for: cycle)
                }
            }
        }
        if let theme = windowsSettings.theme {
            updated.appearance = switch theme {
            case 1: .light
            case 2: .dark
            default: .system
            }
        }
        if let colorSource = windowsSettings.colorSource {
            switch colorSource {
            case 0:
                updated.importedAccentHex = windowsSettings.primaryColor
            case 1, 3:
                updated.importedAccentHex = windowsSettings.selectedPalette ?? windowsSettings.primaryColor
            case 2:
                updated.importedAccentHex = nil
            default:
                break
            }
        } else if let primaryColor = windowsSettings.primaryColor {
            updated.importedAccentHex = primaryColor
        }
        if let showCurrent = windowsSettings.showCurrentLessonOnlyOnClass {
            updated.showCurrentLessonOnlyOnClass = showCurrent
        }
        if let timeOffsetSeconds = windowsSettings.timeOffsetSeconds {
            updated.timeOffsetSeconds = MobileSettings.clampedTimeOffset(timeOffsetSeconds)
        }
        if let cityID = windowsSettings.cityID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cityID.isEmpty {
            updated.weatherCityID = cityID
        }
        if let cityName = windowsSettings.cityName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cityName.isEmpty {
            updated.weatherCityName = cityName
        }
        settings = updated
    }

    private func persistSettings() {
        do {
            try repository.saveSettings(settings)
        } catch {
            statusMessage = "保存设置失败：\(error.localizedDescription)"
        }
    }

    private func reconcileBackgroundRefresh(snapshot: ScheduleSnapshot?, now: Date) {
        let hasActiveActivity = !Activity<ScheduleActivityAttributes>.activities.isEmpty
        let scheduleTargetDate = snapshot.flatMap {
            ScheduleRefreshPolicy.earliestBeginDate(
                for: $0,
                settings: settings,
                hasActiveActivity: hasActiveActivity,
                now: now
            )
        }
        let weatherTargetDate = settings.weatherEnabled && hasActiveActivity
            ? max(nextWeatherRefreshDate, now.addingTimeInterval(1))
            : nil
        let targetDate = [scheduleTargetDate, weatherTargetDate]
            .compactMap { $0 }
            .min()

        if let targetDate {
            guard !hasReconciledBackgroundRefresh || scheduledRefreshDate != targetDate else { return }
            hasReconciledBackgroundRefresh = true
            scheduledRefreshDate = targetDate
            try? ScheduleRefreshScheduler.submit(earliestBeginDate: targetDate)
        } else {
            guard !hasReconciledBackgroundRefresh || scheduledRefreshDate != nil else { return }
            hasReconciledBackgroundRefresh = true
            scheduledRefreshDate = nil
            ScheduleRefreshScheduler.cancel()
        }
    }

    private func reconcileForegroundRefresh(snapshot: ScheduleSnapshot?, now: Date) {
        let boundary = snapshot?.nextBoundary
        guard boundary != scheduledBoundaryDate else { return }

        boundaryRefreshTask?.cancel()
        boundaryRefreshTask = nil
        scheduledBoundaryDate = boundary

        guard let snapshot,
              let boundary,
              let refreshDate = ScheduleRefreshPolicy.foregroundRefreshDate(
                  for: snapshot,
                  now: now
              ) else { return }
        let delay = max(refreshDate.timeIntervalSince(now), 0)
        boundaryRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            guard self.scheduledBoundaryDate == boundary else { return }
            self.scheduledBoundaryDate = nil
            self.boundaryRefreshTask = nil
            await self.refreshCurrentSchedule()
        }
    }

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshCurrentSchedule()
                await self?.refreshWeather(force: false, synchronizeActivity: false)
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }
}

private struct ActivitySignature: Equatable {
    let phase: SchedulePhase?
    let profileName: String?
    let current: ScheduleSession?
    let currentBreak: ScheduleBreak?
    let next: ScheduleSession?
    let enabled: Bool
    let showTeacher: Bool
    let compactInitial: Bool
    let keepAfterSchool: Bool
    let timeOffsetSeconds: TimeInterval
    let accentRGBA: UInt32
    let layout: LiveActivityLayout
    let weatherEnabled: Bool
    let weather: WeatherPresentation?
    let plugin: PluginActivityPresentation?

    init(
        snapshot: ScheduleSnapshot?,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?
    ) {
        phase = snapshot?.phase
        profileName = snapshot?.profileName
        current = snapshot?.current
        currentBreak = snapshot?.currentBreak
        next = snapshot?.next
        enabled = settings.liveActivitiesEnabled
        showTeacher = settings.showTeacher
        compactInitial = settings.useInitialInCompactIsland
        keepAfterSchool = settings.keepAfterSchoolActivity
        timeOffsetSeconds = settings.timeOffsetSeconds
        accentRGBA = settings.activityAccentRGBA
        layout = settings.liveActivityLayout
        weatherEnabled = settings.weatherEnabled
        self.weather = weather
        self.plugin = plugin
    }
}

enum ImportError: LocalizedError {
    case unsupportedDocument
    case incompleteProfile
    case noProfile

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "无法识别该 JSON。请选择 ClassIsland 的 Profile.json 或 Settings.json。"
        case .incompleteProfile:
            "课表缺少 ClassPlans、TimeLayouts 或 Subjects 数据。"
        case .noProfile:
            "当前没有可导出的档案。"
        }
    }
}
