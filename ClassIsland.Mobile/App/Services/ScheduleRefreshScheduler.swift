import BackgroundTasks
import Foundation

enum ScheduleRefreshPolicy {
    static let transitionDelay: TimeInterval = 2

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
        return max(
            boundary.addingTimeInterval(transitionDelay),
            now.addingTimeInterval(transitionDelay)
        )
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
