import ActivityKit
import Foundation

struct ScheduleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let phase: SchedulePhase
        let headline: String
        let compactTitle: String
        let teacher: String
        let timerStart: Date?
        let timerEnd: Date?
        let nextTitle: String
        let nextStart: Date?
        let updatedAt: Date
    }

    let profileName: String
}
