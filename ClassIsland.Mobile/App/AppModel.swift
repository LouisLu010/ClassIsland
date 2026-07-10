import ActivityKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profile: ClassIslandProfile?
    @Published private(set) var profileFileName = ""
    @Published private(set) var currentSnapshot: ScheduleSnapshot?
    @Published private(set) var statusMessage = ""
    @Published private(set) var activityStatus = "尚未启动"
    @Published var settings: MobileSettings {
        didSet {
            guard hasBootstrapped else { return }
            persistSettings()
            Task { await refreshCurrentSchedule() }
        }
    }

    private let repository: MobileRepository
    private let engine: ScheduleEngine
    private let liveActivityController: LiveActivityController
    private var hasBootstrapped = false
    private var monitorTask: Task<Void, Never>?
    private var lastActivitySignature: ActivitySignature?
    private var scheduledRefreshDate: Date?
    private var hasReconciledBackgroundRefresh = false

    init(
        repository: MobileRepository = MobileRepository(),
        engine: ScheduleEngine = ScheduleEngine(),
        liveActivityController: LiveActivityController = .shared
    ) {
        self.repository = repository
        self.engine = engine
        self.liveActivityController = liveActivityController
        settings = MobileSettings()
    }

    deinit {
        monitorTask?.cancel()
    }

    func bootstrap() async {
        loadPersistedDataIfNeeded()
        await refreshCurrentSchedule()
        if monitorTask == nil {
            startMonitor()
        }
    }

    func handleBackgroundRefresh() async {
        scheduledRefreshDate = nil
        hasReconciledBackgroundRefresh = false
        loadPersistedDataIfNeeded()
        await refreshCurrentSchedule(allowStartingActivity: false)
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
                profileFileName = "Profile.json"
            }
        } catch {
            profile = nil
            profileFileName = ""
            startupMessages.append("读取本地课表失败：\(error.localizedDescription)")
        }
        hasBootstrapped = true
        statusMessage = startupMessages.joined(separator: "\n")
    }

    func snapshot(for date: Date, now: Date = Date()) -> ScheduleSnapshot? {
        guard let profile else { return nil }
        return engine.snapshot(profile: profile, settings: settings, at: now, for: date)
    }

    func importDocument(_ url: URL) async {
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
                profile = decoded
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
                || dictionary["ShowCurrentLessonOnlyOnClass"] != nil {
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

    func removeProfile() async {
        do {
            try repository.removeProfile()
            profile = nil
            profileFileName = ""
            currentSnapshot = nil
            lastActivitySignature = nil
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
        allowStartingActivity: Bool = true
    ) async {
        guard let profile else {
            currentSnapshot = nil
            let signature = ActivitySignature(snapshot: nil, settings: settings)
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
        let signature = ActivitySignature(snapshot: snapshot, settings: settings)
        if signature != lastActivitySignature {
            do {
                let synchronized = try await liveActivityController.synchronize(
                    snapshot: snapshot,
                    settings: settings,
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
    }

    func stopLiveActivity() async {
        settings.liveActivitiesEnabled = false
        await liveActivityController.endAll()
        lastActivitySignature = ActivitySignature(snapshot: currentSnapshot, settings: settings)
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

    private func decodeProfile(_ data: Data) throws -> ClassIslandProfile {
        let decoded = try JSONDecoder().decode(ClassIslandProfile.self, from: data)
        guard !decoded.classPlans.isEmpty,
              !decoded.timeLayouts.isEmpty,
              !decoded.subjects.isEmpty else {
            throw ImportError.incompleteProfile
        }
        return decoded
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
        let targetDate = snapshot.flatMap {
            ScheduleRefreshPolicy.earliestBeginDate(
                for: $0,
                settings: settings,
                hasActiveActivity: !Activity<ScheduleActivityAttributes>.activities.isEmpty,
                now: now
            )
        }

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

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshCurrentSchedule()
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

    init(snapshot: ScheduleSnapshot?, settings: MobileSettings) {
        phase = snapshot?.phase
        profileName = snapshot?.profileName
        current = snapshot?.current
        currentBreak = snapshot?.currentBreak
        next = snapshot?.next
        enabled = settings.liveActivitiesEnabled
        showTeacher = settings.showTeacher
        compactInitial = settings.useInitialInCompactIsland
        keepAfterSchool = settings.keepAfterSchoolActivity
    }
}

enum ImportError: LocalizedError {
    case unsupportedDocument
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "无法识别该 JSON。请选择 ClassIsland 的 Profile.json 或 Settings.json。"
        case .incompleteProfile:
            "课表缺少 ClassPlans、TimeLayouts 或 Subjects 数据。"
        }
    }
}
