import Foundation

enum SchedulePhase: String, Codable, Hashable, Sendable {
    case noSchedule
    case upcoming
    case inClass
    case breakTime
    case afterSchool

    var title: String {
        switch self {
        case .noSchedule: "今天没有课程"
        case .upcoming: "课程尚未开始"
        case .inClass: "正在上课"
        case .breakTime: "课间休息"
        case .afterSchool: "今日课程结束"
        }
    }
}
