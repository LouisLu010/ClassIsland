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
        let accentRGBA: UInt32
        let layout: LiveActivityLayout

        private enum CodingKeys: String, CodingKey {
            case phase
            case headline
            case compactTitle
            case teacher
            case timerStart
            case timerEnd
            case nextTitle
            case nextStart
            case updatedAt
            case accentRGBA
            case layout
        }

        init(
            phase: SchedulePhase,
            headline: String,
            compactTitle: String,
            teacher: String,
            timerStart: Date?,
            timerEnd: Date?,
            nextTitle: String,
            nextStart: Date?,
            updatedAt: Date,
            accentRGBA: UInt32,
            layout: LiveActivityLayout
        ) {
            self.phase = phase
            self.headline = headline
            self.compactTitle = compactTitle
            self.teacher = teacher
            self.timerStart = timerStart
            self.timerEnd = timerEnd
            self.nextTitle = nextTitle
            self.nextStart = nextStart
            self.updatedAt = updatedAt
            self.accentRGBA = accentRGBA
            self.layout = layout
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phase = try container.decode(SchedulePhase.self, forKey: .phase)
            headline = try container.decode(String.self, forKey: .headline)
            compactTitle = try container.decode(String.self, forKey: .compactTitle)
            teacher = try container.decodeIfPresent(String.self, forKey: .teacher) ?? ""
            timerStart = try container.decodeIfPresent(Date.self, forKey: .timerStart)
            timerEnd = try container.decodeIfPresent(Date.self, forKey: .timerEnd)
            nextTitle = try container.decodeIfPresent(String.self, forKey: .nextTitle) ?? ""
            nextStart = try container.decodeIfPresent(Date.self, forKey: .nextStart)
            updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
            accentRGBA = try container.decodeIfPresent(UInt32.self, forKey: .accentRGBA) ?? 0x05ABE8FF
            layout = try container.decodeIfPresent(LiveActivityLayout.self, forKey: .layout) ?? .default
        }
    }

    let profileName: String
}
