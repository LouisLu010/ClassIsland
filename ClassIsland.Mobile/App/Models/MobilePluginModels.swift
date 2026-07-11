import Foundation

enum MobilePluginCapability: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case scheduleRead = "schedule.read"
    case weatherRead = "weather.read"
    case networkFetch = "network.fetch"
    case notificationPost = "notification.post"
    case urlOpen = "url.open"
    case liveActivityRender = "liveActivity.render"

    var id: Self { self }

    var title: String {
        switch self {
        case .scheduleRead: "读取课表"
        case .weatherRead: "读取天气"
        case .networkFetch: "访问网络"
        case .notificationPost: "发送通知"
        case .urlOpen: "打开外部链接"
        case .liveActivityRender: "显示实时活动内容"
        }
    }

    var description: String {
        switch self {
        case .scheduleRead: "读取当前、下一节课程及课程状态。"
        case .weatherRead: "读取应用已缓存的城市和天气数据。"
        case .networkFetch: "仅向插件清单声明的 HTTPS 域名发起 GET 请求。"
        case .notificationPost: "通过系统通知中心发布本地通知。"
        case .urlOpen: "仅在你点按插件组件时打开声明的 HTTPS 链接。"
        case .liveActivityRender: "向通用实时活动组件提供一组受限文本。"
        }
    }

    var systemImage: String {
        switch self {
        case .scheduleRead: "calendar"
        case .weatherRead: "cloud.sun"
        case .networkFetch: "network"
        case .notificationPost: "bell.badge"
        case .urlOpen: "arrow.up.right.square"
        case .liveActivityRender: "platter.filled.top.iphone"
        }
    }
}

struct MobilePluginDependency: Codable, Equatable, Sendable {
    let id: String
    let isRequired: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case isRequired
    }

    init(id: String, isRequired: Bool = true) {
        self.id = id
        self.isRequired = isRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? true
    }
}

struct MobilePluginPlatformManifest: Codable, Equatable, Sendable {
    let apiVersion: Int
    let runtime: String
    let entry: String
    let capabilities: [MobilePluginCapability]
}

struct MobilePluginPackageManifest: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let entranceAssembly: String
    let icon: String
    let readme: String
    let url: String?
    let version: String
    let apiVersion: String
    let author: String
    let dependencies: [MobilePluginDependency]
    let mobile: MobilePluginPlatformManifest

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case entranceAssembly
        case icon
        case readme
        case url
        case version
        case apiVersion
        case author
        case dependencies
        case mobile
    }

    init(
        id: String,
        name: String,
        description: String = "",
        entranceAssembly: String = "",
        icon: String = "icon.png",
        readme: String = "README.md",
        url: String? = nil,
        version: String,
        apiVersion: String = "",
        author: String = "",
        dependencies: [MobilePluginDependency] = [],
        mobile: MobilePluginPlatformManifest
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.entranceAssembly = entranceAssembly
        self.icon = icon
        self.readme = readme
        self.url = url
        self.version = version
        self.apiVersion = apiVersion
        self.author = author
        self.dependencies = dependencies
        self.mobile = mobile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        entranceAssembly = try container.decodeIfPresent(String.self, forKey: .entranceAssembly) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "icon.png"
        readme = try container.decodeIfPresent(String.self, forKey: .readme) ?? "README.md"
        url = try container.decodeIfPresent(String.self, forKey: .url)
        version = try container.decode(String.self, forKey: .version)
        apiVersion = try container.decodeIfPresent(String.self, forKey: .apiVersion) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        dependencies = try container.decodeIfPresent(
            [MobilePluginDependency].self,
            forKey: .dependencies
        ) ?? []
        mobile = try container.decode(MobilePluginPlatformManifest.self, forKey: .mobile)
    }
}

enum MobilePluginSettingType: String, Codable, CaseIterable, Sendable {
    case toggle
    case text
    case number
    case choice
}

enum MobilePluginValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                MobilePluginValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Plugin values must be a Boolean, number, or string."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        }
    }

    var stringValue: String {
        switch self {
        case .bool(let value): value ? "true" : "false"
        case .string(let value): value
        case .number(let value):
            if value.rounded() == value,
               value >= Double(Int.min),
               value <= Double(Int.max) {
                String(Int(value))
            } else {
                String(value)
            }
        }
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }
}

struct MobilePluginSettingOption: Codable, Equatable, Identifiable, Sendable {
    let value: String
    let title: String

    var id: String { value }
}

struct MobilePluginSettingDefinition: Codable, Equatable, Identifiable, Sendable {
    let key: String
    let title: String
    let description: String
    let type: MobilePluginSettingType
    let defaultValue: MobilePluginValue
    let placeholder: String
    let minimum: Double?
    let maximum: Double?
    let step: Double?
    let options: [MobilePluginSettingOption]

    var id: String { key }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case description
        case type
        case defaultValue
        case placeholder
        case minimum
        case maximum
        case step
        case options
    }

    init(
        key: String,
        title: String,
        description: String = "",
        type: MobilePluginSettingType,
        defaultValue: MobilePluginValue,
        placeholder: String = "",
        minimum: Double? = nil,
        maximum: Double? = nil,
        step: Double? = nil,
        options: [MobilePluginSettingOption] = []
    ) {
        self.key = key
        self.title = title
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
        self.placeholder = placeholder
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        type = try container.decode(MobilePluginSettingType.self, forKey: .type)
        defaultValue = try container.decode(MobilePluginValue.self, forKey: .defaultValue)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder) ?? ""
        minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
        maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
        step = try container.decodeIfPresent(Double.self, forKey: .step)
        options = try container.decodeIfPresent(
            [MobilePluginSettingOption].self,
            forKey: .options
        ) ?? []
    }
}

struct MobilePluginCondition: Codable, Equatable, Sendable {
    let source: String
    let equals: String?
    let notEquals: String?
    let isEmpty: Bool?
}

enum MobilePluginActionKind: String, Codable, Sendable {
    case notification = "notification.post"
    case openURL = "url.open"
    case setSetting = "setting.write"
    case networkFetch = "network.fetch"
    case refreshComponents = "components.refresh"
}

struct MobilePluginAction: Codable, Equatable, Sendable {
    let kind: MobilePluginActionKind
    let title: String?
    let body: String?
    let url: String?
    let settingKey: String?
    let value: MobilePluginValue?
    let responseSettingKey: String?
}

enum MobilePluginEventName: String, Codable, CaseIterable, Sendable {
    case appActive = "app.active"
    case scheduleClassStarted = "schedule.classStarted"
    case scheduleBreakStarted = "schedule.breakStarted"
    case scheduleAfterSchool = "schedule.afterSchool"
    case weatherUpdated = "weather.updated"
}

struct MobilePluginEventHandler: Codable, Equatable, Sendable {
    let event: MobilePluginEventName
    let when: MobilePluginCondition?
    let actions: [MobilePluginAction]
}

enum MobilePluginComponentKind: String, Codable, CaseIterable, Sendable {
    case text
    case metric
    case status
    case progress
    case list
}

enum MobilePluginComponentPlacement: String, Codable, Sendable {
    case schedule
}

struct MobilePluginComponentItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    let systemImage: String?
}

struct MobilePluginComponentDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let placement: MobilePluginComponentPlacement
    let kind: MobilePluginComponentKind
    let title: String
    let subtitle: String
    let value: String
    let body: String
    let systemImage: String
    let tint: String?
    let minimum: Double?
    let maximum: Double?
    let items: [MobilePluginComponentItem]
    let when: MobilePluginCondition?
    let action: MobilePluginAction?

    private enum CodingKeys: String, CodingKey {
        case id
        case placement
        case kind
        case title
        case subtitle
        case value
        case body
        case systemImage
        case tint
        case minimum
        case maximum
        case items
        case when
        case action
    }

    init(
        id: String,
        placement: MobilePluginComponentPlacement = .schedule,
        kind: MobilePluginComponentKind,
        title: String,
        subtitle: String = "",
        value: String = "",
        body: String = "",
        systemImage: String = "puzzlepiece.extension",
        tint: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        items: [MobilePluginComponentItem] = [],
        when: MobilePluginCondition? = nil,
        action: MobilePluginAction? = nil
    ) {
        self.id = id
        self.placement = placement
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.body = body
        self.systemImage = systemImage
        self.tint = tint
        self.minimum = minimum
        self.maximum = maximum
        self.items = items
        self.when = when
        self.action = action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        placement = try container.decodeIfPresent(
            MobilePluginComponentPlacement.self,
            forKey: .placement
        ) ?? .schedule
        kind = try container.decode(MobilePluginComponentKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        value = try container.decodeIfPresent(String.self, forKey: .value) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage)
            ?? "puzzlepiece.extension"
        tint = try container.decodeIfPresent(String.self, forKey: .tint)
        minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
        maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
        items = try container.decodeIfPresent([MobilePluginComponentItem].self, forKey: .items) ?? []
        when = try container.decodeIfPresent(MobilePluginCondition.self, forKey: .when)
        action = try container.decodeIfPresent(MobilePluginAction.self, forKey: .action)
    }
}

struct MobilePluginLiveActivityDefinition: Codable, Equatable, Sendable {
    let title: String
    let value: String
    let systemImage: String

    private enum CodingKeys: String, CodingKey {
        case title
        case value
        case systemImage
    }

    init(title: String, value: String, systemImage: String = "puzzlepiece.extension") {
        self.title = title
        self.value = value
        self.systemImage = systemImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        value = try container.decode(String.self, forKey: .value)
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage)
            ?? "puzzlepiece.extension"
    }
}

struct MobilePluginDefinition: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let components: [MobilePluginComponentDefinition]
    let settings: [MobilePluginSettingDefinition]
    let events: [MobilePluginEventHandler]
    let allowedDomains: [String]
    let liveActivity: MobilePluginLiveActivityDefinition?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case components
        case settings
        case events
        case allowedDomains
        case liveActivity
    }

    init(
        schemaVersion: Int,
        components: [MobilePluginComponentDefinition] = [],
        settings: [MobilePluginSettingDefinition] = [],
        events: [MobilePluginEventHandler] = [],
        allowedDomains: [String] = [],
        liveActivity: MobilePluginLiveActivityDefinition? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.components = components
        self.settings = settings
        self.events = events
        self.allowedDomains = allowedDomains
        self.liveActivity = liveActivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        components = try container.decodeIfPresent(
            [MobilePluginComponentDefinition].self,
            forKey: .components
        ) ?? []
        settings = try container.decodeIfPresent(
            [MobilePluginSettingDefinition].self,
            forKey: .settings
        ) ?? []
        events = try container.decodeIfPresent(
            [MobilePluginEventHandler].self,
            forKey: .events
        ) ?? []
        allowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
        liveActivity = try container.decodeIfPresent(
            MobilePluginLiveActivityDefinition.self,
            forKey: .liveActivity
        )
    }
}

struct MobilePluginInstallation: Codable, Equatable, Identifiable, Sendable {
    let manifest: MobilePluginPackageManifest
    let definition: MobilePluginDefinition
    let packageSHA256: String
    let installedAt: Date
    let iconRelativePath: String?

    var id: String { manifest.id }
}

struct MobilePluginState: Codable, Equatable, Sendable {
    let id: String
    var isEnabled: Bool
    var grantedCapabilities: Set<MobilePluginCapability>
}

struct InstalledMobilePlugin: Equatable, Identifiable, Sendable {
    let installation: MobilePluginInstallation
    var state: MobilePluginState

    var id: String { installation.id }
    var manifest: MobilePluginPackageManifest { installation.manifest }
    var definition: MobilePluginDefinition { installation.definition }
}

struct PendingMobilePluginInstall: Identifiable, Sendable {
    let id: UUID
    let stagedPackageURL: URL
    let installation: MobilePluginInstallation
    let isUpdate: Bool
    let initialGrantedCapabilities: Set<MobilePluginCapability>
}

struct MobilePluginRuntimeContext: Sendable {
    let now: Date
    let schedule: ScheduleSnapshot?
    let weather: WeatherSnapshot?
}

struct MobilePluginScheduleCheckpoint: Codable, Equatable, Sendable {
    let date: Date
    let phase: SchedulePhase
    let currentSessionID: String?
    let currentBreakID: String?

    init(snapshot: ScheduleSnapshot) {
        date = snapshot.date
        phase = snapshot.phase
        currentSessionID = snapshot.current?.id
        currentBreakID = snapshot.currentBreak?.id
    }
}

struct RenderedMobilePluginItem: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    let systemImage: String?
}

struct RenderedMobilePluginComponent: Equatable, Identifiable, Sendable {
    let id: String
    let pluginID: String
    let pluginName: String
    let kind: MobilePluginComponentKind
    let title: String
    let subtitle: String
    let value: String
    let body: String
    let systemImage: String
    let tint: String?
    let progress: Double
    let items: [RenderedMobilePluginItem]
    let action: MobilePluginAction?
}

enum MobilePluginError: LocalizedError {
    case packageTooLarge
    case tooManyEntries
    case unsafePath(String)
    case symbolicLink(String)
    case duplicatePath(String)
    case entryTooLarge(String)
    case expandedPackageTooLarge
    case missingManifest
    case missingMobileEntry(String)
    case unsupportedRuntime
    case unsupportedAPIVersion(Int)
    case invalidManifest(String)
    case invalidDefinition(String)
    case invalidPluginID
    case missingDependency(String)
    case pluginNotFound
    case requestDenied(String)
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .packageTooLarge: "插件包超过 20 MB 限制。"
        case .tooManyEntries: "插件包中的文件数量超过限制。"
        case .unsafePath(let path): "插件包包含不安全路径：\(path)"
        case .symbolicLink(let path): "插件包不允许包含符号链接：\(path)"
        case .duplicatePath(let path): "插件包包含重复路径：\(path)"
        case .entryTooLarge(let path): "插件文件超过大小限制：\(path)"
        case .expandedPackageTooLarge: "插件包解压后的总大小超过 20 MB 限制。"
        case .missingManifest: "插件包缺少 manifest.yml。"
        case .missingMobileEntry(let path): "插件包缺少移动入口：\(path)"
        case .unsupportedRuntime: "移动插件 runtime 必须为 declarative。"
        case .unsupportedAPIVersion(let version): "不支持移动插件 API v\(version)。"
        case .invalidManifest(let reason): "插件清单无效：\(reason)"
        case .invalidDefinition(let reason): "移动插件定义无效：\(reason)"
        case .invalidPluginID: "插件 ID 只能包含小写字母、数字、点、连字符和下划线。"
        case .missingDependency(let id): "缺少必需插件：\(id)"
        case .pluginNotFound: "找不到已安装的插件。"
        case .requestDenied(let reason): "插件请求被拒绝：\(reason)"
        case .responseTooLarge: "插件网络响应超过 256 KB 限制。"
        }
    }
}
