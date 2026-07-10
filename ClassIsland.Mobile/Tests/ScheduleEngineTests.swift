import XCTest
@testable import ClassIslandMobile

final class ScheduleEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testDecodesWindowsProfileAndBuildsCurrentAndNextSessions() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        var settings = MobileSettings()
        settings.singleWeekStartTime = try date("2026-07-05T00:00:00Z")

        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: settings,
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.phase, .inClass)
        XCTAssertEqual(snapshot.current?.subject, "数学")
        XCTAssertEqual(snapshot.current?.teacher, "周老师")
        XCTAssertEqual(snapshot.next?.subject, "英语")
        XCTAssertEqual(snapshot.sessions.count, 2)
    }

    func testDecodesLegacyDateTimeFields() throws {
        let profile = try decodeProfile(
            firstWeekDivision: 0,
            secondWeekDivision: nil,
            timeSchema: .legacy
        )
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.sessions.count, 2)
        XCTAssertEqual(snapshot.current?.subject, "数学")
    }

    func testBreakTimeUsesFollowingClassAsNextSession() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: try date("2026-07-06T08:50:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.phase, .breakTime)
        XCTAssertNil(snapshot.current)
        XCTAssertEqual(snapshot.currentBreak?.name, "课间休息")
        XCTAssertEqual(snapshot.next?.subject, "英语")
        XCTAssertEqual(snapshot.nextBoundary, try date("2026-07-06T08:55:00Z"))
    }

    func testBackgroundRefreshSchedulesImmediatelyAfterTheNextBoundary() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        let now = try date("2026-07-06T08:20:00Z")
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: now,
            calendar: calendar
        )

        let target = ScheduleRefreshPolicy.earliestBeginDate(
            for: snapshot,
            settings: MobileSettings(),
            hasActiveActivity: true,
            now: now
        )

        XCTAssertEqual(target, try date("2026-07-06T08:45:02Z"))
    }

    func testBackgroundRefreshRequiresAnEnabledActiveActivity() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        let now = try date("2026-07-06T08:20:00Z")
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: now,
            calendar: calendar
        )
        var disabledSettings = MobileSettings()
        disabledSettings.liveActivitiesEnabled = false

        XCTAssertNil(
            ScheduleRefreshPolicy.earliestBeginDate(
                for: snapshot,
                settings: MobileSettings(),
                hasActiveActivity: false,
                now: now
            )
        )
        XCTAssertNil(
            ScheduleRefreshPolicy.earliestBeginDate(
                for: snapshot,
                settings: disabledSettings,
                hasActiveActivity: true,
                now: now
            )
        )
    }

    func testBackgroundRefreshNeverRequestsADateInThePast() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )
        let delayedNow = try date("2026-07-06T09:00:00Z")

        let target = ScheduleRefreshPolicy.earliestBeginDate(
            for: snapshot,
            settings: MobileSettings(),
            hasActiveActivity: true,
            now: delayedNow
        )

        XCTAssertEqual(target, try date("2026-07-06T09:00:02Z"))
    }

    func testBackgroundRefreshStopsAfterScheduleEnds() throws {
        let profile = try decodeProfile(firstWeekDivision: 0, secondWeekDivision: nil)
        let now = try date("2026-07-06T10:00:00Z")
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.phase, .afterSchool)
        XCTAssertNil(
            ScheduleRefreshPolicy.earliestBeginDate(
                for: snapshot,
                settings: MobileSettings(),
                hasActiveActivity: true,
                now: now
            )
        )
    }

    func testMultiWeekRotationSelectsMatchingPlan() throws {
        let profile = try decodeProfile(firstWeekDivision: 1, secondWeekDivision: 2)
        var settings = MobileSettings()
        settings.singleWeekStartTime = try date("2026-07-05T00:00:00Z")
        settings.maxRotationCycle = 4

        let firstWeek = ScheduleEngine().snapshot(
            profile: profile,
            settings: settings,
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )
        let secondWeek = ScheduleEngine().snapshot(
            profile: profile,
            settings: settings,
            at: try date("2026-07-13T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(firstWeek.planName, "第一周")
        XCTAssertEqual(secondWeek.planName, "第二周")
    }

    func testOrderedScheduleTakesPriorityOverRotationRule() throws {
        let profile = try decodeProfile(
            firstWeekDivision: 1,
            secondWeekDivision: 2,
            orderedDate: "2026-07-06T00:00:00"
        )
        var settings = MobileSettings()
        settings.singleWeekStartTime = try date("2026-07-05T00:00:00Z")

        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: settings,
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.planName, "第二周")
        XCTAssertEqual(snapshot.current?.subject, "英语")
    }

    func testTemporaryPlanTakesPriorityOverRotationRule() throws {
        let profile = try decodeProfile(
            firstWeekDivision: 1,
            secondWeekDivision: 2,
            temporaryPlanEnabled: true
        )
        var settings = MobileSettings()
        settings.singleWeekStartTime = try date("2026-07-05T00:00:00Z")

        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: settings,
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.planName, "第二周")
        XCTAssertEqual(snapshot.current?.subject, "英语")
    }

    func testTemporaryGroupOverridesSelectedGroup() throws {
        let profile = try decodeProfile(
            firstWeekDivision: 0,
            secondWeekDivision: 0,
            temporaryGroupType: 0
        )
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.planName, "第二周")
        XCTAssertEqual(snapshot.current?.subject, "英语")
    }

    func testMissingSubjectKeepsTheScheduledTimeSlot() throws {
        let profile = try decodeProfile(
            firstWeekDivision: 0,
            secondWeekDivision: nil,
            missingFirstSubject: true
        )
        let snapshot = ScheduleEngine().snapshot(
            profile: profile,
            settings: MobileSettings(),
            at: try date("2026-07-06T08:20:00Z"),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.phase, .inClass)
        XCTAssertEqual(snapshot.current?.subject, "未命名课程")
        XCTAssertEqual(snapshot.sessions.count, 2)
    }

    func testParsesDotNetTimestampWithSevenFractionalDigits() throws {
        let parsed = ClassIslandDateParser.date(from: "2026-07-06T09:15:25.8014348+08:00")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(ClassIslandDateParser.secondsSinceMidnight("2026-07-06T09:15:25.8014348+08:00"), 33_325)
    }

    func testDateParserPreservesWrittenDayAndRejectsInvalidTimes() throws {
        let parsed = try XCTUnwrap(
            ClassIslandDateParser.date(from: "2026-07-06T00:00:00+14:00", calendar: calendar)
        )
        let components = calendar.dateComponents([.year, .month, .day], from: parsed)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 6)
        XCTAssertNil(ClassIslandDateParser.secondsSinceMidnight("24:00:00"))
        XCTAssertNil(ClassIslandDateParser.secondsSinceMidnight("08:60:00"))
    }

    func testDecodesRelevantWindowsSettings() throws {
        let json = """
        {
          "SelectedProfile": "Default.json",
          "SingleWeekStartTime": "2026-07-05T00:00:00+08:00",
          "MultiWeekRotationOffset": [-1, -1, 0, 1, 0],
          "MultiWeekRotationMaxCycle": 4,
          "Theme": 1,
          "ColorSource": 3,
          "PrimaryColor": "#00AEEFFF",
          "SelectedPlatte": "#123456FF",
          "ShowCurrentLessonOnlyOnClass": true
        }
        """
        let settings = try JSONDecoder().decode(ClassIslandWindowsSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.selectedProfile, "Default.json")
        XCTAssertEqual(settings.multiWeekRotationOffset, [-1, -1, 0, 1, 0])
        XCTAssertEqual(settings.multiWeekRotationMaxCycle, 4)
        XCTAssertEqual(settings.theme, 1)
        XCTAssertEqual(settings.colorSource, 3)
        XCTAssertEqual(settings.primaryColor, "#00AEEFFF")
        XCTAssertEqual(settings.selectedPalette, "#123456FF")
        XCTAssertEqual(settings.showCurrentLessonOnlyOnClass, true)
    }

    func testDecodesLegacyWindowsAccentColor() throws {
        let json = """
        {
          "PrimaryColor": { "A": 128, "R": 1, "G": 2, "B": 3 }
        }
        """
        let settings = try JSONDecoder().decode(ClassIslandWindowsSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.primaryColor, "#01020380")
    }

    func testMobileSettingsUseDefaultsAndClampInvalidPersistedValues() throws {
        let json = """
        {
          "showTeacher": false,
          "rotationOffsets": [-1, -1, -4, 20],
          "maxRotationCycle": 99
        }
        """
        let settings = try JSONDecoder().decode(MobileSettings.self, from: Data(json.utf8))

        XCTAssertFalse(settings.showTeacher)
        XCTAssertTrue(settings.liveActivitiesEnabled)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertEqual(settings.activityAccentRGBA, 0x05ABE8FF)
        XCTAssertEqual(settings.maxRotationCycle, 12)
        XCTAssertEqual(settings.rotationOffset(for: 2), 0)
        XCTAssertEqual(settings.rotationOffset(for: 3), 2)

        let roundTripped = try JSONDecoder().decode(
            MobileSettings.self,
            from: JSONEncoder().encode(settings)
        )
        XCTAssertEqual(roundTripped, settings)

        var importedColor = settings
        importedColor.importedAccentHex = "#12345680"
        XCTAssertEqual(importedColor.activityAccentRGBA, 0x12345680)
    }

    private func date(_ value: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw TestError.invalidDate(value)
        }
        return date
    }

    private func decodeProfile(
        firstWeekDivision: Int,
        secondWeekDivision: Int?,
        orderedDate: String? = nil,
        timeSchema: TimeSchema = .current,
        temporaryPlanEnabled: Bool = false,
        temporaryGroupType: Int? = nil,
        missingFirstSubject: Bool = false
    ) throws -> ClassIslandProfile {
        let timePoints = switch timeSchema {
        case .current:
            """
            { "StartSecond": "", "EndSecond": "", "StartTime": "08:00:00", "EndTime": "08:45:00", "TimeType": 0 },
            { "StartSecond": "", "EndSecond": "", "StartTime": "08:45:00", "EndTime": "08:55:00", "TimeType": 1 },
            { "StartSecond": "", "EndSecond": "", "StartTime": "08:55:00", "EndTime": "09:40:00", "TimeType": 0 }
            """
        case .legacy:
            """
            { "StartSecond": "2026-01-01T08:00:00", "EndSecond": "2026-01-01T08:45:00", "TimeType": 0 },
            { "StartSecond": "2026-01-01T08:45:00", "EndSecond": "2026-01-01T08:55:00", "TimeType": 1 },
            { "StartSecond": "2026-01-01T08:55:00", "EndSecond": "2026-01-01T09:40:00", "TimeType": 0 }
            """
        }
        let firstSubjectId = missingFirstSubject
            ? "00000000-0000-0000-0000-000000000199"
            : "00000000-0000-0000-0000-000000000101"
        let secondGroupId = temporaryGroupType == nil
            ? "ACAF4EF0-E261-4262-B941-34EA93CB4369"
            : "40000000-0000-0000-0000-000000000001"
        let secondPlan = secondWeekDivision.map {
            """
            ,"00000000-0000-0000-0000-000000000012": {
              "TimeLayoutId": "00000000-0000-0000-0000-000000000001",
              "TimeRule": { "WeekDay": 1, "WeekCountDiv": \($0), "WeekCountDivTotal": 2 },
              "Classes": [
                { "SubjectId": "00000000-0000-0000-0000-000000000102" },
                { "SubjectId": "00000000-0000-0000-0000-000000000101" }
              ],
              "Name": "第二周",
              "IsEnabled": true,
              "AssociatedGroup": "\(secondGroupId)"
            }
            """
        } ?? ""
        let orderedSchedules = orderedDate.map {
            "\"\($0)\": { \"ClassPlanId\": \"00000000-0000-0000-0000-000000000012\" }"
        } ?? ""
        let temporaryPlan = temporaryPlanEnabled
            ? """
            ,"TempClassPlanId": "00000000-0000-0000-0000-000000000012",
            "TempClassPlanSetupTime": "2026-07-06T00:00:00"
            """
            : ""
        let temporaryGroup = temporaryGroupType.map {
            """
            ,"TempClassPlanGroupId": "40000000-0000-0000-0000-000000000001",
            "TempClassPlanGroupExpireTime": "2026-07-06T00:00:00",
            "IsTempClassPlanGroupEnabled": true,
            "TempClassPlanGroupType": \($0)
            """
        } ?? ""

        let json = """
        {
          "Name": "测试档案",
          "TimeLayouts": {
            "00000000-0000-0000-0000-000000000001": {
              "Name": "上午",
              "Layouts": [
                \(timePoints)
              ]
            }
          },
          "ClassPlans": {
            "00000000-0000-0000-0000-000000000011": {
              "TimeLayoutId": "00000000-0000-0000-0000-000000000001",
              "TimeRule": { "WeekDay": 1, "WeekCountDiv": \(firstWeekDivision), "WeekCountDivTotal": 2 },
              "Classes": [
                { "SubjectId": "\(firstSubjectId)" },
                { "SubjectId": "00000000-0000-0000-0000-000000000102" }
              ],
              "Name": "第一周",
              "IsEnabled": true,
              "AssociatedGroup": "ACAF4EF0-E261-4262-B941-34EA93CB4369"
            }
            \(secondPlan)
          },
          "Subjects": {
            "00000000-0000-0000-0000-000000000101": {
              "Name": "数学", "Initial": "数", "TeacherName": "周老师", "IsOutDoor": false
            },
            "00000000-0000-0000-0000-000000000102": {
              "Name": "英语", "Initial": "英", "TeacherName": "Taylor", "IsOutDoor": false
            }
          },
          "SelectedClassPlanGroupId": "ACAF4EF0-E261-4262-B941-34EA93CB4369",
          "OrderedSchedules": { \(orderedSchedules) }
          \(temporaryPlan)
          \(temporaryGroup)
        }
        """

        return try JSONDecoder().decode(ClassIslandProfile.self, from: Data(json.utf8))
    }
}

private enum TimeSchema {
    case current
    case legacy
}

private enum TestError: Error {
    case invalidDate(String)
}
