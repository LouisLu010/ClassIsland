import Foundation

struct ClassIslandProfile: Decodable, Sendable {
    let name: String
    let timeLayouts: [String: ClassIslandTimeLayout]
    let classPlans: [String: ClassIslandClassPlan]
    let subjects: [String: ClassIslandSubject]
    let orderedSchedules: [String: ClassIslandOrderedSchedule]
    let isOverlayClassPlanEnabled: Bool
    let tempClassPlanId: String?
    let tempClassPlanSetupTime: String?
    let selectedClassPlanGroupId: String
    let tempClassPlanGroupId: String?
    let tempClassPlanGroupExpireTime: String?
    let isTempClassPlanGroupEnabled: Bool
    let tempClassPlanGroupType: Int

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case timeLayouts = "TimeLayouts"
        case classPlans = "ClassPlans"
        case subjects = "Subjects"
        case orderedSchedules = "OrderedSchedules"
        case isOverlayClassPlanEnabled = "IsOverlayClassPlanEnabled"
        case tempClassPlanId = "TempClassPlanId"
        case tempClassPlanSetupTime = "TempClassPlanSetupTime"
        case selectedClassPlanGroupId = "SelectedClassPlanGroupId"
        case tempClassPlanGroupId = "TempClassPlanGroupId"
        case tempClassPlanGroupExpireTime = "TempClassPlanGroupExpireTime"
        case isTempClassPlanGroupEnabled = "IsTempClassPlanGroupEnabled"
        case tempClassPlanGroupType = "TempClassPlanGroupType"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        timeLayouts = try container.decodeIfPresent([String: ClassIslandTimeLayout].self, forKey: .timeLayouts) ?? [:]
        classPlans = try container.decodeIfPresent([String: ClassIslandClassPlan].self, forKey: .classPlans) ?? [:]
        subjects = try container.decodeIfPresent([String: ClassIslandSubject].self, forKey: .subjects) ?? [:]
        orderedSchedules = try container.decodeIfPresent([String: ClassIslandOrderedSchedule].self, forKey: .orderedSchedules) ?? [:]
        isOverlayClassPlanEnabled = try container.decodeIfPresent(Bool.self, forKey: .isOverlayClassPlanEnabled) ?? false
        tempClassPlanId = try container.decodeIfPresent(String.self, forKey: .tempClassPlanId)
        tempClassPlanSetupTime = try container.decodeIfPresent(String.self, forKey: .tempClassPlanSetupTime)
        selectedClassPlanGroupId = try container.decodeIfPresent(String.self, forKey: .selectedClassPlanGroupId)
            ?? ClassIslandClassPlan.defaultGroupId
        tempClassPlanGroupId = try container.decodeIfPresent(String.self, forKey: .tempClassPlanGroupId)
        tempClassPlanGroupExpireTime = try container.decodeIfPresent(String.self, forKey: .tempClassPlanGroupExpireTime)
        isTempClassPlanGroupEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTempClassPlanGroupEnabled) ?? false
        tempClassPlanGroupType = try container.decodeIfPresent(Int.self, forKey: .tempClassPlanGroupType) ?? 1
    }
}

struct ClassIslandTimeLayout: Decodable, Sendable {
    let name: String
    let layouts: [ClassIslandTimePoint]

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case layouts = "Layouts"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        layouts = try container.decodeIfPresent([ClassIslandTimePoint].self, forKey: .layouts) ?? []
    }
}

struct ClassIslandTimePoint: Decodable, Sendable {
    let startTimeValue: String
    let endTimeValue: String
    let timeType: Int
    let breakName: String

    enum CodingKeys: String, CodingKey {
        case startTime = "StartTime"
        case endTime = "EndTime"
        case startSecond = "StartSecond"
        case endSecond = "EndSecond"
        case timeType = "TimeType"
        case breakName = "BreakName"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentStart = try container.decodeIfPresent(String.self, forKey: .startTime)
        let currentEnd = try container.decodeIfPresent(String.self, forKey: .endTime)
        let legacyStart = try container.decodeIfPresent(String.self, forKey: .startSecond)
        let legacyEnd = try container.decodeIfPresent(String.self, forKey: .endSecond)
        startTimeValue = [currentStart, legacyStart]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? ""
        endTimeValue = [currentEnd, legacyEnd]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty }) ?? ""
        timeType = try container.decodeIfPresent(Int.self, forKey: .timeType) ?? 0
        breakName = try container.decodeIfPresent(String.self, forKey: .breakName) ?? "课间休息"
    }
}

struct ClassIslandClassPlan: Decodable, Sendable {
    static let defaultGroupId = "ACAF4EF0-E261-4262-B941-34EA93CB4369"
    static let globalGroupId = "00000000-0000-0000-0000-000000000000"

    let timeLayoutId: String
    let timeRule: ClassIslandTimeRule
    let classes: [ClassIslandClassInfo]
    let name: String
    let isOverlay: Bool
    let isEnabled: Bool
    let associatedGroup: String

    enum CodingKeys: String, CodingKey {
        case timeLayoutId = "TimeLayoutId"
        case timeRule = "TimeRule"
        case classes = "Classes"
        case name = "Name"
        case isOverlay = "IsOverlay"
        case isEnabled = "IsEnabled"
        case associatedGroup = "AssociatedGroup"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeLayoutId = try container.decodeIfPresent(String.self, forKey: .timeLayoutId) ?? ""
        timeRule = try container.decodeIfPresent(ClassIslandTimeRule.self, forKey: .timeRule) ?? .everyWeek
        classes = try container.decodeIfPresent([ClassIslandClassInfo].self, forKey: .classes) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        isOverlay = try container.decodeIfPresent(Bool.self, forKey: .isOverlay) ?? false
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        associatedGroup = try container.decodeIfPresent(String.self, forKey: .associatedGroup) ?? Self.defaultGroupId
    }
}

struct ClassIslandTimeRule: Decodable, Sendable {
    static let everyWeek = ClassIslandTimeRule(weekDay: 0, weekCountDiv: 0, weekCountDivTotal: 2)

    let weekDay: Int
    let weekCountDiv: Int
    let weekCountDivTotal: Int

    enum CodingKeys: String, CodingKey {
        case weekDay = "WeekDay"
        case weekCountDiv = "WeekCountDiv"
        case weekCountDivTotal = "WeekCountDivTotal"
    }

    init(weekDay: Int, weekCountDiv: Int, weekCountDivTotal: Int) {
        self.weekDay = weekDay
        self.weekCountDiv = weekCountDiv
        self.weekCountDivTotal = weekCountDivTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekDay = try container.decodeIfPresent(Int.self, forKey: .weekDay) ?? 0
        weekCountDiv = try container.decodeIfPresent(Int.self, forKey: .weekCountDiv) ?? 0
        weekCountDivTotal = max(2, try container.decodeIfPresent(Int.self, forKey: .weekCountDivTotal) ?? 2)
    }
}

struct ClassIslandClassInfo: Decodable, Sendable {
    let subjectId: String
    let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case subjectId = "SubjectId"
        case isEnabled = "IsEnabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjectId = try container.decodeIfPresent(String.self, forKey: .subjectId) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

struct ClassIslandSubject: Decodable, Sendable {
    let name: String
    let initial: String
    let teacherName: String
    let isOutdoor: Bool

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case initial = "Initial"
        case teacherName = "TeacherName"
        case isOutdoor = "IsOutDoor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名课程"
        initial = try container.decodeIfPresent(String.self, forKey: .initial) ?? ""
        teacherName = try container.decodeIfPresent(String.self, forKey: .teacherName) ?? ""
        isOutdoor = try container.decodeIfPresent(Bool.self, forKey: .isOutdoor) ?? false
    }
}

struct ClassIslandOrderedSchedule: Decodable, Sendable {
    let classPlanId: String

    enum CodingKeys: String, CodingKey {
        case classPlanId = "ClassPlanId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classPlanId = try container.decodeIfPresent(String.self, forKey: .classPlanId) ?? ""
    }
}
