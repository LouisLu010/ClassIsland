import Foundation

enum ProfileEditingService {
    static let emptyId = "00000000-0000-0000-0000-000000000000"

    @discardableResult
    static func addSubject(to profile: inout ClassIslandProfile) -> String {
        let id = makeId()
        profile.subjects[id] = ClassIslandSubject(name: "新科目", initial: "新")
        return id
    }

    static func updateSubject(
        id: String,
        value: ClassIslandSubject,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(id, in: profile.subjects) else {
            throw ProfileEditingError.subjectNotFound
        }
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileEditingError.emptyName }
        var updated = value
        updated.name = name
        if updated.initial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.initial = String(name.prefix(1))
        }
        profile.subjects[key] = updated
    }

    static func removeSubject(id: String, from profile: inout ClassIslandProfile) throws {
        guard let key = resolvedKey(id, in: profile.subjects) else {
            throw ProfileEditingError.subjectNotFound
        }
        let usage = profile.classPlans.values.reduce(into: 0) { count, plan in
            count += plan.classes.filter { idsEqual($0.subjectId, key) }.count
        }
        guard usage == 0 else { throw ProfileEditingError.subjectInUse(usage) }
        guard profile.subjects.count > 1 else { throw ProfileEditingError.lastSubject }
        profile.subjects.removeValue(forKey: key)
        for layoutKey in Array(profile.timeLayouts.keys) {
            guard var layout = profile.timeLayouts[layoutKey] else { continue }
            for index in layout.layouts.indices where idsEqual(layout.layouts[index].defaultClassId, key) {
                layout.layouts[index].defaultClassId = emptyId
            }
            profile.timeLayouts[layoutKey] = layout
        }
    }

    @discardableResult
    static func addTimeLayout(
        to profile: inout ClassIslandProfile,
        copying sourceId: String? = nil
    ) -> String {
        let id = makeId()
        if let sourceId,
           let sourceKey = resolvedKey(sourceId, in: profile.timeLayouts),
           var source = profile.timeLayouts[sourceKey] {
            source.name += " - 副本"
            source.isOverlay = false
            source.overlaySourceId = nil
            source.layouts = source.layouts.map {
                var point = $0
                point.id = UUID()
                return point
            }
            profile.timeLayouts[id] = source
        } else {
            profile.timeLayouts[id] = ClassIslandTimeLayout(
                layouts: [
                    ClassIslandTimePoint(
                        startTimeValue: "08:00:00",
                        endTimeValue: "08:45:00",
                        timeType: 0
                    )
                ]
            )
        }
        return id
    }

    static func updateTimeLayout(
        id: String,
        value: ClassIslandTimeLayout,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(id, in: profile.timeLayouts),
              let previous = profile.timeLayouts[key] else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileEditingError.emptyName }
        try validateTimePoints(value.layouts)
        var updated = value
        updated.name = name
        profile.timeLayouts[key] = updated
        reconcileClassPlans(using: key, previous: previous, updated: updated, in: &profile)
    }

    static func removeTimeLayout(id: String, from profile: inout ClassIslandProfile) throws {
        guard let key = resolvedKey(id, in: profile.timeLayouts) else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let usage = profile.classPlans.values.filter { idsEqual($0.timeLayoutId, key) }.count
        guard usage == 0 else { throw ProfileEditingError.timeLayoutInUse(usage) }
        guard profile.timeLayouts.count > 1 else { throw ProfileEditingError.lastTimeLayout }
        profile.timeLayouts.removeValue(forKey: key)
    }

    static func addTimePoint(
        _ point: ClassIslandTimePoint,
        to timeLayoutId: String,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(timeLayoutId, in: profile.timeLayouts),
              var layout = profile.timeLayouts[key] else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let previous = layout
        layout.layouts.append(point)
        try validateTimePoints(layout.layouts)
        profile.timeLayouts[key] = layout
        reconcileClassPlans(using: key, previous: previous, updated: layout, in: &profile)
    }

    static func updateTimePoint(
        _ point: ClassIslandTimePoint,
        in timeLayoutId: String,
        profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(timeLayoutId, in: profile.timeLayouts),
              var layout = profile.timeLayouts[key],
              let index = layout.layouts.firstIndex(where: { $0.id == point.id }) else {
            throw ProfileEditingError.timePointNotFound
        }
        let previous = layout
        layout.layouts[index] = point
        try validateTimePoints(layout.layouts)
        profile.timeLayouts[key] = layout
        reconcileClassPlans(using: key, previous: previous, updated: layout, in: &profile)
    }

    static func removeTimePoints(
        at offsets: IndexSet,
        from timeLayoutId: String,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(timeLayoutId, in: profile.timeLayouts),
              var layout = profile.timeLayouts[key] else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let previous = layout
        for index in offsets.sorted(by: >) where layout.layouts.indices.contains(index) {
            layout.layouts.remove(at: index)
        }
        guard layout.layouts.contains(where: { $0.timeType == 0 }) else {
            throw ProfileEditingError.lastClassTimePoint
        }
        profile.timeLayouts[key] = layout
        reconcileClassPlans(using: key, previous: previous, updated: layout, in: &profile)
    }

    static func moveTimePoints(
        from offsets: IndexSet,
        to destination: Int,
        in timeLayoutId: String,
        profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(timeLayoutId, in: profile.timeLayouts),
              var layout = profile.timeLayouts[key] else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let previous = layout
        layout.layouts.move(fromOffsets: offsets, toOffset: destination)
        profile.timeLayouts[key] = layout
        reconcileClassPlans(using: key, previous: previous, updated: layout, in: &profile)
    }

    @discardableResult
    static func addClassPlan(
        to profile: inout ClassIslandProfile,
        copying sourceId: String? = nil
    ) throws -> String {
        let id = makeId()
        if let sourceId,
           let sourceKey = resolvedKey(sourceId, in: profile.classPlans),
           var source = profile.classPlans[sourceKey] {
            source.name += " - 副本"
            source.isOverlay = false
            source.overlaySourceId = nil
            source.overlaySetupTime = nil
            profile.classPlans[id] = source
            return id
        }

        guard let layoutId = sortedEntries(profile.timeLayouts).first?.key,
              let layout = profile.timeLayouts[layoutId] else {
            throw ProfileEditingError.noTimeLayout
        }
        let classes = layout.layouts
            .filter { $0.timeType == 0 }
            .map { defaultClassInfo(for: $0, profile: profile) }
        profile.classPlans[id] = ClassIslandClassPlan(
            timeLayoutId: layoutId,
            timeRule: ClassIslandTimeRule(weekDay: 1, weekCountDiv: 0, weekCountDivTotal: 2),
            classes: classes
        )
        return id
    }

    static func updateClassPlan(
        id: String,
        value: ClassIslandClassPlan,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(id, in: profile.classPlans) else {
            throw ProfileEditingError.classPlanNotFound
        }
        guard resolvedKey(value.timeLayoutId, in: profile.timeLayouts) != nil else {
            throw ProfileEditingError.timeLayoutNotFound
        }
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileEditingError.emptyName }
        var updated = value
        updated.name = name
        normalizeClasses(in: &updated, profile: profile)
        profile.classPlans[key] = updated
    }

    static func removeClassPlan(id: String, from profile: inout ClassIslandProfile) throws {
        guard let key = resolvedKey(id, in: profile.classPlans) else {
            throw ProfileEditingError.classPlanNotFound
        }
        guard profile.classPlans.count > 1 else { throw ProfileEditingError.lastClassPlan }
        profile.classPlans.removeValue(forKey: key)
        profile.orderedSchedules = profile.orderedSchedules.filter { !idsEqual($0.value.classPlanId, key) }
        if profile.tempClassPlanId.map({ idsEqual($0, key) }) == true {
            profile.tempClassPlanId = nil
            profile.tempClassPlanSetupTime = nil
        }
        if profile.overlayClassPlanId.map({ idsEqual($0, key) }) == true {
            profile.overlayClassPlanId = nil
            profile.isOverlayClassPlanEnabled = false
        }
        for planKey in Array(profile.classPlans.keys) {
            guard var plan = profile.classPlans[planKey],
                  plan.overlaySourceId.map({ idsEqual($0, key) }) == true else { continue }
            plan.overlaySourceId = nil
            profile.classPlans[planKey] = plan
        }
    }

    static func setClass(
        _ classInfo: ClassIslandClassInfo,
        at index: Int,
        in classPlanId: String,
        profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(classPlanId, in: profile.classPlans),
              var plan = profile.classPlans[key],
              plan.classes.indices.contains(index) else {
            throw ProfileEditingError.classPlanNotFound
        }
        plan.classes[index] = classInfo
        profile.classPlans[key] = plan
    }

    @discardableResult
    static func addGroup(to profile: inout ClassIslandProfile) -> String {
        let id = makeId()
        profile.classPlanGroups[id] = ClassIslandClassPlanGroup()
        return id
    }

    static func updateGroup(
        id: String,
        value: ClassIslandClassPlanGroup,
        in profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(id, in: profile.classPlanGroups) else {
            throw ProfileEditingError.groupNotFound
        }
        guard !idsEqual(key, ClassIslandClassPlan.defaultGroupId),
              !idsEqual(key, ClassIslandClassPlan.globalGroupId) else {
            throw ProfileEditingError.protectedGroup
        }
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileEditingError.emptyName }
        var updated = value
        updated.name = name
        updated.isGlobal = false
        profile.classPlanGroups[key] = updated
    }

    static func removeGroup(
        id: String,
        deletingPlans: Bool,
        from profile: inout ClassIslandProfile
    ) throws {
        guard let key = resolvedKey(id, in: profile.classPlanGroups) else {
            throw ProfileEditingError.groupNotFound
        }
        guard !idsEqual(key, ClassIslandClassPlan.defaultGroupId),
              !idsEqual(key, ClassIslandClassPlan.globalGroupId) else {
            throw ProfileEditingError.protectedGroup
        }
        let affected = profile.classPlans.keys.filter {
            profile.classPlans[$0].map { idsEqual($0.associatedGroup, key) } == true
        }
        if deletingPlans {
            for planId in affected {
                if profile.classPlans.count > 1 {
                    try removeClassPlan(id: planId, from: &profile)
                } else if var plan = profile.classPlans[planId] {
                    plan.associatedGroup = ClassIslandClassPlan.defaultGroupId
                    profile.classPlans[planId] = plan
                }
            }
        } else {
            for planId in affected {
                guard var plan = profile.classPlans[planId] else { continue }
                plan.associatedGroup = ClassIslandClassPlan.defaultGroupId
                profile.classPlans[planId] = plan
            }
        }
        profile.classPlanGroups.removeValue(forKey: key)
        if idsEqual(profile.selectedClassPlanGroupId, key) {
            profile.selectedClassPlanGroupId = ClassIslandClassPlan.defaultGroupId
        }
        if profile.tempClassPlanGroupId.map({ idsEqual($0, key) }) == true {
            profile.tempClassPlanGroupId = nil
            profile.isTempClassPlanGroupEnabled = false
        }
    }

    static func setOrderedSchedule(
        on date: Date,
        classPlanId: String,
        in profile: inout ClassIslandProfile,
        calendar: Calendar = .current
    ) throws {
        guard resolvedKey(classPlanId, in: profile.classPlans) != nil else {
            throw ProfileEditingError.classPlanNotFound
        }
        profile.orderedSchedules[dateKey(date, calendar: calendar)] = ClassIslandOrderedSchedule(
            classPlanId: classPlanId
        )
    }

    static func removeOrderedSchedules(at offsets: IndexSet, from profile: inout ClassIslandProfile) {
        let keys = sortedOrderedSchedules(profile).map(\.key)
        for index in offsets where keys.indices.contains(index) {
            profile.orderedSchedules.removeValue(forKey: keys[index])
        }
    }

    static func sortedEntries<Value>(_ dictionary: [String: Value]) -> [(key: String, value: Value)] {
        dictionary.sorted {
            let left = displayName($0.value)
            let right = displayName($1.value)
            if left == right { return $0.key < $1.key }
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    static func sortedOrderedSchedules(
        _ profile: ClassIslandProfile
    ) -> [(key: String, value: ClassIslandOrderedSchedule)] {
        profile.orderedSchedules.sorted {
            let left = ClassIslandDateParser.date(from: $0.key) ?? .distantFuture
            let right = ClassIslandDateParser.date(from: $1.key) ?? .distantFuture
            if left == right { return $0.key < $1.key }
            return left < right
        }
    }

    static func validationIssues(for profile: ClassIslandProfile) -> [ProfileValidationIssue] {
        var issues: [ProfileValidationIssue] = []
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.error("档案名称为空", "请填写档案名称。"))
        }
        if profile.subjects.isEmpty {
            issues.append(.error("没有科目", "至少需要保留一个科目。"))
        }
        if profile.timeLayouts.isEmpty {
            issues.append(.error("没有时间表", "至少需要保留一个时间表。"))
        }
        if profile.classPlans.isEmpty {
            issues.append(.error("没有课表", "至少需要保留一个课表。"))
        }

        for (id, layout) in profile.timeLayouts {
            if !layout.layouts.contains(where: { $0.timeType == 0 }) {
                issues.append(.error("时间表没有课程", "\(layout.name) 至少需要一个上课时间点。"))
            }
            if (try? validateTimePoints(layout.layouts)) == nil {
                issues.append(.error("时间点无效", "\(layout.name) 中存在无法识别或结束早于开始的时间。"))
            }
            if id.isEmpty {
                issues.append(.error("时间表 ID 无效", layout.name))
            }
        }

        for (_, plan) in profile.classPlans {
            guard let layoutKey = resolvedKey(plan.timeLayoutId, in: profile.timeLayouts),
                  let layout = profile.timeLayouts[layoutKey] else {
                issues.append(.error("课表缺少时间表", "\(plan.name) 引用的时间表不存在。"))
                continue
            }
            let expectedCount = layout.layouts.filter { $0.timeType == 0 }.count
            if plan.classes.count != expectedCount {
                issues.append(.error("课程数量不匹配", "\(plan.name) 应包含 \(expectedCount) 节课程。"))
            }
            for info in plan.classes where !idsEqual(info.subjectId, emptyId) {
                if resolvedKey(info.subjectId, in: profile.subjects) == nil {
                    issues.append(.error("课表缺少科目", "\(plan.name) 引用了不存在的科目。"))
                    break
                }
            }
            if resolvedKey(plan.associatedGroup, in: profile.classPlanGroups) == nil {
                issues.append(.warning("课表群不存在", "\(plan.name) 将回退到默认课表群。"))
            }
        }
        return issues
    }

    static func validateForSaving(_ profile: ClassIslandProfile) throws {
        if let first = validationIssues(for: profile).first(where: { $0.severity == .error }) {
            throw ProfileEditingError.validationFailed(first.message)
        }
    }

    private static func validateTimePoints(_ points: [ClassIslandTimePoint]) throws {
        for point in points {
            guard (0...3).contains(point.timeType),
                  let start = ClassIslandDateParser.secondsSinceMidnight(point.startTimeValue),
                  let end = ClassIslandDateParser.secondsSinceMidnight(point.endTimeValue) else {
                throw ProfileEditingError.invalidTimePoint
            }
            if point.timeType == 0 || point.timeType == 1 {
                guard end > start else { throw ProfileEditingError.invalidTimeRange }
            }
        }
    }

    private static func reconcileClassPlans(
        using timeLayoutId: String,
        previous: ClassIslandTimeLayout,
        updated: ClassIslandTimeLayout,
        in profile: inout ClassIslandProfile
    ) {
        let previousClassPoints = previous.layouts.filter { $0.timeType == 0 }
        let updatedClassPoints = updated.layouts.filter { $0.timeType == 0 }
        for planKey in Array(profile.classPlans.keys) {
            guard var plan = profile.classPlans[planKey], idsEqual(plan.timeLayoutId, timeLayoutId) else { continue }
            var classesByPoint: [UUID: ClassIslandClassInfo] = [:]
            for (index, point) in previousClassPoints.enumerated() where plan.classes.indices.contains(index) {
                classesByPoint[point.id] = plan.classes[index]
            }
            plan.classes = updatedClassPoints.map {
                classesByPoint[$0.id] ?? defaultClassInfo(for: $0, profile: profile)
            }
            profile.classPlans[planKey] = plan
        }
    }

    private static func normalizeClasses(
        in plan: inout ClassIslandClassPlan,
        profile: ClassIslandProfile
    ) {
        guard let layoutKey = resolvedKey(plan.timeLayoutId, in: profile.timeLayouts),
              let layout = profile.timeLayouts[layoutKey] else { return }
        let points = layout.layouts.filter { $0.timeType == 0 }
        if plan.classes.count > points.count {
            plan.classes.removeLast(plan.classes.count - points.count)
        } else if plan.classes.count < points.count {
            for point in points.dropFirst(plan.classes.count) {
                plan.classes.append(defaultClassInfo(for: point, profile: profile))
            }
        }
    }

    private static func defaultClassInfo(
        for point: ClassIslandTimePoint,
        profile: ClassIslandProfile
    ) -> ClassIslandClassInfo {
        if !idsEqual(point.defaultClassId, emptyId),
           let key = resolvedKey(point.defaultClassId, in: profile.subjects) {
            return ClassIslandClassInfo(subjectId: key)
        }
        return ClassIslandClassInfo(subjectId: sortedEntries(profile.subjects).first?.key ?? emptyId)
    }

    private static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02dT00:00:00",
            values.year ?? 1,
            values.month ?? 1,
            values.day ?? 1
        )
    }

    private static func displayName<Value>(_ value: Value) -> String {
        switch value {
        case let subject as ClassIslandSubject: subject.name
        case let layout as ClassIslandTimeLayout: layout.name
        case let plan as ClassIslandClassPlan: plan.name
        case let group as ClassIslandClassPlanGroup: group.name
        default: ""
        }
    }

    private static func resolvedKey<Value>(_ id: String, in dictionary: [String: Value]) -> String? {
        dictionary[id] != nil ? id : dictionary.keys.first { idsEqual($0, id) }
    }

    private static func idsEqual(_ left: String, _ right: String) -> Bool {
        left.caseInsensitiveCompare(right) == .orderedSame
    }

    private static func makeId() -> String {
        UUID().uuidString.uppercased()
    }
}

struct ProfileValidationIssue: Identifiable, Equatable, Sendable {
    enum Severity: Equatable, Sendable {
        case warning
        case error
    }

    let id: UUID
    let severity: Severity
    let title: String
    let message: String

    static func warning(_ title: String, _ message: String) -> ProfileValidationIssue {
        ProfileValidationIssue(id: UUID(), severity: .warning, title: title, message: message)
    }

    static func error(_ title: String, _ message: String) -> ProfileValidationIssue {
        ProfileValidationIssue(id: UUID(), severity: .error, title: title, message: message)
    }

    static func == (lhs: ProfileValidationIssue, rhs: ProfileValidationIssue) -> Bool {
        lhs.severity == rhs.severity && lhs.title == rhs.title && lhs.message == rhs.message
    }
}

enum ProfileEditingError: LocalizedError, Equatable {
    case subjectNotFound
    case subjectInUse(Int)
    case lastSubject
    case timeLayoutNotFound
    case timeLayoutInUse(Int)
    case lastTimeLayout
    case timePointNotFound
    case lastClassTimePoint
    case invalidTimePoint
    case invalidTimeRange
    case classPlanNotFound
    case lastClassPlan
    case noTimeLayout
    case groupNotFound
    case protectedGroup
    case emptyName
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .subjectNotFound: "找不到该科目。"
        case .subjectInUse(let count): "该科目仍被 \(count) 节课程使用，请先替换这些课程。"
        case .lastSubject: "档案至少需要保留一个科目。"
        case .timeLayoutNotFound: "找不到该时间表。"
        case .timeLayoutInUse(let count): "该时间表仍被 \(count) 个课表使用，请先更换对应课表的时间表。"
        case .lastTimeLayout: "档案至少需要保留一个时间表。"
        case .timePointNotFound: "找不到该时间点。"
        case .lastClassTimePoint: "时间表至少需要保留一个上课时间点。"
        case .invalidTimePoint: "时间点类型或时间格式无效。"
        case .invalidTimeRange: "结束时间必须晚于开始时间。"
        case .classPlanNotFound: "找不到该课表。"
        case .lastClassPlan: "档案至少需要保留一个课表。"
        case .noTimeLayout: "请先创建时间表。"
        case .groupNotFound: "找不到该课表群。"
        case .protectedGroup: "默认课表群和全局课表群不能修改或删除。"
        case .emptyName: "名称不能为空。"
        case .validationFailed(let message): message
        }
    }
}

enum ProfileDocumentCodec {
    private static let authoritativeCollections = [
        "TimeLayouts",
        "ClassPlans",
        "Subjects",
        "ClassPlanGroups",
        "OrderedSchedules"
    ]

    static func encode(
        _ profile: ClassIslandProfile,
        preserving originalData: Data?
    ) throws -> Data {
        try ProfileEditingService.validateForSaving(profile)
        let encoder = JSONEncoder()
        let editedData = try encoder.encode(profile)
        guard let edited = try JSONSerialization.jsonObject(with: editedData) as? [String: Any] else {
            throw ProfileEditingError.validationFailed("无法生成档案 JSON。")
        }

        let merged: [String: Any]
        if let originalData,
           let object = try? JSONSerialization.jsonObject(with: originalData),
           let original = object as? [String: Any] {
            merged = mergeRoot(original: original, edited: edited)
        } else {
            merged = edited
        }
        return try JSONSerialization.data(
            withJSONObject: merged,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func mergeRoot(
        original: [String: Any],
        edited: [String: Any]
    ) -> [String: Any] {
        var result = original
        for (key, value) in edited {
            if authoritativeCollections.contains(key),
               let editedCollection = value as? [String: Any] {
                let originalCollection = original[key] as? [String: Any] ?? [String: Any]()
                result[key] = mergeCollection(original: originalCollection, edited: editedCollection)
            } else {
                result[key] = deepMerge(original: original[key], edited: value)
            }
        }
        return result
    }

    private static func mergeCollection(
        original: [String: Any],
        edited: [String: Any]
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in edited {
            let originalKey = original.keys.first {
                $0.caseInsensitiveCompare(key) == .orderedSame
            }
            result[key] = deepMerge(original: originalKey.flatMap { original[$0] }, edited: value)
        }
        return result
    }

    private static func deepMerge(original: Any?, edited: Any) -> Any {
        if let editedObject = edited as? [String: Any] {
            let originalObject = original as? [String: Any] ?? [String: Any]()
            var result = originalObject
            for (key, value) in editedObject {
                result[key] = deepMerge(original: originalObject[key], edited: value)
            }
            return result
        }
        if let editedArray = edited as? [Any] {
            // 有序条目的未知字段已由模型携带，数组必须以编辑后的顺序为准。
            return editedArray
        }
        return edited
    }
}

private extension Array {
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted().compactMap { indices.contains($0) ? self[$0] : nil }
        for index in offsets.sorted(by: >) where indices.contains(index) {
            remove(at: index)
        }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertionIndex = Swift.min(Swift.max(destination - removedBeforeDestination, 0), count)
        insert(contentsOf: moving, at: insertionIndex)
    }
}
