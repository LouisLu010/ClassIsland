import XCTest
@testable import ClassIslandMobile

final class ScheduleNotificationPlannerTests: XCTestCase {
    func testUnavailableActivitySurfacesFallBackToSystemNotifications() {
        let capabilities = ReminderSurfaceCapabilities(
            supportsDynamicIslandHardware: false,
            supportsLiveActivities: false,
            supportsSystemNotifications: true
        )

        let selection = capabilities.normalizedSelection([.dynamicIsland, .liveActivity])

        XCTAssertEqual(selection, [.systemNotification])
    }

    func testDeviceWithoutDynamicIslandKeepsLiveActivityAndAddsNotificationFallback() {
        let capabilities = ReminderSurfaceCapabilities(
            supportsDynamicIslandHardware: false,
            supportsLiveActivities: true,
            supportsSystemNotifications: true
        )

        let selection = capabilities.normalizedSelection([.dynamicIsland, .liveActivity])

        XCTAssertEqual(selection, [.liveActivity, .systemNotification])
    }

    func testManualEmptySelectionDoesNotForceNotificationsBackOn() {
        let capabilities = ReminderSurfaceCapabilities(
            supportsDynamicIslandHardware: false,
            supportsLiveActivities: false,
            supportsSystemNotifications: true
        )

        XCTAssertTrue(capabilities.normalizedSelection([]).isEmpty)
    }

    func testUnknownWindowCapabilityDoesNotDiscardDynamicIslandSelection() {
        let capabilities = ReminderSurfaceCapabilities(
            supportsDynamicIslandHardware: false,
            supportsLiveActivities: true,
            supportsSystemNotifications: true,
            isDynamicIslandHardwareKnown: false
        )

        XCTAssertEqual(capabilities.normalizedSelection([.dynamicIsland]), [.dynamicIsland])
        XCTAssertFalse(capabilities.supports(.dynamicIsland))
    }

    func testLegacyLiveActivitySettingMigratesToReminderSurfaces() throws {
        let enabled = try JSONDecoder().decode(
            MobileSettings.self,
            from: Data(#"{"liveActivitiesEnabled":true}"#.utf8)
        )
        let disabled = try JSONDecoder().decode(
            MobileSettings.self,
            from: Data(#"{"liveActivitiesEnabled":false}"#.utf8)
        )

        XCTAssertEqual(enabled.reminderSurfaces, [.dynamicIsland, .liveActivity])
        XCTAssertTrue(disabled.reminderSurfaces.isEmpty)
    }

    func testSystemNotificationSelectionRoundTrips() throws {
        var settings = MobileSettings()
        settings.reminderSurfaces = [.systemNotification]

        let decoded = try JSONDecoder().decode(
            MobileSettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded.reminderSurfaces, [.systemNotification])
        XCTAssertFalse(decoded.liveActivitiesEnabled)
        XCTAssertTrue(decoded.systemNotificationsEnabled)
    }

    func testPlannerCreatesClassBreakAndAfterSchoolNotifications() throws {
        var settings = MobileSettings()
        settings.reminderSurfaces = [.systemNotification]
        let snapshot = try makeSnapshot(timeOffsetSeconds: 0)

        let plans = ScheduleNotificationPlanner.makePlans(
            snapshots: [snapshot],
            settings: settings,
            weather: nil,
            plugin: nil,
            now: try date("2026-07-06T07:00:00Z")
        )

        XCTAssertEqual(plans.count, 4)
        XCTAssertEqual(plans.map(\.fireDate), [
            try date("2026-07-06T08:00:00Z"),
            try date("2026-07-06T08:45:00Z"),
            try date("2026-07-06T09:00:00Z"),
            try date("2026-07-06T09:45:00Z")
        ])
        XCTAssertEqual(plans.first?.title, "正在上课")
        XCTAssertTrue(plans[1].body.contains("课间操"))
        XCTAssertEqual(plans.last?.title, "今日课程结束")
    }

    func testPlannerAppliesCourseTimeOffsetToDeliveryDate() throws {
        var settings = MobileSettings()
        settings.reminderSurfaces = [.systemNotification]
        settings.timeOffsetSeconds = 120
        let snapshot = try makeSnapshot(timeOffsetSeconds: 120)

        let plans = ScheduleNotificationPlanner.makePlans(
            snapshots: [snapshot],
            settings: settings,
            weather: nil,
            plugin: nil,
            now: try date("2026-07-06T07:00:00Z")
        )

        XCTAssertEqual(plans.first?.fireDate, try date("2026-07-06T07:58:00Z"))
    }

    func testNotificationRegionsRenderCustomTitleAndBody() throws {
        var settings = MobileSettings()
        var layout = LiveActivityLayout.default
        layout.setComponents(
            [LiveActivityComponentConfiguration(kind: .customText, customText: "准备上课")],
            in: .notificationTitle
        )
        layout.setComponents(
            [
                LiveActivityComponentConfiguration(kind: .currentLesson),
                LiveActivityComponentConfiguration(kind: .nextLesson)
            ],
            in: .notificationBody
        )
        settings.liveActivityLayout = layout
        let snapshot = try makeSnapshot(timeOffsetSeconds: 0)
        let eventSnapshot = ScheduleSnapshot(
            date: snapshot.date,
            profileName: snapshot.profileName,
            planName: snapshot.planName,
            phase: .inClass,
            sessions: snapshot.sessions,
            breaks: snapshot.breaks,
            current: snapshot.sessions[0],
            currentBreak: nil,
            next: snapshot.sessions[1],
            timeOffsetSeconds: 0
        )

        let content = ScheduleNotificationTextRenderer.render(
            snapshot: eventSnapshot,
            settings: settings,
            weather: nil,
            plugin: nil,
            eventDate: try date("2026-07-06T08:00:00Z")
        )

        XCTAssertEqual(content.title, "准备上课")
        XCTAssertTrue(content.body.contains("数学 周老师"))
        XCTAssertTrue(content.body.contains("下一节 英语"))
    }

    private func makeSnapshot(timeOffsetSeconds: TimeInterval) throws -> ScheduleSnapshot {
        let first = ScheduleSession(
            id: "first",
            index: 0,
            start: try date("2026-07-06T08:00:00Z"),
            end: try date("2026-07-06T08:45:00Z"),
            subject: "数学",
            initial: "数",
            teacher: "周老师",
            isOutdoor: false
        )
        let second = ScheduleSession(
            id: "second",
            index: 1,
            start: try date("2026-07-06T09:00:00Z"),
            end: try date("2026-07-06T09:45:00Z"),
            subject: "英语",
            initial: "英",
            teacher: "李老师",
            isOutdoor: false
        )
        let classBreak = ScheduleBreak(
            id: "break",
            start: first.end,
            end: second.start,
            name: "课间操"
        )
        return ScheduleSnapshot(
            date: try date("2026-07-06T00:00:00Z"),
            profileName: "高二（3）班",
            planName: "周一",
            phase: .upcoming,
            sessions: [first, second],
            breaks: [classBreak],
            current: nil,
            currentBreak: nil,
            next: first,
            timeOffsetSeconds: timeOffsetSeconds
        )
    }

    private func date(_ value: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw TestError.invalidDate(value)
        }
        return date
    }

    private enum TestError: Error {
        case invalidDate(String)
    }
}
