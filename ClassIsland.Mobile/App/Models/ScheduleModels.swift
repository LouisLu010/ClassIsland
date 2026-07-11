import Foundation

struct ScheduleSession: Identifiable, Equatable, Sendable {
    let id: String
    let index: Int
    let start: Date
    let end: Date
    let subject: String
    let initial: String
    let teacher: String
    let isOutdoor: Bool
}

struct ScheduleBreak: Identifiable, Equatable, Sendable {
    let id: String
    let start: Date
    let end: Date
    let name: String
}

struct ScheduleSnapshot: Equatable, Sendable {
    let date: Date
    let profileName: String
    let planName: String
    let phase: SchedulePhase
    let sessions: [ScheduleSession]
    let breaks: [ScheduleBreak]
    let current: ScheduleSession?
    let currentBreak: ScheduleBreak?
    let next: ScheduleSession?
    let timeOffsetSeconds: TimeInterval

    var nextBoundary: Date? {
        let courseBoundary: Date? = switch phase {
        case .inClass: current?.end
        case .upcoming, .breakTime: next?.start ?? currentBreak?.end
        case .noSchedule, .afterSchool: nil
        }
        return systemDate(forCourseDate: courseBoundary)
    }

    func courseDate(forSystemDate date: Date) -> Date {
        date.addingTimeInterval(timeOffsetSeconds)
    }

    func systemDate(forCourseDate date: Date?) -> Date? {
        date?.addingTimeInterval(-timeOffsetSeconds)
    }
}
