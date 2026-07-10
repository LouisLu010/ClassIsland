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
        }
    }

    var maximumComponentCount: Int {
        switch self {
        case .compactLeading, .compactTrailing, .minimal: 1
        case .expandedLeading, .expandedCenter, .expandedTrailing: 2
        case .lockHeader, .lockPrimary, .lockProgress, .lockFooter, .expandedBottom: 4
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
    case clock
    case date
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
        case .clock: "更新时间"
        case .date: "日期"
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
        case .clock: "显示实时活动最近更新时间。"
        case .date: "显示当前日期。"
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
        case .clock: "clock"
        case .date: "calendar"
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

    private enum CodingKeys: String, CodingKey {
        case kind = "k"
        case customText = "t"
        case isEmphasized = "e"
        case showsIcon = "s"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case kind
        case customText
        case isEmphasized
        case showsIcon
    }

    init(
        id: UUID = UUID(),
        kind: LiveActivityComponentKind,
        customText: String = "",
        isEmphasized: Bool = false,
        showsIcon: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.customText = String(customText.prefix(Self.maximumCustomTextLength))
        self.isEmphasized = isEmphasized
        self.showsIcon = showsIcon
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
    }

    static func == (
        lhs: LiveActivityComponentConfiguration,
        rhs: LiveActivityComponentConfiguration
    ) -> Bool {
        lhs.kind == rhs.kind
            && lhs.customText == rhs.customText
            && lhs.isEmphasized == rhs.isEmphasized
            && lhs.showsIcon == rhs.showsIcon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(customText)
        hasher.combine(isEmphasized)
        hasher.combine(showsIcon)
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
            LiveActivityComponentConfiguration(kind: .status, isEmphasized: true)
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
        ]
    ])
}
