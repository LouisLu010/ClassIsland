import Foundation

enum LiveActivityRegion: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case lockHeader
    case lockPrimary
    case lockProgress
    case lockFooter
    case expandedLeading
    case expandedCenter
    case expandedTrailing
    case expandedBottom
    case compactLeading
    case compactTrailing
    case minimal
    case notificationTitle
    case notificationBody

    var id: Self { self }

    var title: String {
        switch self {
        case .lockHeader: "顶部行"
        case .lockPrimary: "主要内容"
        case .lockProgress: "进度行"
        case .lockFooter: "底部行"
        case .expandedLeading: "左侧"
        case .expandedCenter: "中央"
        case .expandedTrailing: "右侧"
        case .expandedBottom: "底部"
        case .compactLeading: "左侧紧凑区"
        case .compactTrailing: "右侧紧凑区"
        case .minimal: "最小视图"
        case .notificationTitle: "通知标题"
        case .notificationBody: "通知正文"
        }
    }

    var maximumComponentCount: Int {
        switch self {
        case .compactLeading, .compactTrailing, .minimal: 1
        case .expandedLeading, .expandedCenter, .expandedTrailing, .notificationTitle: 2
        case .lockHeader, .lockPrimary, .lockProgress, .lockFooter, .expandedBottom, .notificationBody: 4
        }
    }
}

enum LiveActivityComponentKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case status
    case currentLesson
    case countdown
    case progress
    case nextLesson
    case profileName
    case weather
    case clock
    case date
    case plugin
    case customText

    var id: Self { self }

    var title: String {
        switch self {
        case .status: "课程状态"
        case .currentLesson: "当前课程"
        case .countdown: "课程倒计时"
        case .progress: "课程进度"
        case .nextLesson: "下一节课"
        case .profileName: "档案名称"
        case .weather: "天气"
        case .clock: "时钟"
        case .date: "日期"
        case .plugin: "插件信息"
        case .customText: "自定义文本"
        }
    }

    var description: String {
        switch self {
        case .status: "显示上课、课间或放学状态。"
        case .currentLesson: "显示当前课程及任课教师。"
        case .countdown: "显示当前阶段的剩余时间。"
        case .progress: "显示当前阶段的时间进度。"
        case .nextLesson: "显示下一节课程及开始时间。"
        case .profileName: "显示当前档案名称。"
        case .weather: "显示天气、湿度、风速、AQI、气压或体感温度。"
        case .clock: "显示当前时间，可选择显示秒数。"
        case .date: "显示随日期变化自动更新的当前日期。"
        case .plugin: "显示已授权插件提供的一组受限文本。"
        case .customText: "显示一段自定义文本。"
        }
    }

    var systemImage: String {
        switch self {
        case .status: "tag"
        case .currentLesson: "book.closed"
        case .countdown: "timer"
        case .progress: "chart.bar.fill"
        case .nextLesson: "arrow.right.circle"
        case .profileName: "person.crop.rectangle"
        case .weather: "cloud.sun"
        case .clock: "clock"
        case .date: "calendar"
        case .plugin: "puzzlepiece.extension"
        case .customText: "textformat"
        }
    }
}

struct LiveActivityComponentConfiguration: Codable, Equatable, Hashable, Identifiable, Sendable {
    static let maximumCustomTextLength = 16

    var id: UUID
    var kind: LiveActivityComponentKind
    var customText: String
    var isEmphasized: Bool
    var showsIcon: Bool
    var weatherMetric: WeatherMetric
    var clockShowsSeconds: Bool
    var clockUsesSystemTime: Bool

    private enum CodingKeys: String, CodingKey {
        case kind = "k"
        case customText = "t"
        case isEmphasized = "e"
        case showsIcon = "s"
        case weatherMetric = "w"
        case clockShowsSeconds = "c"
        case clockUsesSystemTime = "r"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case kind
        case customText
        case isEmphasized
        case showsIcon
        case weatherMetric
        case clockShowsSeconds
        case clockUsesSystemTime
    }

    init(
        id: UUID = UUID(),
        kind: LiveActivityComponentKind,
        customText: String = "",
        isEmphasized: Bool = false,
        showsIcon: Bool = true,
        weatherMetric: WeatherMetric = .condition,
        clockShowsSeconds: Bool = false,
        clockUsesSystemTime: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.customText = String(customText.prefix(Self.maximumCustomTextLength))
        self.isEmphasized = isEmphasized
        self.showsIcon = showsIcon
        self.weatherMetric = weatherMetric
        self.clockShowsSeconds = clockShowsSeconds
        self.clockUsesSystemTime = clockUsesSystemTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        id = UUID()
        if let decodedKind = try container.decodeIfPresent(LiveActivityComponentKind.self, forKey: .kind) {
            kind = decodedKind
        } else {
            kind = try legacy.decode(LiveActivityComponentKind.self, forKey: .kind)
        }
        let decodedText = try container.decodeIfPresent(String.self, forKey: .customText)
        let legacyText = try legacy.decodeIfPresent(String.self, forKey: .customText)
        customText = String(
            (decodedText ?? legacyText ?? "")
                .prefix(Self.maximumCustomTextLength)
        )
        let decodedEmphasis = try container.decodeIfPresent(Bool.self, forKey: .isEmphasized)
        let legacyEmphasis = try legacy.decodeIfPresent(Bool.self, forKey: .isEmphasized)
        isEmphasized = decodedEmphasis ?? legacyEmphasis ?? false
        let decodedShowsIcon = try container.decodeIfPresent(Bool.self, forKey: .showsIcon)
        let legacyShowsIcon = try legacy.decodeIfPresent(Bool.self, forKey: .showsIcon)
        showsIcon = decodedShowsIcon ?? legacyShowsIcon ?? true
        let decodedWeatherMetric = try container.decodeIfPresent(
            WeatherMetric.self,
            forKey: .weatherMetric
        )
        let legacyWeatherMetric = try legacy.decodeIfPresent(
            WeatherMetric.self,
            forKey: .weatherMetric
        )
        weatherMetric = decodedWeatherMetric ?? legacyWeatherMetric ?? .condition
        let decodedClockShowsSeconds = try container.decodeIfPresent(
            Bool.self,
            forKey: .clockShowsSeconds
        )
        let legacyClockShowsSeconds = try legacy.decodeIfPresent(
            Bool.self,
            forKey: .clockShowsSeconds
        )
        clockShowsSeconds = decodedClockShowsSeconds ?? legacyClockShowsSeconds ?? false
        let decodedClockUsesSystemTime = try container.decodeIfPresent(
            Bool.self,
            forKey: .clockUsesSystemTime
        )
        let legacyClockUsesSystemTime = try legacy.decodeIfPresent(
            Bool.self,
            forKey: .clockUsesSystemTime
        )
        clockUsesSystemTime = decodedClockUsesSystemTime ?? legacyClockUsesSystemTime ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        if kind == .customText && !customText.isEmpty {
            try container.encode(customText, forKey: .customText)
        }
        if isEmphasized {
            try container.encode(true, forKey: .isEmphasized)
        }
        if !showsIcon {
            try container.encode(false, forKey: .showsIcon)
        }
        if kind == .weather && weatherMetric != .condition {
            try container.encode(weatherMetric, forKey: .weatherMetric)
        }
        if kind == .clock && clockShowsSeconds {
            try container.encode(true, forKey: .clockShowsSeconds)
        }
        if kind == .clock && clockUsesSystemTime {
            try container.encode(true, forKey: .clockUsesSystemTime)
        }
    }

    static func == (
        lhs: LiveActivityComponentConfiguration,
        rhs: LiveActivityComponentConfiguration
    ) -> Bool {
        lhs.kind == rhs.kind
            && lhs.customText == rhs.customText
            && lhs.isEmphasized == rhs.isEmphasized
            && lhs.showsIcon == rhs.showsIcon
            && lhs.weatherMetric == rhs.weatherMetric
            && lhs.clockShowsSeconds == rhs.clockShowsSeconds
            && lhs.clockUsesSystemTime == rhs.clockUsesSystemTime
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(customText)
        hasher.combine(isEmphasized)
        hasher.combine(showsIcon)
        hasher.combine(weatherMetric)
        hasher.combine(clockShowsSeconds)
        hasher.combine(clockUsesSystemTime)
    }

    fileprivate func normalized() -> LiveActivityComponentConfiguration {
        var result = self
        if kind == .customText {
            let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            result.customText = trimmed.isEmpty
                ? "ClassIsland"
                : String(customText.prefix(Self.maximumCustomTextLength))
        } else {
            result.customText = ""
        }
        if kind != .weather {
            result.weatherMetric = .condition
        }
        if kind != .clock {
            result.clockShowsSeconds = false
            result.clockUsesSystemTime = false
        }
        return result
    }
}

struct LiveActivityLayout: Codable, Equatable, Hashable, Sendable {
    private var storage: [LiveActivityRegion: [LiveActivityComponentConfiguration]]

    private enum CodingKeys: String, CodingKey {
        case regions
    }

    init(storage: [LiveActivityRegion: [LiveActivityComponentConfiguration]]) {
        self.storage = storage
        normalize()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let encoded = try container.decodeIfPresent(
            [String: [LiveActivityComponentConfiguration]].self,
            forKey: .regions
        ) ?? [:]
        storage = Self.default.storage
        for (key, components) in encoded {
            guard let region = LiveActivityRegion(rawValue: key) else { continue }
            storage[region] = components
        }
        normalize()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encoded = Dictionary(uniqueKeysWithValues: storage.map { ($0.key.rawValue, $0.value) })
        try container.encode(encoded, forKey: .regions)
    }

    func components(in region: LiveActivityRegion) -> [LiveActivityComponentConfiguration] {
        storage[region] ?? []
    }

    var activityKitPayloadLayout: LiveActivityLayout {
        var result = self
        result.setComponents([], in: .notificationTitle)
        result.setComponents([], in: .notificationBody)
        return result
    }

    static func == (lhs: LiveActivityLayout, rhs: LiveActivityLayout) -> Bool {
        LiveActivityRegion.allCases.allSatisfy {
            lhs.components(in: $0) == rhs.components(in: $0)
        }
    }

    func hash(into hasher: inout Hasher) {
        for region in LiveActivityRegion.allCases {
            hasher.combine(region)
            for component in components(in: region) {
                hasher.combine(component)
            }
        }
    }

    mutating func setComponents(
        _ components: [LiveActivityComponentConfiguration],
        in region: LiveActivityRegion
    ) {
        storage[region] = Array(components.prefix(region.maximumComponentCount)).map { $0.normalized() }
    }

    mutating func add(
        _ component: LiveActivityComponentConfiguration,
        to region: LiveActivityRegion
    ) {
        var components = self.components(in: region)
        let normalized = component.normalized()
        if region.maximumComponentCount == 1 {
            components = [normalized]
        } else if components.count < region.maximumComponentCount {
            components.append(normalized)
        }
        storage[region] = components
    }

    mutating func update(
        _ component: LiveActivityComponentConfiguration,
        in region: LiveActivityRegion
    ) {
        var components = self.components(in: region)
        guard let index = components.firstIndex(where: { $0.id == component.id }) else { return }
        components[index] = component.normalized()
        storage[region] = components
    }

    mutating func remove(at offsets: IndexSet, from region: LiveActivityRegion) {
        var components = self.components(in: region)
        for index in offsets.sorted(by: >) where components.indices.contains(index) {
            components.remove(at: index)
        }
        storage[region] = components
    }

    mutating func move(from offsets: IndexSet, to destination: Int, in region: LiveActivityRegion) {
        var components = self.components(in: region)
        let moving = offsets.sorted().compactMap { components.indices.contains($0) ? components[$0] : nil }
        for index in offsets.sorted(by: >) where components.indices.contains(index) {
            components.remove(at: index)
        }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertion = min(max(destination - removedBeforeDestination, 0), components.count)
        components.insert(contentsOf: moving, at: insertion)
        storage[region] = components
    }

    mutating func reset(region: LiveActivityRegion) {
        storage[region] = Self.default.components(in: region)
    }

    private mutating func normalize() {
        for region in LiveActivityRegion.allCases {
            storage[region] = Array((storage[region] ?? []).prefix(region.maximumComponentCount))
                .map { $0.normalized() }
        }
    }

    static let `default` = LiveActivityLayout(storage: [
        .lockHeader: [
            LiveActivityComponentConfiguration(kind: .status, isEmphasized: true),
            LiveActivityComponentConfiguration(kind: .weather),
            LiveActivityComponentConfiguration(kind: .profileName, showsIcon: false)
        ],
        .lockPrimary: [
            LiveActivityComponentConfiguration(kind: .currentLesson, isEmphasized: true),
            LiveActivityComponentConfiguration(kind: .countdown, isEmphasized: true, showsIcon: false)
        ],
        .lockProgress: [
            LiveActivityComponentConfiguration(kind: .progress, showsIcon: false)
        ],
        .lockFooter: [
            LiveActivityComponentConfiguration(kind: .nextLesson)
        ],
        .expandedLeading: [
            LiveActivityComponentConfiguration(kind: .status, isEmphasized: true),
            LiveActivityComponentConfiguration(kind: .weather)
        ],
        .expandedCenter: [
            LiveActivityComponentConfiguration(kind: .currentLesson, isEmphasized: true, showsIcon: false)
        ],
        .expandedTrailing: [
            LiveActivityComponentConfiguration(kind: .countdown, isEmphasized: true, showsIcon: false)
        ],
        .expandedBottom: [
            LiveActivityComponentConfiguration(kind: .nextLesson),
            LiveActivityComponentConfiguration(kind: .progress, showsIcon: false)
        ],
        .compactLeading: [
            LiveActivityComponentConfiguration(kind: .currentLesson, isEmphasized: true, showsIcon: false)
        ],
        .compactTrailing: [
            LiveActivityComponentConfiguration(kind: .countdown, isEmphasized: true, showsIcon: false)
        ],
        .minimal: [
            LiveActivityComponentConfiguration(kind: .status, isEmphasized: true, showsIcon: true)
        ],
        .notificationTitle: [
            LiveActivityComponentConfiguration(kind: .status, isEmphasized: true, showsIcon: false)
        ],
        .notificationBody: [
            LiveActivityComponentConfiguration(kind: .currentLesson, showsIcon: false),
            LiveActivityComponentConfiguration(kind: .nextLesson, showsIcon: false)
        ]
    ])
}
