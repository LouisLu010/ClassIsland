import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class MobilePluginManager: ObservableObject {
    @Published private(set) var plugins: [InstalledMobilePlugin] = []
    @Published private(set) var settingsValues: [String: [String: MobilePluginValue]] = [:]
    @Published private(set) var statusMessage = ""
    @Published private(set) var isImporting = false
    @Published private(set) var isInstalling = false
    @Published var pendingInstall: PendingMobilePluginInstall?

    private let repository: MobilePluginRepository
    private let packageService: MobilePluginPackageService
    private let runtime: MobilePluginRuntime
    private let networkClient: MobilePluginNetworkClient
    private var hasBootstrapped = false
    private var eventDispatchTask: Task<Void, Never>?

    init(
        repository: MobilePluginRepository = MobilePluginRepository(),
        packageService: MobilePluginPackageService = MobilePluginPackageService(),
        runtime: MobilePluginRuntime = MobilePluginRuntime(),
        networkClient: MobilePluginNetworkClient = MobilePluginNetworkClient()
    ) {
        self.repository = repository
        self.packageService = packageService
        self.runtime = runtime
        self.networkClient = networkClient
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        do {
            let repository = repository
            let loaded = try await Task.detached(priority: .userInitiated) {
                try? repository.discardAllStagedPackages()
                return try repository.loadInstalledPlugins()
            }.value
            plugins = loaded
            for plugin in loaded {
                let stored = (try? repository.loadSettings(pluginID: plugin.id)) ?? [:]
                settingsValues[plugin.id] = normalizedSettings(stored, for: plugin)
            }
            hasBootstrapped = true
        } catch {
            statusMessage = "读取移动插件失败：\(error.localizedDescription)"
            hasBootstrapped = true
        }
    }

    func prepareInstallation(from sourceURL: URL) async {
        guard !isImporting, !isInstalling else { return }
        isImporting = true
        defer { isImporting = false }
        await bootstrap()

        if let pendingInstall {
            repository.discardStagedPackage(at: pendingInstall.stagedPackageURL)
            self.pendingInstall = nil
        }

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let repository = repository
            let packageService = packageService
            let result = try await Task.detached(priority: .userInitiated) {
                let stagedURL = try repository.stageImportedPackage(from: sourceURL)
                do {
                    let installation = try packageService.inspectPackage(at: stagedURL)
                    return (stagedURL, installation)
                } catch {
                    repository.discardStagedPackage(at: stagedURL)
                    throw error
                }
            }.value
            let isUpdate = plugins.contains { $0.id == result.1.id }
            guard isUpdate || plugins.count < 64 else {
                repository.discardStagedPackage(at: result.0)
                statusMessage = "最多只能安装 64 个移动插件。"
                return
            }
            let requestedCapabilities = Set(result.1.manifest.mobile.capabilities)
            let existingCapabilities = plugins.first(where: { $0.id == result.1.id })?
                .state.grantedCapabilities
            let initialGrantedCapabilities = existingCapabilities?
                .intersection(requestedCapabilities) ?? requestedCapabilities
            pendingInstall = PendingMobilePluginInstall(
                id: UUID(),
                stagedPackageURL: result.0,
                installation: result.1,
                isUpdate: isUpdate,
                initialGrantedCapabilities: initialGrantedCapabilities
            )
            statusMessage = "已验证插件包：\(result.1.manifest.name)"
        } catch {
            statusMessage = "插件包导入失败：\(error.localizedDescription)"
        }
    }

    func cancelPendingInstallation() {
        guard let pendingInstall else { return }
        cancelPendingInstallation(pendingInstall)
    }

    func cancelPendingInstallation(_ pending: PendingMobilePluginInstall) {
        guard !isInstalling else { return }
        repository.discardStagedPackage(at: pending.stagedPackageURL)
        if pendingInstall?.id == pending.id {
            pendingInstall = nil
        }
    }

    func installPending(grantedCapabilities: Set<MobilePluginCapability>) async {
        guard let pending = pendingInstall, !isInstalling else { return }
        isInstalling = true
        defer { isInstalling = false }
        let requested = Set(pending.installation.manifest.mobile.capabilities)
        let granted = grantedCapabilities.intersection(requested)
        let existing = plugins.first { $0.id == pending.installation.id }
        let missing = pending.installation.manifest.dependencies.filter { dependency in
            dependency.isRequired && !plugins.contains { $0.id == dependency.id }
        }
        let state = MobilePluginState(
            id: pending.installation.id,
            isEnabled: (existing?.state.isEnabled ?? true) && missing.isEmpty,
            grantedCapabilities: granted
        )
        let installed = InstalledMobilePlugin(
            installation: pending.installation,
            state: state
        )
        var proposedPlugins = plugins.filter { $0.id != installed.id }
        proposedPlugins.append(installed)
        proposedPlugins.sort {
            $0.manifest.name.localizedStandardCompare($1.manifest.name) == .orderedAscending
        }
        let preservedSettings = settingsValues[installed.id]
            ?? (try? repository.loadSettings(pluginID: installed.id))
            ?? [:]
        let proposedSettings = normalizedSettings(preservedSettings, for: installed)

        do {
            let packageService = packageService
            let repository = repository
            try await Task.detached(priority: .userInitiated) {
                try packageService.installPackage(
                    at: pending.stagedPackageURL,
                    installation: pending.installation,
                    state: state,
                    repository: repository
                )
            }.value

            plugins = proposedPlugins
            settingsValues[installed.id] = proposedSettings

            repository.discardStagedPackage(at: pending.stagedPackageURL)
            pendingInstall = nil
            if granted.contains(.notificationPost) {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )
            }
            statusMessage = pending.isUpdate
                ? "已更新插件：\(installed.manifest.name)"
                : "已安装插件：\(installed.manifest.name)"
            if let dependency = missing.first {
                statusMessage += "；启用前需要插件 \(dependency.id)"
            }
        } catch {
            statusMessage = "插件安装失败：\(error.localizedDescription)"
        }
    }

    func setEnabled(_ enabled: Bool, pluginID: String) {
        guard let index = plugins.firstIndex(where: { $0.id == pluginID }) else { return }
        if enabled, let missing = missingRequiredDependencies(for: plugins[index]).first {
            statusMessage = MobilePluginError.missingDependency(missing.id).localizedDescription
            return
        }
        let previousValue = plugins[index].state.isEnabled
        plugins[index].state.isEnabled = enabled
        do {
            try repository.saveState(plugins[index].state)
            statusMessage = enabled
                ? "已启用插件：\(plugins[index].manifest.name)"
                : "已停用插件：\(plugins[index].manifest.name)"
        } catch {
            plugins[index].state.isEnabled = previousValue
            statusMessage = "保存插件状态失败：\(error.localizedDescription)"
        }
    }

    func setCapability(
        _ capability: MobilePluginCapability,
        granted: Bool,
        pluginID: String
    ) async {
        guard let index = plugins.firstIndex(where: { $0.id == pluginID }),
              plugins[index].manifest.mobile.capabilities.contains(capability) else {
            return
        }
        let previousCapabilities = plugins[index].state.grantedCapabilities
        if granted {
            plugins[index].state.grantedCapabilities.insert(capability)
        } else {
            plugins[index].state.grantedCapabilities.remove(capability)
        }
        do {
            try repository.saveState(plugins[index].state)
            if granted, capability == .notificationPost {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                )
            }
        } catch {
            plugins[index].state.grantedCapabilities = previousCapabilities
            statusMessage = "保存插件权限失败：\(error.localizedDescription)"
        }
    }

    func uninstall(pluginID: String, removeData: Bool = false) async {
        guard let plugin = plugins.first(where: { $0.id == pluginID }) else { return }
        do {
            let repository = repository
            try await Task.detached(priority: .userInitiated) {
                try repository.removePlugin(id: pluginID, removeData: removeData)
            }.value
            plugins.removeAll { $0.id == pluginID }
            settingsValues.removeValue(forKey: pluginID)
            statusMessage = "已卸载插件：\(plugin.manifest.name)"
        } catch {
            statusMessage = "插件卸载失败：\(error.localizedDescription)"
        }
    }

    func plugin(id: String) -> InstalledMobilePlugin? {
        plugins.first { $0.id == id }
    }

    func iconURL(for plugin: InstalledMobilePlugin) -> URL? {
        try? repository.iconURL(for: plugin.installation)
    }

    func missingRequiredDependencies(for plugin: InstalledMobilePlugin) -> [MobilePluginDependency] {
        plugin.manifest.dependencies.filter { dependency in
            dependency.isRequired
                && !plugins.contains { $0.id == dependency.id }
        }
    }

    func isOperational(pluginID: String) -> Bool {
        operationalPlugins.contains { $0.id == pluginID }
    }

    func settingValue(pluginID: String, key: String) -> MobilePluginValue? {
        settingsValues[pluginID]?[key]
    }

    func setSettingValue(_ value: MobilePluginValue, pluginID: String, key: String) {
        guard let plugin = plugin(id: pluginID),
              let definition = plugin.definition.settings.first(where: { $0.key == key }),
              let normalized = normalizedValue(value, for: definition) else {
            return
        }
        let previousValues = settingsValues[pluginID] ?? [:]
        settingsValues[pluginID, default: [:]][key] = normalized
        do {
            try persistSettings(pluginID: pluginID)
        } catch {
            settingsValues[pluginID] = previousValues
            statusMessage = "保存插件设置失败：\(error.localizedDescription)"
        }
    }

    func renderedComponents(context: MobilePluginRuntimeContext) -> [RenderedMobilePluginComponent] {
        runtime.renderComponents(
            plugins: operationalPlugins,
            settings: settingsValues,
            context: context
        )
    }

    func activityPresentation(context: MobilePluginRuntimeContext) -> PluginActivityPresentation? {
        guard let presentation = runtime.activityPresentation(
            plugins: operationalPlugins,
            settings: settingsValues,
            context: context
        ) else {
            return nil
        }
        guard UIImage(systemName: presentation.systemImage) == nil else {
            return presentation
        }
        return PluginActivityPresentation(
            title: presentation.title,
            value: presentation.value,
            systemImage: "puzzlepiece.extension"
        )
    }

    func dispatch(event: MobilePluginEventName, context: MobilePluginRuntimeContext) async {
        let previousTask = eventDispatchTask
        let task = Task { [weak self] in
            if let previousTask {
                await previousTask.value
            }
            guard let self else { return }
            await self.dispatchImmediately(event: event, context: context)
        }
        eventDispatchTask = task
        await task.value
    }

    private func dispatchImmediately(
        event: MobilePluginEventName,
        context: MobilePluginRuntimeContext
    ) async {
        for plugin in operationalPlugins {
            for handler in plugin.definition.events where handler.event == event {
                if let requiredCapability = requiredCapability(for: event),
                   !plugin.state.grantedCapabilities.contains(requiredCapability) {
                    continue
                }
                let values = settingsValues[plugin.id] ?? [:]
                guard runtime.conditionMatches(
                    handler.when,
                    plugin: plugin,
                    settings: values,
                    context: context
                ) else {
                    continue
                }
                for action in handler.actions {
                    guard let current = operationalPlugins.first(where: {
                        $0.id == plugin.id
                            && $0.installation.packageSHA256
                                == plugin.installation.packageSHA256
                    }) else {
                        break
                    }
                    if let requiredCapability = requiredCapability(for: event),
                       !current.state.grantedCapabilities.contains(requiredCapability) {
                        break
                    }
                    do {
                        try await execute(
                            action,
                            plugin: current,
                            context: context,
                            userInitiated: false
                        )
                    } catch {
                        statusMessage = "插件 \(plugin.manifest.name) 执行失败：\(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func requiredCapability(
        for event: MobilePluginEventName
    ) -> MobilePluginCapability? {
        switch event {
        case .scheduleClassStarted, .scheduleBreakStarted, .scheduleAfterSchool:
            .scheduleRead
        case .weatherUpdated:
            .weatherRead
        case .appActive:
            nil
        }
    }

    func performComponentAction(
        _ action: MobilePluginAction,
        pluginID: String,
        context: MobilePluginRuntimeContext
    ) async {
        guard let plugin = operationalPlugins.first(where: { $0.id == pluginID }) else { return }
        do {
            try await execute(action, plugin: plugin, context: context, userInitiated: true)
        } catch {
            statusMessage = "插件 \(plugin.manifest.name) 执行失败：\(error.localizedDescription)"
        }
    }

    private var operationalPlugins: [InstalledMobilePlugin] {
        var available = plugins.filter(\.state.isEnabled)
        var changed = true
        while changed {
            let availableIDs = Set(available.map(\.id))
            let filtered = available.filter { plugin in
                plugin.manifest.dependencies.allSatisfy {
                    !$0.isRequired || availableIDs.contains($0.id)
                }
            }
            changed = filtered.count != available.count
            available = filtered
        }
        return available
    }

    private func execute(
        _ action: MobilePluginAction,
        plugin: InstalledMobilePlugin,
        context: MobilePluginRuntimeContext,
        userInitiated: Bool
    ) async throws {
        let pluginID = plugin.id
        let expectedPackageSHA256 = plugin.installation.packageSHA256
        guard let plugin = operationalPlugins.first(where: {
            $0.id == pluginID && $0.installation.packageSHA256 == expectedPackageSHA256
        }) else {
            throw MobilePluginError.requestDenied("插件已停用或依赖当前不可用。")
        }
        let settings = settingsValues[plugin.id] ?? [:]
        switch action.kind {
        case .notification:
            try require(.notificationPost, for: plugin)
            let content = UNMutableNotificationContent()
            content.title = runtime.resolve(
                action.title ?? plugin.manifest.name,
                plugin: plugin,
                settings: settings,
                context: context
            )
            content.body = runtime.resolve(
                action.body ?? "",
                plugin: plugin,
                settings: settings,
                context: context
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "mobile-plugin.\(plugin.id).\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try await UNUserNotificationCenter.current().add(request)

        case .openURL:
            try require(.urlOpen, for: plugin)
            guard userInitiated else {
                throw MobilePluginError.requestDenied("外部链接必须由用户点按后打开。")
            }
            let resolved = runtime.resolve(
                action.url ?? "",
                plugin: plugin,
                settings: settings,
                context: context
            )
            guard let url = URL(string: resolved),
                  url.scheme?.lowercased() == "https",
                  url.user == nil,
                  url.password == nil else {
                throw MobilePluginError.requestDenied("只允许打开无凭据的 HTTPS 链接。")
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)

        case .setSetting:
            guard let key = action.settingKey, var value = action.value else {
                throw MobilePluginError.requestDenied("缺少设置写入参数。")
            }
            if case .string(let template) = value {
                value = .string(
                    runtime.resolve(template, plugin: plugin, settings: settings, context: context)
                )
            }
            setSettingValue(value, pluginID: plugin.id, key: key)

        case .networkFetch:
            try require(.networkFetch, for: plugin)
            let resolved = runtime.resolve(
                action.url ?? "",
                plugin: plugin,
                settings: settings,
                context: context
            )
            guard let url = URL(string: resolved),
                  let host = url.host?.lowercased(),
                  url.scheme?.lowercased() == "https",
                  url.user == nil,
                  url.password == nil,
                  plugin.definition.allowedDomains.contains(where: {
                      host == $0.lowercased()
                  }) else {
                throw MobilePluginError.requestDenied("请求地址不在插件域名白名单中。")
            }
            let response = try await networkClient.fetch(
                url: url,
                allowedDomains: plugin.definition.allowedDomains
            )
            guard let current = operationalPlugins.first(where: {
                $0.id == pluginID && $0.installation.packageSHA256 == expectedPackageSHA256
            }) else {
                throw MobilePluginError.requestDenied("插件已停用，网络响应已丢弃。")
            }
            try require(.networkFetch, for: current)
            if let key = action.responseSettingKey {
                setSettingValue(.string(response), pluginID: plugin.id, key: key)
            }

        case .refreshComponents:
            objectWillChange.send()
        }
    }

    private func require(_ capability: MobilePluginCapability, for plugin: InstalledMobilePlugin) throws {
        guard plugin.state.grantedCapabilities.contains(capability) else {
            throw MobilePluginError.requestDenied("未授予 \(capability.title) 权限。")
        }
    }

    private func normalizedSettings(
        _ values: [String: MobilePluginValue],
        for plugin: InstalledMobilePlugin
    ) -> [String: MobilePluginValue] {
        Dictionary(uniqueKeysWithValues: plugin.definition.settings.map { definition in
            let value = values[definition.key]
                .flatMap { normalizedValue($0, for: definition) }
                ?? definition.defaultValue
            return (definition.key, value)
        })
    }

    private func normalizedValue(
        _ value: MobilePluginValue,
        for definition: MobilePluginSettingDefinition
    ) -> MobilePluginValue? {
        switch (definition.type, value) {
        case (.toggle, .bool):
            value
        case (.text, .string(let text)):
            .string(String(text.prefix(2_048)))
        case (.number, .number(let number)) where number.isFinite:
            .number(min(max(number, definition.minimum ?? number), definition.maximum ?? number))
        case (.choice, .string(let selected)) where definition.options.contains(where: {
            $0.value == selected
        }):
            value
        default:
            nil
        }
    }

    private func persistSettings(pluginID: String) throws {
        try repository.saveSettings(settingsValues[pluginID] ?? [:], pluginID: pluginID)
    }
}

actor MobilePluginNetworkClient {
    private static let maximumResponseSize = 256 * 1_024

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetch(url: URL, allowedDomains: [String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("ClassIsland-MobilePlugin/1", forHTTPHeaderField: "User-Agent")

        let redirectDelegate = MobilePluginRedirectDelegate(allowedDomains: allowedDomains)
        let (bytes, response) = try await session.bytes(for: request, delegate: redirectDelegate)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              MobilePluginRedirectDelegate.isAllowed(
                  httpResponse.url,
                  allowedDomains: allowedDomains
              ) else {
            throw MobilePluginError.requestDenied("网络服务返回了错误状态。")
        }
        if response.expectedContentLength > Int64(Self.maximumResponseSize) {
            throw MobilePluginError.responseTooLarge
        }

        var data = Data()
        data.reserveCapacity(min(max(Int(response.expectedContentLength), 0), Self.maximumResponseSize))
        for try await byte in bytes {
            guard data.count < Self.maximumResponseSize else {
                throw MobilePluginError.responseTooLarge
            }
            data.append(byte)
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw MobilePluginError.requestDenied("网络响应不是 UTF-8 文本。")
        }
        return value
    }
}

private final class MobilePluginRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let allowedDomains: [String]

    init(allowedDomains: [String]) {
        self.allowedDomains = allowedDomains
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(
            Self.isAllowed(request.url, allowedDomains: allowedDomains) ? request : nil
        )
    }

    static func isAllowed(_ url: URL?, allowedDomains: [String]) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased() else {
            return false
        }
        return allowedDomains.contains {
            let domain = $0.lowercased()
            return host == domain
        }
    }
}

final class MobilePluginNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = MobilePluginNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        guard identifier.hasPrefix("mobile-plugin.")
                || identifier.hasPrefix(ScheduleNotificationIdentifier.prefix) else {
            return []
        }
        return [.banner, .sound]
    }
}
