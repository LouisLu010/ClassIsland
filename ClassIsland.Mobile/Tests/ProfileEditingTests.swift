import XCTest
@testable import ClassIslandMobile

final class ProfileEditingTests: XCTestCase {
    func testNewProfileRoundTripsAndPassesValidation() throws {
        let profile = ClassIslandProfile.newProfile(name: "测试档案")

        XCTAssertTrue(ProfileEditingService.validationIssues(for: profile).isEmpty)

        let data = try ProfileDocumentCodec.encode(profile, preserving: nil)
        let decoded = try JSONDecoder().decode(ClassIslandProfile.self, from: data)

        XCTAssertEqual(decoded, profile)
        XCTAssertEqual(decoded.classPlans.count, 5)
        XCTAssertEqual(decoded.timeLayouts.values.first?.layouts.filter { $0.timeType == 0 }.count, 4)
        XCTAssertNotNil(decoded.key(in: decoded.classPlanGroups, matching: ClassIslandClassPlan.defaultGroupId))
        XCTAssertNotNil(decoded.key(in: decoded.classPlanGroups, matching: ClassIslandClassPlan.globalGroupId))
    }

    func testLegacyDateTimePointsEncodeAsDesktopTimeSpans() throws {
        let source = Data(
            """
            {
              "StartSecond": "2026-01-01T08:05:06",
              "EndSecond": "2026-01-01T08:50:07",
              "TimeType": 0
            }
            """.utf8
        )
        let point = try JSONDecoder().decode(ClassIslandTimePoint.self, from: source)
        let encoded = try JSONEncoder().encode(point)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(object["StartTime"] as? String, "08:05:06")
        XCTAssertEqual(object["EndTime"] as? String, "08:50:07")
    }

    func testProfileEncodingPreservesUnknownDesktopAndPluginFields() throws {
        let profile = ClassIslandProfile.newProfile(name: "保留字段")
        let initialData = try ProfileDocumentCodec.encode(profile, preserving: nil)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: initialData) as? [String: Any]
        )
        object["PluginRoot"] = ["Enabled": true, "Version": 7]

        let subjectId = try XCTUnwrap(profile.subjects.keys.first)
        var subjects = try XCTUnwrap(object["Subjects"] as? [String: Any])
        var subject = try XCTUnwrap(subjects[subjectId] as? [String: Any])
        subject["AttachedSettings"] = ["Plugin.Subject.Color": "#123456"]
        subjects[subjectId] = subject
        object["Subjects"] = subjects
        let sourceData = try JSONSerialization.data(withJSONObject: object)

        var edited = try JSONDecoder().decode(ClassIslandProfile.self, from: sourceData)
        var editedSubject = try XCTUnwrap(edited.subjects[subjectId])
        editedSubject.teacherName = "新教师"
        try ProfileEditingService.updateSubject(id: subjectId, value: editedSubject, in: &edited)

        let mergedData = try ProfileDocumentCodec.encode(edited, preserving: sourceData)
        let merged = try XCTUnwrap(
            JSONSerialization.jsonObject(with: mergedData) as? [String: Any]
        )
        let mergedRoot = try XCTUnwrap(merged["PluginRoot"] as? [String: Any])
        let mergedSubjects = try XCTUnwrap(merged["Subjects"] as? [String: Any])
        let mergedSubject = try XCTUnwrap(mergedSubjects[subjectId] as? [String: Any])
        let attached = try XCTUnwrap(mergedSubject["AttachedSettings"] as? [String: Any])

        XCTAssertEqual(mergedRoot["Version"] as? Int, 7)
        XCTAssertEqual(attached["Plugin.Subject.Color"] as? String, "#123456")
        XCTAssertEqual(mergedSubject["TeacherName"] as? String, "新教师")
    }

    func testReorderingKeepsUnknownFieldsAttachedToTimePointsAndClasses() throws {
        let profile = ClassIslandProfile.newProfile(name: "重排保留字段")
        let layoutId = try XCTUnwrap(profile.timeLayouts.keys.first)
        let planId = try XCTUnwrap(profile.classPlans.keys.first)
        let initialData = try ProfileDocumentCodec.encode(profile, preserving: nil)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: initialData) as? [String: Any])

        var layouts = try XCTUnwrap(object["TimeLayouts"] as? [String: Any])
        var layout = try XCTUnwrap(layouts[layoutId] as? [String: Any])
        var points = try XCTUnwrap(layout["Layouts"] as? [[String: Any]])
        points[0]["ActionSet"] = ["Marker": "first", "FirstOnly": true]
        points[2]["ActionSet"] = ["Marker": "second", "SecondOnly": true]
        layout["Layouts"] = points
        layouts[layoutId] = layout
        object["TimeLayouts"] = layouts

        var plans = try XCTUnwrap(object["ClassPlans"] as? [String: Any])
        var plan = try XCTUnwrap(plans[planId] as? [String: Any])
        var classes = try XCTUnwrap(plan["Classes"] as? [[String: Any]])
        classes[0]["AttachedObjects"] = ["Marker": "first", "FirstOnly": true]
        classes[1]["AttachedObjects"] = ["Marker": "second", "SecondOnly": true]
        plan["Classes"] = classes
        plans[planId] = plan
        object["ClassPlans"] = plans

        let sourceData = try JSONSerialization.data(withJSONObject: object)
        var edited = try JSONDecoder().decode(ClassIslandProfile.self, from: sourceData)
        var editedLayout = try XCTUnwrap(edited.timeLayouts[layoutId])
        editedLayout.layouts.swapAt(0, 2)
        try ProfileEditingService.updateTimeLayout(id: layoutId, value: editedLayout, in: &edited)

        let savedData = try ProfileDocumentCodec.encode(edited, preserving: sourceData)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: savedData) as? [String: Any])
        let savedLayouts = try XCTUnwrap(saved["TimeLayouts"] as? [String: Any])
        let savedLayout = try XCTUnwrap(savedLayouts[layoutId] as? [String: Any])
        let savedPoints = try XCTUnwrap(savedLayout["Layouts"] as? [[String: Any]])
        let firstAction = try XCTUnwrap(savedPoints[0]["ActionSet"] as? [String: Any])
        let secondAction = try XCTUnwrap(savedPoints[2]["ActionSet"] as? [String: Any])

        XCTAssertEqual(firstAction["Marker"] as? String, "second")
        XCTAssertNil(firstAction["FirstOnly"])
        XCTAssertEqual(secondAction["Marker"] as? String, "first")
        XCTAssertNil(secondAction["SecondOnly"])

        let savedPlans = try XCTUnwrap(saved["ClassPlans"] as? [String: Any])
        let savedPlan = try XCTUnwrap(savedPlans[planId] as? [String: Any])
        let savedClasses = try XCTUnwrap(savedPlan["Classes"] as? [[String: Any]])
        let firstAttached = try XCTUnwrap(savedClasses[0]["AttachedObjects"] as? [String: Any])
        let secondAttached = try XCTUnwrap(savedClasses[1]["AttachedObjects"] as? [String: Any])

        XCTAssertEqual(firstAttached["Marker"] as? String, "second")
        XCTAssertNil(firstAttached["FirstOnly"])
        XCTAssertEqual(secondAttached["Marker"] as? String, "first")
        XCTAssertNil(secondAttached["SecondOnly"])
    }

    func testChangingTimeLayoutKeepsEveryClassPlanAligned() throws {
        var profile = ClassIslandProfile.newProfile()
        let layoutId = try XCTUnwrap(profile.timeLayouts.keys.first)
        var layout = try XCTUnwrap(profile.timeLayouts[layoutId])
        layout.layouts.append(
            ClassIslandTimePoint(
                startTimeValue: "13:30:00",
                endTimeValue: "14:15:00",
                timeType: 0
            )
        )

        try ProfileEditingService.updateTimeLayout(id: layoutId, value: layout, in: &profile)

        let matchingPlans = profile.classPlans.values.filter {
            $0.timeLayoutId.caseInsensitiveCompare(layoutId) == .orderedSame
        }
        XCTAssertFalse(matchingPlans.isEmpty)
        XCTAssertTrue(matchingPlans.allSatisfy { $0.classes.count == 5 })
        XCTAssertTrue(ProfileEditingService.validationIssues(for: profile).isEmpty)
    }

    func testReferencedSubjectCannotBeDeleted() throws {
        var profile = ClassIslandProfile.newProfile()
        let subjectId = try XCTUnwrap(profile.subjects.keys.first)

        XCTAssertThrowsError(
            try ProfileEditingService.removeSubject(id: subjectId, from: &profile)
        ) { error in
            guard case ProfileEditingError.subjectInUse(let count) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(count, 0)
        }
    }

    func testEditedCourseIsImmediatelyVisibleToScheduleEngine() throws {
        var profile = ClassIslandProfile.newProfile(name: "编辑测试")
        let subjectId = ProfileEditingService.addSubject(to: &profile)
        try ProfileEditingService.updateSubject(
            id: subjectId,
            value: ClassIslandSubject(name: "移动端课程", initial: "移", teacherName: "测试教师"),
            in: &profile
        )
        let mondayPlanId = try XCTUnwrap(
            profile.classPlans.first { $0.value.timeRule.weekDay == 1 }?.key
        )
        var mondayPlan = try XCTUnwrap(profile.classPlans[mondayPlanId])
        mondayPlan.classes[0].subjectId = subjectId
        try ProfileEditingService.updateClassPlan(id: mondayPlanId, value: mondayPlan, in: &profile)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-06T08:20:00Z"))
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.current?.subject, "移动端课程")
        XCTAssertEqual(snapshot.current?.teacher, "测试教师")
    }

    func testRemovingGroupCanDisbandPlansIntoDefaultGroup() throws {
        var profile = ClassIslandProfile.newProfile()
        let groupId = ProfileEditingService.addGroup(to: &profile)
        let planId = try XCTUnwrap(profile.classPlans.keys.first)
        var plan = try XCTUnwrap(profile.classPlans[planId])
        plan.associatedGroup = groupId
        profile.classPlans[planId] = plan

        try ProfileEditingService.removeGroup(
            id: groupId,
            deletingPlans: false,
            from: &profile
        )

        XCTAssertNil(profile.key(in: profile.classPlanGroups, matching: groupId))
        XCTAssertEqual(profile.classPlans[planId]?.associatedGroup, ClassIslandClassPlan.defaultGroupId)
    }

    func testRequiredGroupsKeepDesktopSystemSemantics() throws {
        var profile = ClassIslandProfile.newProfile()
        profile.selectedClassPlanGroupId = "missing-group"
        profile.classPlanGroups[ClassIslandClassPlan.defaultGroupId]?.isGlobal = true
        profile.classPlanGroups[ClassIslandClassPlan.globalGroupId]?.isGlobal = false

        profile.ensureRequiredGroups()

        XCTAssertEqual(profile.selectedClassPlanGroupId, ClassIslandClassPlan.defaultGroupId)
        XCTAssertFalse(
            try XCTUnwrap(profile.classPlanGroups[ClassIslandClassPlan.defaultGroupId]).isGlobal
        )
        XCTAssertTrue(
            try XCTUnwrap(profile.classPlanGroups[ClassIslandClassPlan.globalGroupId]).isGlobal
        )
        XCTAssertThrowsError(
            try ProfileEditingService.updateGroup(
                id: ClassIslandClassPlan.defaultGroupId,
                value: ClassIslandClassPlanGroup(name: "已修改"),
                in: &profile
            )
        ) { error in
            XCTAssertEqual(error as? ProfileEditingError, .protectedGroup)
        }
    }
}
