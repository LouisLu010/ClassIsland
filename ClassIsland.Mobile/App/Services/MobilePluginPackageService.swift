import CryptoKit
import Foundation
import ImageIO
import Yams
import ZIPFoundation

struct MobilePluginPackageService: Sendable {
    static let maximumPackageSize = 20 * 1_024 * 1_024
    static let maximumExpandedSize: UInt64 = 20 * 1_024 * 1_024
    static let maximumEntrySize: UInt64 = 5 * 1_024 * 1_024
    static let maximumEntryCount = 256

    private static let maximumManifestSize: UInt64 = 256 * 1_024
    private static let maximumDefinitionSize: UInt64 = 1 * 1_024 * 1_024
    private static let maximumIconSize: UInt64 = 1 * 1_024 * 1_024

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspectPackage(at packageURL: URL, installedAt: Date = Date()) throws -> MobilePluginInstallation {
        guard let packageSize = try packageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw MobilePluginError.packageTooLarge
        }
        guard packageSize <= Self.maximumPackageSize else {
            throw MobilePluginError.packageTooLarge
        }

        let archive = try Archive(url: packageURL, accessMode: .read)
        let entries = Array(archive)
        let entriesByPath = try validate(entries: entries)
        guard let manifestEntry = entriesByPath["manifest.yml"] else {
            throw MobilePluginError.missingManifest
        }
        guard manifestEntry.path == "manifest.yml", manifestEntry.type == .file else {
            throw MobilePluginError.invalidManifest("manifest.yml 必须是包根目录中的普通文件。")
        }
        guard manifestEntry.uncompressedSize <= Self.maximumManifestSize else {
            throw MobilePluginError.entryTooLarge("manifest.yml")
        }

        let manifestData = try read(manifestEntry, from: archive, limit: Self.maximumManifestSize)
        let manifest: MobilePluginPackageManifest
        do {
            manifest = try YAMLDecoder().decode(MobilePluginPackageManifest.self, from: manifestData)
        } catch {
            throw MobilePluginError.invalidManifest(error.localizedDescription)
        }
        try validate(manifest: manifest)

        let entryPath = try Self.validateArchivePath(manifest.mobile.entry)
        guard entryPath.hasPrefix("mobile/"), entryPath.hasSuffix(".json") else {
            throw MobilePluginError.invalidManifest("mobile.entry 必须是 mobile/ 下的 JSON 文件。")
        }
        guard let definitionEntry = entriesByPath[entryPath.lowercased()] else {
            throw MobilePluginError.missingMobileEntry(entryPath)
        }
        guard definitionEntry.path == entryPath, definitionEntry.type == .file else {
            throw MobilePluginError.invalidManifest("mobile.entry 路径大小写必须完全匹配。")
        }
        guard definitionEntry.uncompressedSize <= Self.maximumDefinitionSize else {
            throw MobilePluginError.entryTooLarge(entryPath)
        }

        let definitionData = try read(
            definitionEntry,
            from: archive,
            limit: Self.maximumDefinitionSize
        )
        let definition: MobilePluginDefinition
        do {
            definition = try JSONDecoder().decode(MobilePluginDefinition.self, from: definitionData)
        } catch {
            throw MobilePluginError.invalidDefinition(error.localizedDescription)
        }
        try validate(definition: definition, manifest: manifest)

        let iconPath = try validatedIconPath(manifest.icon, entriesByPath: entriesByPath)
        if let iconPath, let iconEntry = entriesByPath[iconPath.lowercased()] {
            let iconData = try read(iconEntry, from: archive, limit: Self.maximumIconSize)
            try validateIcon(data: iconData, path: iconPath)
        }
        let packageData = try Data(contentsOf: packageURL, options: [.mappedIfSafe])
        guard packageData.count <= Self.maximumPackageSize else {
            throw MobilePluginError.packageTooLarge
        }
        let digest = SHA256.hash(data: packageData).map { String(format: "%02x", $0) }.joined()

        return MobilePluginInstallation(
            manifest: manifest,
            definition: definition,
            packageSHA256: digest,
            installedAt: installedAt,
            iconRelativePath: iconPath
        )
    }

    func installPackage(
        at packageURL: URL,
        installation: MobilePluginInstallation,
        state: MobilePluginState,
        repository: MobilePluginRepository
    ) throws {
        let current = try inspectPackage(at: packageURL, installedAt: installation.installedAt)
        guard current.packageSHA256 == installation.packageSHA256,
              current.manifest == installation.manifest,
              current.definition == installation.definition else {
            throw MobilePluginError.invalidDefinition("待安装插件包在确认后发生了变化。")
        }

        let archive = try Archive(url: packageURL, accessMode: .read)
        let entries = Array(archive)
        _ = try validate(entries: entries)
        let stagingDirectory = try repository.makeInstallationStagingDirectory()
        var shouldRemoveStaging = true
        defer {
            if shouldRemoveStaging, fileManager.fileExists(atPath: stagingDirectory.path) {
                try? fileManager.removeItem(at: stagingDirectory)
            }
        }

        let iconPath = installation.iconRelativePath?.lowercased()
        var extractedSize: UInt64 = 0
        for entry in entries where entry.type == .file {
            let path = try Self.validateArchivePath(entry.path)
            let normalized = path.lowercased()
            let shouldExtract = normalized == "manifest.yml"
                || normalized.hasPrefix("mobile/")
                || (iconPath.map { normalized == $0 } ?? false)
            guard shouldExtract else { continue }

            let destination = stagingDirectory.appendingPathComponent(path)
            let remaining = Self.maximumExpandedSize - extractedSize
            let data = try read(
                entry,
                from: archive,
                limit: min(Self.maximumEntrySize, remaining)
            )
            extractedSize += UInt64(data.count)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
        }

        try repository.writeInstallation(
            installation,
            state: state,
            to: stagingDirectory
        )
        try repository.replacePluginDirectory(id: installation.id, with: stagingDirectory)
        shouldRemoveStaging = false
    }

    static func validateArchivePath(_ path: String) throws -> String {
        guard !path.isEmpty,
              path.utf8.count <= 512,
              !path.contains("\\"),
              !path.contains("\0"),
              !path.hasPrefix("/"),
              path.range(of: "^[A-Za-z]:", options: .regularExpression) == nil else {
            throw MobilePluginError.unsafePath(path)
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        for (index, component) in components.enumerated() {
            if component == "." || component == ".." {
                throw MobilePluginError.unsafePath(path)
            }
            let isTrailingDirectoryMarker = index == components.count - 1 && component.isEmpty
            if component.isEmpty && !isTrailingDirectoryMarker {
                throw MobilePluginError.unsafePath(path)
            }
        }
        return path.precomposedStringWithCanonicalMapping
    }

    private func validate(entries: [Entry]) throws -> [String: Entry] {
        guard entries.count <= Self.maximumEntryCount else {
            throw MobilePluginError.tooManyEntries
        }

        var expandedSize: UInt64 = 0
        var entriesByPath: [String: Entry] = [:]
        for entry in entries {
            let path = try Self.validateArchivePath(entry.path)
            guard entry.type != .symlink else {
                throw MobilePluginError.symbolicLink(path)
            }
            guard entry.uncompressedSize <= Self.maximumEntrySize else {
                throw MobilePluginError.entryTooLarge(path)
            }
            let (newSize, overflow) = expandedSize.addingReportingOverflow(entry.uncompressedSize)
            guard !overflow, newSize <= Self.maximumExpandedSize else {
                throw MobilePluginError.expandedPackageTooLarge
            }
            expandedSize = newSize

            let normalized = path.lowercased()
            guard entriesByPath[normalized] == nil else {
                throw MobilePluginError.duplicatePath(path)
            }
            entriesByPath[normalized] = entry
        }
        return entriesByPath
    }

    private func validate(manifest: MobilePluginPackageManifest) throws {
        let idPattern = "^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,126}[A-Za-z0-9])?$"
        guard manifest.id == manifest.id.lowercased(),
              manifest.id.range(of: idPattern, options: .regularExpression) != nil else {
            throw MobilePluginError.invalidPluginID
        }
        guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              manifest.name.count <= 80 else {
            throw MobilePluginError.invalidManifest("name 不能为空且不能超过 80 个字符。")
        }
        guard !manifest.version.isEmpty, manifest.version.count <= 32 else {
            throw MobilePluginError.invalidManifest("version 不能为空且不能超过 32 个字符。")
        }
        guard manifest.description.count <= 1_000,
              manifest.author.count <= 120,
              (manifest.url?.count ?? 0) <= 2_048,
              manifest.dependencies.count <= 32 else {
            throw MobilePluginError.invalidManifest("描述、作者、URL 或依赖数量超过限制。")
        }
        guard manifest.mobile.apiVersion == 1 else {
            throw MobilePluginError.unsupportedAPIVersion(manifest.mobile.apiVersion)
        }
        guard manifest.mobile.runtime.caseInsensitiveCompare("declarative") == .orderedSame else {
            throw MobilePluginError.unsupportedRuntime
        }
        guard Set(manifest.mobile.capabilities).count == manifest.mobile.capabilities.count else {
            throw MobilePluginError.invalidManifest("capabilities 不能重复。")
        }
        let dependencyIDs = manifest.dependencies.map { $0.id.lowercased() }
        guard Set(dependencyIDs).count == dependencyIDs.count,
              manifest.dependencies.allSatisfy({ dependency in
                  dependency.id == dependency.id.lowercased()
                      && dependency.id.range(of: idPattern, options: .regularExpression) != nil
                      && dependency.id.caseInsensitiveCompare(manifest.id) != .orderedSame
              }) else {
            throw MobilePluginError.invalidManifest("dependencies 包含重复、自引用或空 ID。")
        }
    }

    private func validate(
        definition: MobilePluginDefinition,
        manifest: MobilePluginPackageManifest
    ) throws {
        guard definition.schemaVersion == 1 else {
            throw MobilePluginError.invalidDefinition("仅支持 schemaVersion 1。")
        }
        guard definition.components.count <= 32,
              definition.settings.count <= 64,
              definition.events.count <= 32,
              definition.events.reduce(0, { $0 + $1.actions.count }) <= 64,
              definition.events.allSatisfy({ handler in
                  handler.actions.count <= 8
                      && handler.actions.filter { $0.kind == .networkFetch }.count <= 2
              }) else {
            throw MobilePluginError.invalidDefinition("组件、设置或事件数量超过限制。")
        }

        let componentIDs = definition.components.map { $0.id }
        let settingKeys = definition.settings.map { $0.key }
        guard Set(componentIDs).count == componentIDs.count,
              Set(settingKeys).count == settingKeys.count else {
            throw MobilePluginError.invalidDefinition("组件 ID 和设置 key 必须唯一。")
        }
        guard (componentIDs + settingKeys).allSatisfy(Self.isValidDefinitionIdentifier) else {
            throw MobilePluginError.invalidDefinition("组件 ID 或设置 key 格式无效。")
        }

        let capabilities = Set(manifest.mobile.capabilities)
        let settingsByKey = Dictionary(
            uniqueKeysWithValues: definition.settings.map { ($0.key, $0) }
        )
        try validate(settings: definition.settings)
        try validate(domains: definition.allowedDomains, capabilities: capabilities)
        if definition.events.flatMap(\.actions).contains(where: { $0.kind == .networkFetch }),
           definition.allowedDomains.isEmpty {
            throw MobilePluginError.invalidDefinition(
                "network.fetch 行动至少需要一个 allowedDomains 主机名。"
            )
        }

        for component in definition.components {
            try validate(
                component: component,
                settingsByKey: settingsByKey,
                capabilities: capabilities
            )
        }
        for handler in definition.events {
            switch handler.event {
            case .scheduleClassStarted, .scheduleBreakStarted, .scheduleAfterSchool:
                guard capabilities.contains(.scheduleRead) else {
                    throw MobilePluginError.invalidDefinition(
                        "课程事件需要 schedule.read 能力。"
                    )
                }
            case .weatherUpdated:
                guard capabilities.contains(.weatherRead) else {
                    throw MobilePluginError.invalidDefinition(
                        "weather.updated 事件需要 weather.read 能力。"
                    )
                }
            case .appActive:
                break
            }
            if let condition = handler.when {
                try validate(
                    condition: condition,
                    settingKeys: Set(settingKeys),
                    capabilities: capabilities
                )
            }
            for action in handler.actions {
                guard action.kind != .openURL else {
                    throw MobilePluginError.invalidDefinition(
                        "url.open 只能由用户点按组件触发，不能绑定到自动事件。"
                    )
                }
                try validate(
                    action: action,
                    settingsByKey: settingsByKey,
                    capabilities: capabilities
                )
            }
        }
        if let liveActivity = definition.liveActivity {
            guard capabilities.contains(.liveActivityRender) else {
                throw MobilePluginError.invalidDefinition(
                    "liveActivity 需要 liveActivity.render 能力。"
                )
            }
            try validateTemplate(liveActivity.title, capabilities: capabilities)
            try validateTemplate(liveActivity.value, capabilities: capabilities)
            guard !liveActivity.title.contains("{{now."),
                  !liveActivity.value.contains("{{now.") else {
                throw MobilePluginError.invalidDefinition(
                    "liveActivity 不支持 now 模板，请使用宿主时钟组件。"
                )
            }
            try validateSystemImage(liveActivity.systemImage)
        }
    }

    private func validate(settings: [MobilePluginSettingDefinition]) throws {
        for setting in settings {
            guard !setting.title.isEmpty, setting.title.count <= 80,
                  setting.description.count <= 240 else {
                throw MobilePluginError.invalidDefinition("设置标题或说明过长：\(setting.key)")
            }
            switch (setting.type, setting.defaultValue) {
            case (.toggle, .bool), (.text, .string), (.number, .number), (.choice, .string):
                break
            default:
                throw MobilePluginError.invalidDefinition("设置默认值类型不匹配：\(setting.key)")
            }
            if case .string(let value) = setting.defaultValue, value.count > 2_048 {
                throw MobilePluginError.invalidDefinition("设置默认文本过长：\(setting.key)")
            }
            if setting.type == .number {
                guard let value = setting.defaultValue.numberValue, value.isFinite,
                      setting.minimum?.isFinite != false,
                      setting.maximum?.isFinite != false,
                      setting.step?.isFinite != false,
                      (setting.minimum == nil || setting.maximum == nil
                          || setting.minimum! <= setting.maximum!),
                      setting.minimum.map({ value >= $0 }) ?? true,
                      setting.maximum.map({ value <= $0 }) ?? true,
                      setting.step.map({ $0 > 0 }) ?? true else {
                    throw MobilePluginError.invalidDefinition("数字设置范围无效：\(setting.key)")
                }
            }
            if setting.type == .choice {
                let optionValues = setting.options.map { $0.value }
                guard !optionValues.isEmpty,
                      optionValues.count <= 32,
                      Set(optionValues).count == optionValues.count,
                      setting.options.allSatisfy({ $0.value.count <= 128 && $0.title.count <= 80 }),
                      optionValues.contains(setting.defaultValue.stringValue) else {
                    throw MobilePluginError.invalidDefinition("选择设置选项无效：\(setting.key)")
                }
            }
        }
    }

    private func validate(
        domains: [String],
        capabilities: Set<MobilePluginCapability>
    ) throws {
        guard domains.count <= 16, Set(domains.map { $0.lowercased() }).count == domains.count else {
            throw MobilePluginError.invalidDefinition("allowedDomains 重复或超过 16 个。")
        }
        let pattern = "^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$"
        guard domains.allSatisfy({
            $0.range(of: pattern, options: .regularExpression) != nil
                && !$0.contains("..")
                && !$0.contains(":")
                && $0.split(separator: ".").count >= 2
                && ($0.split(separator: ".").last?.count ?? 0) >= 2
        }) else {
            throw MobilePluginError.invalidDefinition("allowedDomains 只能包含主机名。")
        }
        if !domains.isEmpty, !capabilities.contains(.networkFetch) {
            throw MobilePluginError.invalidDefinition("allowedDomains 需要 network.fetch 能力。")
        }
    }

    private func validate(
        component: MobilePluginComponentDefinition,
        settingsByKey: [String: MobilePluginSettingDefinition],
        capabilities: Set<MobilePluginCapability>
    ) throws {
        let settingKeys = Set(settingsByKey.keys)
        guard !component.title.isEmpty,
              component.title.count <= 80,
              component.subtitle.count <= 240,
              component.body.count <= 512,
              component.items.count <= 16 else {
            throw MobilePluginError.invalidDefinition("组件内容超过限制：\(component.id)")
        }
        try validateSystemImage(component.systemImage)
        if let tint = component.tint {
            guard tint.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
                throw MobilePluginError.invalidDefinition("组件 tint 必须为 #RRGGBB：\(component.id)")
            }
        }
        if component.kind == .progress {
            let minimum = component.minimum ?? 0
            let maximum = component.maximum ?? 1
            guard minimum.isFinite, maximum.isFinite, maximum > minimum else {
                throw MobilePluginError.invalidDefinition("进度组件范围无效：\(component.id)")
            }
        }
        if component.kind == .list, component.items.isEmpty {
            throw MobilePluginError.invalidDefinition("列表组件至少需要一个 item：\(component.id)")
        }
        if let condition = component.when {
            try validate(
                condition: condition,
                settingKeys: settingKeys,
                capabilities: capabilities
            )
        }

        try validateTemplate(component.title, capabilities: capabilities)
        try validateTemplate(component.subtitle, capabilities: capabilities)
        try validateTemplate(component.value, capabilities: capabilities)
        try validateTemplate(component.body, capabilities: capabilities)
        guard Set(component.items.map(\.id)).count == component.items.count else {
            throw MobilePluginError.invalidDefinition("列表 item ID 不能重复：\(component.id)")
        }
        for item in component.items {
            guard Self.isValidDefinitionIdentifier(item.id) else {
                throw MobilePluginError.invalidDefinition("列表 item ID 无效：\(item.id)")
            }
            try validateTemplate(item.label, capabilities: capabilities)
            try validateTemplate(item.value, capabilities: capabilities)
            if let systemImage = item.systemImage {
                try validateSystemImage(systemImage)
            }
        }
        if let action = component.action {
            guard action.kind == .openURL else {
                throw MobilePluginError.invalidDefinition("组件点按行动目前仅支持 url.open。")
            }
            try validate(
                action: action,
                settingsByKey: settingsByKey,
                capabilities: capabilities
            )
        }
    }

    private func validate(
        condition: MobilePluginCondition,
        settingKeys: Set<String>,
        capabilities: Set<MobilePluginCapability>
    ) throws {
        guard condition.source.count <= 128,
              (condition.equals?.count ?? 0) <= 256,
              (condition.notEquals?.count ?? 0) <= 256 else {
            throw MobilePluginError.invalidDefinition("条件表达式过长。")
        }
        if condition.source.hasPrefix("settings.") {
            let key = String(condition.source.dropFirst("settings.".count))
            guard settingKeys.contains(key) else {
                throw MobilePluginError.invalidDefinition("条件引用了未声明的设置：\(key)")
            }
        } else if condition.source.hasPrefix("schedule.") {
            guard capabilities.contains(.scheduleRead) else {
                throw MobilePluginError.invalidDefinition("课表条件需要 schedule.read 能力。")
            }
        } else if condition.source.hasPrefix("weather.") {
            guard capabilities.contains(.weatherRead) else {
                throw MobilePluginError.invalidDefinition("天气条件需要 weather.read 能力。")
            }
        } else if !condition.source.hasPrefix("now.")
                    && !condition.source.hasPrefix("plugin.") {
            throw MobilePluginError.invalidDefinition("条件 source 不受支持：\(condition.source)")
        }
    }

    private func validate(
        action: MobilePluginAction,
        settingsByKey: [String: MobilePluginSettingDefinition],
        capabilities: Set<MobilePluginCapability>
    ) throws {
        let requiredCapability: MobilePluginCapability? = switch action.kind {
        case .notification: .notificationPost
        case .openURL: .urlOpen
        case .networkFetch: .networkFetch
        case .setSetting, .refreshComponents: nil
        }
        if let requiredCapability, !capabilities.contains(requiredCapability) {
            throw MobilePluginError.invalidDefinition(
                "行动 \(action.kind.rawValue) 缺少 \(requiredCapability.rawValue) 能力。"
            )
        }

        switch action.kind {
        case .notification:
            guard let title = action.title, !title.isEmpty, title.count <= 128,
                  let body = action.body, body.count <= 512 else {
                throw MobilePluginError.invalidDefinition("notification.post 参数无效。")
            }
            try validateTemplate(title, capabilities: capabilities)
            try validateTemplate(body, capabilities: capabilities)
        case .openURL:
            guard let url = action.url, !url.isEmpty, url.count <= 1_024 else {
                throw MobilePluginError.invalidDefinition("url.open 缺少有效 URL。")
            }
            try validateTemplate(url, capabilities: capabilities)
        case .setSetting:
            guard let key = action.settingKey,
                  let definition = settingsByKey[key],
                  let value = action.value,
                  settingValue(value, matches: definition) else {
                throw MobilePluginError.invalidDefinition("setting.write 必须写入已声明的设置。")
            }
            if case .string(let template) = value {
                try validateTemplate(template, capabilities: capabilities)
            }
        case .networkFetch:
            guard let url = action.url, !url.isEmpty, url.count <= 1_024 else {
                throw MobilePluginError.invalidDefinition("network.fetch 缺少有效 URL。")
            }
            if let key = action.responseSettingKey,
               settingsByKey[key]?.type != .text {
                throw MobilePluginError.invalidDefinition("network.fetch 响应目标必须是文本设置：\(key)")
            }
            try validateTemplate(url, capabilities: capabilities)
        case .refreshComponents:
            break
        }
    }

    private func validateTemplate(
        _ value: String,
        capabilities: Set<MobilePluginCapability>
    ) throws {
        guard value.count <= 1_024 else {
            throw MobilePluginError.invalidDefinition("模板字符串超过 1024 个字符。")
        }
        if value.contains("{{schedule."), !capabilities.contains(.scheduleRead) {
            throw MobilePluginError.invalidDefinition("课表模板需要 schedule.read 能力。")
        }
        if value.contains("{{weather."), !capabilities.contains(.weatherRead) {
            throw MobilePluginError.invalidDefinition("天气模板需要 weather.read 能力。")
        }
    }

    private func validateSystemImage(_ value: String) throws {
        guard !value.isEmpty,
              value.count <= 64,
              value.range(of: "^[A-Za-z0-9.-]+$", options: .regularExpression) != nil else {
            throw MobilePluginError.invalidDefinition("systemImage 格式无效：\(value)")
        }
    }

    private func validatedIconPath(
        _ declaredPath: String,
        entriesByPath: [String: Entry]
    ) throws -> String? {
        guard !declaredPath.isEmpty else { return nil }
        let path = try Self.validateArchivePath(declaredPath)
        let allowedExtensions = Set(["png", "jpg", "jpeg", "heic", "webp"])
        guard allowedExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased()) else {
            throw MobilePluginError.invalidManifest("插件图标格式不受支持。")
        }
        guard let entry = entriesByPath[path.lowercased()] else { return nil }
        guard entry.path == path,
              entry.type == .file,
              entry.uncompressedSize <= Self.maximumIconSize else {
            throw MobilePluginError.entryTooLarge(path)
        }
        return path
    }

    private func validateIcon(data: Data, path: String) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.intValue > 0,
              height.intValue > 0,
              width.intValue <= 2_048,
              height.intValue <= 2_048,
              width.intValue * height.intValue <= 4_194_304 else {
            throw MobilePluginError.invalidManifest("插件图标无效或像素尺寸过大：\(path)")
        }
    }

    private func read(_ entry: Entry, from archive: Archive, limit: UInt64) throws -> Data {
        var result = Data()
        try archive.extract(entry, bufferSize: 32 * 1_024, skipCRC32: false) { chunk in
            guard UInt64(result.count + chunk.count) <= limit else {
                throw MobilePluginError.entryTooLarge(entry.path)
            }
            result.append(chunk)
        }
        return result
    }

    private static func isValidDefinitionIdentifier(_ value: String) -> Bool {
        value.range(
            of: "^[A-Za-z][A-Za-z0-9._-]{0,63}$",
            options: .regularExpression
        ) != nil
    }

    private func settingValue(
        _ value: MobilePluginValue,
        matches definition: MobilePluginSettingDefinition
    ) -> Bool {
        switch (definition.type, value) {
        case (.toggle, .bool):
            true
        case (.text, .string(let text)):
            text.count <= 2_048
        case (.number, .number(let number)):
            number.isFinite
                && (definition.minimum.map { number >= $0 } ?? true)
                && (definition.maximum.map { number <= $0 } ?? true)
        case (.choice, .string(let selected)):
            definition.options.contains { $0.value == selected }
        default:
            false
        }
    }
}
