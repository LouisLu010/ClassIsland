import Foundation

struct ClassIslandProfile: Codable, Equatable, Sendable {
    var name: String
    var id: String
    var timeLayouts: [String: ClassIslandTimeLayout]
    var classPlans: [String: ClassIslandClassPlan]
    var subjects: [String: ClassIslandSubject]
    var classPlanGroups: [String: ClassIslandClassPlanGroup]
    var orderedSchedules: [String: ClassIslandOrderedSchedule]
    var isOverlayClassPlanEnabled: Bool
    var overlayClassPlanId: String?
    var tempClassPlanId: String?
    var tempClassPlanSetupTime: String?
    var selectedClassPlanGroupId: String
    var tempClassPlanGroupId: String?
    var tempClassPlanGroupExpireTime: String?
    var isTempClassPlanGroupEnabled: Bool
    var tempClassPlanGroupType: Int

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case timeLayouts = "TimeLayouts"
        case classPlans = "ClassPlans"
        case subjects = "Subjects"
        case classPlanGroups = "ClassPlanGroups"
        case orderedSchedules = "OrderedSchedules"
        case isOverlayClassPlanEnabled = "IsOverlayClassPlanEnabled"
        case overlayClassPlanId = "OverlayClassPlanId"
        case tempClassPlanId = "TempClassPlanId"
        case tempClassPlanSetupTime = "TempClassPlanSetupTime"
        case selectedClassPlanGroupId = "SelectedClassPlanGroupId"
        case tempClassPlanGroupId = "TempClassPlanGroupId"
        case tempClassPlanGroupExpireTime = "TempClassPlanGroupExpireTime"
        case isTempClassPlanGroupEnabled = "IsTempClassPlanGroupEnabled"
        case tempClassPlanGroupType = "TempClassPlanGroupType"
    }

    init(
        name: String,
        id: String = UUID().uuidString.uppercased(),
        timeLayouts: [String: ClassIslandTimeLayout],
        classPlans: [String: ClassIslandClassPlan],
        subjects: [String: ClassIslandSubject],
        classPlanGroups: [String: ClassIslandClassPlanGroup] = ClassIslandClassPlanGroup.requiredGroups,
        orderedSchedules: [String: ClassIslandOrderedSchedule] = [:],
        isOverlayClassPlanEnabled: Bool = false,
        overlayClassPlanId: String? = nil,
        tempClassPlanId: String? = nil,
        tempClassPlanSetupTime: String? = nil,
        selectedClassPlanGroupId: String = ClassIslandClassPlan.defaultGroupId,
        tempClassPlanGroupId: String? = nil,
        tempClassPlanGroupExpireTime: String? = nil,
        isTempClassPlanGroupEnabled: Bool = false,
        tempClassPlanGroupType: Int = 1
    ) {
        self.name = name
        self.id = id
        self.timeLayouts = timeLayouts
        self.classPlans = classPlans
        self.subjects = subjects
        self.classPlanGroups = classPlanGroups
        self.orderedSchedules = orderedSchedules
        self.isOverlayClassPlanEnabled = isOverlayClassPlanEnabled
        self.overlayClassPlanId = overlayClassPlanId
        self.tempClassPlanId = tempClassPlanId
        self.tempClassPlanSetupTime = tempClassPlanSetupTime
        self.selectedClassPlanGroupId = selectedClassPlanGroupId
        self.tempClassPlanGroupId = tempClassPlanGroupId
        self.tempClassPlanGroupExpireTime = tempClassPlanGroupExpireTime
        self.isTempClassPlanGroupEnabled = isTempClassPlanGroupEnabled
        self.tempClassPlanGroupType = tempClassPlanGroupType
        ensureRequiredGroups()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.uppercased()
        timeLayouts = try container.decodeIfPresent([String: ClassIslandTimeLayout].self, forKey: .timeLayouts) ?? [:]
        classPlans = try container.decodeIfPresent([String: ClassIslandClassPlan].self, forKey: .classPlans) ?? [:]
        subjects = try container.decodeIfPresent([String: ClassIslandSubject].self, forKey: .subjects) ?? [:]
        classPlanGroups = try container.decodeIfPresent(
            [String: ClassIslandClassPlanGroup].self,
            forKey: .classPlanGroups
        ) ?? [:]
        orderedSchedules = try container.decodeIfPresent(
            [String: ClassIslandOrderedSchedule].self,
            forKey: .orderedSchedules
        ) ?? [:]
        isOverlayClassPlanEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isOverlayClassPlanEnabled
        ) ?? false
        overlayClassPlanId = try container.decodeIfPresent(String.self, forKey: .overlayClassPlanId)
        tempClassPlanId = try container.decodeIfPresent(String.self, forKey: .tempClassPlanId)
        tempClassPlanSetupTime = try container.decodeIfPresent(String.self, forKey: .tempClassPlanSetupTime)
        selectedClassPlanGroupId = try container.decodeIfPresent(String.self, forKey: .selectedClassPlanGroupId)
            ?? ClassIslandClassPlan.defaultGroupId
        tempClassPlanGroupId = try container.decodeIfPresent(String.self, forKey: .tempClassPlanGroupId)
        tempClassPlanGroupExpireTime = try container.decodeIfPresent(
            String.self,
            forKey: .tempClassPlanGroupExpireTime
        )
        isTempClassPlanGroupEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isTempClassPlanGroupEnabled
        ) ?? false
        tempClassPlanGroupType = try container.decodeIfPresent(Int.self, forKey: .tempClassPlanGroupType) ?? 1
        ensureRequiredGroups()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(id, forKey: .id)
        try container.encode(timeLayouts, forKey: .timeLayouts)
        try container.encode(classPlans, forKey: .classPlans)
        try container.encode(subjects, forKey: .subjects)
        try container.encode(classPlanGroups, forKey: .classPlanGroups)
        try container.encode(orderedSchedules, forKey: .orderedSchedules)
        try container.encode(isOverlayClassPlanEnabled, forKey: .isOverlayClassPlanEnabled)
        try container.encodeOptional(overlayClassPlanId, forKey: .overlayClassPlanId)
        try container.encodeOptional(tempClassPlanId, forKey: .tempClassPlanId)
        try container.encodeOptional(tempClassPlanSetupTime, forKey: .tempClassPlanSetupTime)
        try container.encode(selectedClassPlanGroupId, forKey: .selectedClassPlanGroupId)
        try container.encodeOptional(tempClassPlanGroupId, forKey: .tempClassPlanGroupId)
        try container.encodeOptional(tempClassPlanGroupExpireTime, forKey: .tempClassPlanGroupExpireTime)
        try container.encode(isTempClassPlanGroupEnabled, forKey: .isTempClassPlanGroupEnabled)
        try container.encode(tempClassPlanGroupType, forKey: .tempClassPlanGroupType)
    }

    static func newProfile(name: String = "新档案") -> ClassIslandProfile {
        let subjectId = UUID().uuidString.uppercased()
        let timeLayoutId = UUID().uuidString.uppercased()
        let classTimes = [
            ("08:00:00", "08:45:00"),
            ("08:55:00", "09:40:00"),
            ("10:00:00", "10:45:00"),
            ("10:55:00", "11:40:00")
        ]
        var points: [ClassIslandTimePoint] = []
        for (index, time) in classTimes.enumerated() {
            points.append(ClassIslandTimePoint(startTimeValue: time.0, endTimeValue: time.1, timeType: 0))
            if index < classTimes.count - 1 {
                points.append(
                    ClassIslandTimePoint(
                        startTimeValue: time.1,
                        endTimeValue: classTimes[index + 1].0,
                        timeType: 1,
                        breakName: index == 1 ? "大课间" : "课间休息"
                    )
                )
            }
        }

        let subjects = [
            subjectId: ClassIslandSubject(name: "未设置", initial: "?", teacherName: "", isOutdoor: false)
        ]
        let timeLayouts = [
            timeLayoutId: ClassIslandTimeLayout(name: "标准上午", layouts: points)
        ]
        var classPlans: [String: ClassIslandClassPlan] = [:]
        for weekday in 1...5 {
            let planId = UUID().uuidString.uppercased()
            classPlans[planId] = ClassIslandClassPlan(
                timeLayoutId: timeLayoutId,
                timeRule: ClassIslandTimeRule(weekDay: weekday, weekCountDiv: 0, weekCountDivTotal: 2),
                classes: classTimes.map { _ in ClassIslandClassInfo(subjectId: subjectId) },
                name: "周\(Self.weekdayName(weekday))课表"
            )
        }

        return ClassIslandProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新档案" : name,
            timeLayouts: timeLayouts,
            classPlans: classPlans,
            subjects: subjects
        )
    }

    mutating func ensureRequiredGroups() {
        if let defaultKey = key(in: classPlanGroups, matching: ClassIslandClassPlan.defaultGroupId),
           var group = classPlanGroups[defaultKey] {
            group.isGlobal = false
            classPlanGroups[defaultKey] = group
        } else {
            classPlanGroups[ClassIslandClassPlan.defaultGroupId] = ClassIslandClassPlanGroup(name: "默认")
        }
        if let globalKey = key(in: classPlanGroups, matching: ClassIslandClassPlan.globalGroupId),
           var group = classPlanGroups[globalKey] {
            group.isGlobal = true
            classPlanGroups[globalKey] = group
        } else {
            classPlanGroups[ClassIslandClassPlan.globalGroupId] = ClassIslandClassPlanGroup(
                name: "全局课表群",
                isGlobal: true
            )
        }
        if key(in: classPlanGroups, matching: selectedClassPlanGroupId) == nil {
            selectedClassPlanGroupId = ClassIslandClassPlan.defaultGroupId
        }
    }

    func key<Value>(in dictionary: [String: Value], matching id: String) -> String? {
        dictionary.keys.first { $0.caseInsensitiveCompare(id) == .orderedSame }
    }

    private static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 0: "日"
        case 1: "一"
        case 2: "二"
        case 3: "三"
        case 4: "四"
        case 5: "五"
        case 6: "六"
        default: "?"
        }
    }
}

struct ClassIslandTimeLayout: Codable, Equatable, Sendable {
    var name: String
    var layouts: [ClassIslandTimePoint]
    var isOverlay: Bool
    var overlaySourceId: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case layouts = "Layouts"
        case isOverlay = "IsOverlay"
        case overlaySourceId = "OverlaySourceId"
    }

    init(
        name: String = "新时间表",
        layouts: [ClassIslandTimePoint] = [],
        isOverlay: Bool = false,
        overlaySourceId: String? = nil
    ) {
        self.name = name
        self.layouts = layouts
        self.isOverlay = isOverlay
        self.overlaySourceId = overlaySourceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        layouts = try container.decodeIfPresent([ClassIslandTimePoint].self, forKey: .layouts) ?? []
        isOverlay = try container.decodeIfPresent(Bool.self, forKey: .isOverlay) ?? false
        overlaySourceId = try container.decodeIfPresent(String.self, forKey: .overlaySourceId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(layouts, forKey: .layouts)
        try container.encode(isOverlay, forKey: .isOverlay)
        try container.encodeOptional(overlaySourceId, forKey: .overlaySourceId)
    }
}

struct ClassIslandTimePoint: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var startTimeValue: String
    var endTimeValue: String
    var timeType: Int
    var isHideDefault: Bool
    var defaultClassId: String
    var breakName: String
    private var extraFields: [String: ProfileJSONValue]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case startTime = "StartTime"
        case endTime = "EndTime"
        case startSecond = "StartSecond"
        case endSecond = "EndSecond"
        case timeType = "TimeType"
        case isHideDefault = "IsHideDefault"
        case defaultClassId = "DefaultClassId"
        case breakName = "BreakName"
    }

    init(
        id: UUID = UUID(),
        startTimeValue: String,
        endTimeValue: String,
        timeType: Int,
        isHideDefault: Bool = false,
        defaultClassId: String = "00000000-0000-0000-0000-000000000000",
        breakName: String = ""
    ) {
        self.id = id
        self.startTimeValue = startTimeValue
        self.endTimeValue = endTimeValue
        self.timeType = timeType
        self.isHideDefault = isHideDefault
        self.defaultClassId = defaultClassId
        self.breakName = breakName
        extraFields = [:]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        let currentStart = try container.decodeIfPresent(String.self, forKey: .startTime)
        let currentEnd = try container.decodeIfPresent(String.self, forKey: .endTime)
        let legacyStart = try container.decodeIfPresent(String.self, forKey: .startSecond)
        let legacyEnd = try container.decodeIfPresent(String.self, forKey: .endSecond)
        startTimeValue = canonicalProfileTime(
            [currentStart, legacyStart].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        )
        endTimeValue = canonicalProfileTime(
            [currentEnd, legacyEnd].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        )
        timeType = try container.decodeIfPresent(Int.self, forKey: .timeType) ?? 0
        isHideDefault = try container.decodeIfPresent(Bool.self, forKey: .isHideDefault) ?? false
        defaultClassId = try container.decodeIfPresent(String.self, forKey: .defaultClassId)
            ?? "00000000-0000-0000-0000-000000000000"
        breakName = try container.decodeIfPresent(String.self, forKey: .breakName) ?? ""
        extraFields = try decodeExtraFields(
            from: decoder,
            knownKeys: CodingKeys.allCases.map(\.rawValue)
        )
    }

    func encode(to encoder: Encoder) throws {
        try encodeExtraFields(
            extraFields,
            to: encoder,
            knownKeys: CodingKeys.allCases.map(\.rawValue)
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startTimeValue, forKey: .startTime)
        try container.encode(endTimeValue, forKey: .endTime)
        try container.encode("", forKey: .startSecond)
        try container.encode("", forKey: .endSecond)
        try container.encode(timeType, forKey: .timeType)
        try container.encode(isHideDefault, forKey: .isHideDefault)
        try container.encode(defaultClassId, forKey: .defaultClassId)
        try container.encode(breakName, forKey: .breakName)
    }

    var displayBreakName: String {
        breakName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "课间休息" : breakName
    }

    static func == (lhs: ClassIslandTimePoint, rhs: ClassIslandTimePoint) -> Bool {
        lhs.startTimeValue == rhs.startTimeValue
            && lhs.endTimeValue == rhs.endTimeValue
            && lhs.timeType == rhs.timeType
            && lhs.isHideDefault == rhs.isHideDefault
            && lhs.defaultClassId.caseInsensitiveCompare(rhs.defaultClassId) == .orderedSame
            && lhs.breakName == rhs.breakName
            && lhs.extraFields == rhs.extraFields
    }
}

struct ClassIslandClassPlan: Codable, Equatable, Sendable {
    static let defaultGroupId = "ACAF4EF0-E261-4262-B941-34EA93CB4369"
    static let globalGroupId = "00000000-0000-0000-0000-000000000000"

    var timeLayoutId: String
    var timeRule: ClassIslandTimeRule
    var classes: [ClassIslandClassInfo]
    var name: String
    var isOverlay: Bool
    var overlaySourceId: String?
    var overlaySetupTime: String?
    var isEnabled: Bool
    var associatedGroup: String

    enum CodingKeys: String, CodingKey {
        case timeLayoutId = "TimeLayoutId"
        case timeRule = "TimeRule"
        case classes = "Classes"
        case name = "Name"
        case isOverlay = "IsOverlay"
        case overlaySourceId = "OverlaySourceId"
        case overlaySetupTime = "OverlaySetupTime"
        case isEnabled = "IsEnabled"
        case associatedGroup = "AssociatedGroup"
    }

    init(
        timeLayoutId: String,
        timeRule: ClassIslandTimeRule = .everyWeek,
        classes: [ClassIslandClassInfo] = [],
        name: String = "新课表",
        isOverlay: Bool = false,
        overlaySourceId: String? = nil,
        overlaySetupTime: String? = nil,
        isEnabled: Bool = true,
        associatedGroup: String = Self.defaultGroupId
    ) {
        self.timeLayoutId = timeLayoutId
        self.timeRule = timeRule
        self.classes = classes
        self.name = name
        self.isOverlay = isOverlay
        self.overlaySourceId = overlaySourceId
        self.overlaySetupTime = overlaySetupTime
        self.isEnabled = isEnabled
        self.associatedGroup = associatedGroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeLayoutId = try container.decodeIfPresent(String.self, forKey: .timeLayoutId) ?? ""
        timeRule = try container.decodeIfPresent(ClassIslandTimeRule.self, forKey: .timeRule) ?? .everyWeek
        classes = try container.decodeIfPresent([ClassIslandClassInfo].self, forKey: .classes) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        isOverlay = try container.decodeIfPresent(Bool.self, forKey: .isOverlay) ?? false
        overlaySourceId = try container.decodeIfPresent(String.self, forKey: .overlaySourceId)
        overlaySetupTime = try container.decodeIfPresent(String.self, forKey: .overlaySetupTime)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        associatedGroup = try container.decodeIfPresent(String.self, forKey: .associatedGroup) ?? Self.defaultGroupId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeLayoutId, forKey: .timeLayoutId)
        try container.encode(timeRule, forKey: .timeRule)
        try container.encode(classes, forKey: .classes)
        try container.encode(name, forKey: .name)
        try container.encode(isOverlay, forKey: .isOverlay)
        try container.encodeOptional(overlaySourceId, forKey: .overlaySourceId)
        try container.encodeOptional(overlaySetupTime, forKey: .overlaySetupTime)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(associatedGroup, forKey: .associatedGroup)
    }
}

struct ClassIslandTimeRule: Codable, Equatable, Sendable {
    static let everyWeek = ClassIslandTimeRule(weekDay: 0, weekCountDiv: 0, weekCountDivTotal: 2)

    var weekDay: Int
    var weekCountDiv: Int
    var weekCountDivTotal: Int

    enum CodingKeys: String, CodingKey {
        case weekDay = "WeekDay"
        case weekCountDiv = "WeekCountDiv"
        case weekCountDivTotal = "WeekCountDivTotal"
    }

    init(weekDay: Int, weekCountDiv: Int, weekCountDivTotal: Int) {
        self.weekDay = min(max(weekDay, 0), 6)
        self.weekCountDivTotal = max(2, weekCountDivTotal)
        self.weekCountDiv = min(max(weekCountDiv, 0), self.weekCountDivTotal)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let total = max(2, try container.decodeIfPresent(Int.self, forKey: .weekCountDivTotal) ?? 2)
        weekDay = min(max(try container.decodeIfPresent(Int.self, forKey: .weekDay) ?? 0, 0), 6)
        weekCountDiv = min(max(try container.decodeIfPresent(Int.self, forKey: .weekCountDiv) ?? 0, 0), total)
        weekCountDivTotal = total
    }
}

struct ClassIslandClassInfo: Codable, Equatable, Sendable {
    var subjectId: String
    var isChangedClass: Bool
    var isEnabled: Bool
    private var extraFields: [String: ProfileJSONValue]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case subjectId = "SubjectId"
        case isChangedClass = "IsChangedClass"
        case isEnabled = "IsEnabled"
    }

    init(
        subjectId: String = "00000000-0000-0000-0000-000000000000",
        isChangedClass: Bool = false,
        isEnabled: Bool = true
    ) {
        self.subjectId = subjectId
        self.isChangedClass = isChangedClass
        self.isEnabled = isEnabled
        extraFields = [:]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjectId = try container.decodeIfPresent(String.self, forKey: .subjectId)
            ?? "00000000-0000-0000-0000-000000000000"
        isChangedClass = try container.decodeIfPresent(Bool.self, forKey: .isChangedClass) ?? false
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        extraFields = try decodeExtraFields(
            from: decoder,
            knownKeys: CodingKeys.allCases.map(\.rawValue)
        )
    }

    func encode(to encoder: Encoder) throws {
        try encodeExtraFields(
            extraFields,
            to: encoder,
            knownKeys: CodingKeys.allCases.map(\.rawValue)
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subjectId, forKey: .subjectId)
        try container.encode(isChangedClass, forKey: .isChangedClass)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

struct ClassIslandSubject: Codable, Equatable, Sendable {
    var name: String
    var initial: String
    var teacherName: String
    var isOutdoor: Bool

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case initial = "Initial"
        case teacherName = "TeacherName"
        case isOutdoor = "IsOutDoor"
    }

    init(name: String = "未命名课程", initial: String = "", teacherName: String = "", isOutdoor: Bool = false) {
        self.name = name
        self.initial = initial
        self.teacherName = teacherName
        self.isOutdoor = isOutdoor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名课程"
        initial = try container.decodeIfPresent(String.self, forKey: .initial) ?? ""
        teacherName = try container.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        isOutdoor = try container.decodeIfPresent(Bool.self, forKey: .isOutdoor) ?? false
    }
}

struct ClassIslandClassPlanGroup: Codable, Equatable, Sendable {
    var name: String
    var isGlobal: Bool

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case isGlobal = "IsGlobal"
    }

    init(name: String = "新课表群", isGlobal: Bool = false) {
        self.name = name
        self.isGlobal = isGlobal
    }

    static var requiredGroups: [String: ClassIslandClassPlanGroup] {
        [
            ClassIslandClassPlan.defaultGroupId: ClassIslandClassPlanGroup(name: "默认"),
            ClassIslandClassPlan.globalGroupId: ClassIslandClassPlanGroup(name: "全局课表群", isGlobal: true)
        ]
    }
}

struct ClassIslandOrderedSchedule: Codable, Equatable, Sendable {
    var classPlanId: String

    enum CodingKeys: String, CodingKey {
        case classPlanId = "ClassPlanId"
    }

    init(classPlanId: String) {
        self.classPlanId = classPlanId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classPlanId = try container.decodeIfPresent(String.self, forKey: .classPlanId) ?? ""
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeOptional<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

private func canonicalProfileTime(_ value: String) -> String {
    guard let seconds = ClassIslandDateParser.secondsSinceMidnight(value) else { return value }
    let wholeSeconds = Int(seconds)
    return String(
        format: "%02d:%02d:%02d",
        wholeSeconds / 3_600,
        wholeSeconds % 3_600 / 60,
        wholeSeconds % 60
    )
}

private struct ProfileCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private enum ProfileJSONValue: Codable, Equatable, Sendable {
    case object([String: ProfileJSONValue])
    case array([ProfileJSONValue])
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case decimal(Double)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(UInt64.self) {
            self = .unsignedInteger(value)
        } else if let value = try? container.decode(Double.self) {
            self = .decimal(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ProfileJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([ProfileJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                ProfileJSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value in profile."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .unsignedInteger(let value): try container.encode(value)
        case .decimal(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

private func decodeExtraFields(
    from decoder: Decoder,
    knownKeys: [String]
) throws -> [String: ProfileJSONValue] {
    let knownNames = Set(knownKeys)
    let container = try decoder.container(keyedBy: ProfileCodingKey.self)
    var fields: [String: ProfileJSONValue] = [:]
    for key in container.allKeys where !knownNames.contains(key.stringValue) {
        fields[key.stringValue] = try container.decode(ProfileJSONValue.self, forKey: key)
    }
    return fields
}

private func encodeExtraFields(
    _ fields: [String: ProfileJSONValue],
    to encoder: Encoder,
    knownKeys: [String]
) throws {
    let knownNames = Set(knownKeys)
    var container = encoder.container(keyedBy: ProfileCodingKey.self)
    for (name, value) in fields where !knownNames.contains(name) {
        guard let key = ProfileCodingKey(stringValue: name) else { continue }
        try container.encode(value, forKey: key)
    }
}
