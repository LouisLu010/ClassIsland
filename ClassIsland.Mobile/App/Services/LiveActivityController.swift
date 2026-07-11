import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private init() {}

    func synchronize(
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        now: Date = Date(),
        allowStarting: Bool = true
    ) async throws -> Bool {
        guard settings.liveActivitiesEnabled else {
            await endAll()
            return true
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabledBySystem
        }
        if snapshot.phase == .noSchedule || (snapshot.phase == .afterSchool && !settings.keepAfterSchoolActivity) {
            await endAll()
            return true
        }

        let profileName = activityText(
            snapshot.profileName.isEmpty ? "ClassIsland" : snapshot.profileName
        )
        let state = contentState(
            snapshot: snapshot,
            settings: settings,
            weather: weather,
            plugin: plugin,
            now: now
        )
        let staleDate = snapshot.nextBoundary?.addingTimeInterval(
            ScheduleRefreshPolicy.liveActivityStaleLeeway
        )
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let activity = Activity<ScheduleActivityAttributes>.activities.first {
            if activity.attributes.profileName == profileName {
                await activity.update(content)
                return true
            }
            await endAll()
        }

        guard allowStarting else { return false }

        _ = try Activity.request(
            attributes: ScheduleActivityAttributes(profileName: profileName),
            content: content,
            pushType: nil
        )
        return true
    }

    func endAll() async {
        let finalState = ScheduleActivityAttributes.ContentState(
            phase: .afterSchool,
            headline: "今日课程结束",
            compactTitle: "完成",
            teacher: "",
            timerStart: nil,
            timerEnd: nil,
            nextTitle: "",
            nextStart: nil,
            updatedAt: Date(),
            timeOffsetSeconds: 0,
            accentRGBA: 0x05ABE8FF,
            layout: LiveActivityLayout.default.activityKitPayloadLayout,
            weather: nil,
            plugin: nil
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        for activity in Activity<ScheduleActivityAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }

    private func contentState(
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        now: Date
    ) -> ScheduleActivityAttributes.ContentState {
        let focus = snapshot.current ?? snapshot.next
        let teacherSource = snapshot.phase == .breakTime ? nil : focus
        let headline: String
        let timerStart: Date?
        let timerEnd: Date?

        switch snapshot.phase {
        case .inClass:
            headline = snapshot.current?.subject ?? snapshot.phase.title
            timerStart = snapshot.systemDate(forCourseDate: snapshot.current?.start)
            timerEnd = snapshot.systemDate(forCourseDate: snapshot.current?.end)
        case .upcoming:
            headline = snapshot.next?.subject ?? snapshot.phase.title
            timerStart = now
            timerEnd = snapshot.systemDate(forCourseDate: snapshot.next?.start)
        case .breakTime:
            headline = snapshot.currentBreak?.name ?? snapshot.phase.title
            timerStart = snapshot.systemDate(forCourseDate: snapshot.currentBreak?.start) ?? now
            timerEnd = snapshot.systemDate(
                forCourseDate: snapshot.next?.start ?? snapshot.currentBreak?.end
            )
        case .afterSchool:
            headline = snapshot.phase.title
            timerStart = nil
            timerEnd = nil
        case .noSchedule:
            headline = snapshot.phase.title
            timerStart = nil
            timerEnd = nil
        }

        let initial = focus?.initial.trimmingCharacters(in: .whitespacesAndNewlines)
        let compactTitle: String
        switch snapshot.phase {
        case .breakTime:
            compactTitle = "休"
        case .afterSchool:
            compactTitle = "完"
        case .noSchedule:
            compactTitle = "无"
        case .upcoming, .inClass:
            if settings.useInitialInCompactIsland, let initial, !initial.isEmpty {
                compactTitle = String(initial.prefix(2))
            } else {
                compactTitle = String(headline.prefix(2))
            }
        }

        return ScheduleActivityAttributes.ContentState(
            phase: snapshot.phase,
            headline: activityText(headline),
            compactTitle: compactTitle,
            teacher: settings.showTeacher ? activityText(teacherSource?.teacher ?? "") : "",
            timerStart: timerStart,
            timerEnd: timerEnd,
            nextTitle: activityText(
                snapshot.phase == .inClass || snapshot.phase == .breakTime
                    ? snapshot.next?.subject ?? ""
                    : ""
            ),
            nextStart: snapshot.phase == .inClass || snapshot.phase == .breakTime
                ? snapshot.next?.start
                : nil,
            updatedAt: now,
            timeOffsetSeconds: snapshot.timeOffsetSeconds,
            accentRGBA: settings.activityAccentRGBA,
            layout: settings.liveActivityLayout.activityKitPayloadLayout,
            weather: settings.weatherEnabled ? weather : nil,
            plugin: plugin
        )
    }

    private func activityText(_ value: String) -> String {
        String(value.prefix(48))
    }
}

enum LiveActivityError: LocalizedError {
    case disabledBySystem

    var errorDescription: String? {
        switch self {
        case .disabledBySystem:
            "系统已关闭实时活动，请在“设置 → ClassIsland”中启用。"
        }
    }
}
