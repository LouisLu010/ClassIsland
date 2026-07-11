import BackgroundTasks
import Foundation

enum ScheduleRefreshPolicy {
    static let foregroundTransitionLeeway: TimeInterval = 0.1
    static let minimumForegroundDelay: TimeInterval = 0.05
    static let backgroundRetryDelay: TimeInterval = 1
    static let liveActivityStaleLeeway: TimeInterval = 1
    static let notificationRefreshInterval: TimeInterval = 24 * 60 * 60

    static func foregroundRefreshDate(
        for snapshot: ScheduleSnapshot,
        now: Date = Date()
    ) -> Date? {
        guard let boundary = snapshot.nextBoundary else { return nil }
        return max(
            boundary.addingTimeInterval(foregroundTransitionLeeway),
            now.addingTimeInterval(minimumForegroundDelay)
        )
    }

    static func earliestBeginDate(
        for snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        hasActiveActivity: Bool,
        now: Date = Date()
    ) -> Date? {
        guard settings.liveActivitiesEnabled,
              hasActiveActivity,
              let boundary = snapshot.nextBoundary else {
            return nil
        }
        return boundary > now ? boundary : now.addingTimeInterval(backgroundRetryDelay)
    }

    static func notificationRefreshDate(
        settings: MobileSettings,
        now: Date = Date()
    ) -> Date? {
        guard settings.systemNotificationsEnabled else { return nil }
        return now.addingTimeInterval(notificationRefreshInterval)
    }
}

enum ScheduleRefreshScheduler {
    static let taskIdentifier = "cn.classisland.mobile.schedule-refresh"

    @MainActor
    static func submit(earliestBeginDate: Date) throws {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func cancel() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }
}
