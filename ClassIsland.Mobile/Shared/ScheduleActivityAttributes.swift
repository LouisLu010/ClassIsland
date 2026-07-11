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
        let timeOffsetSeconds: TimeInterval
        let accentRGBA: UInt32
        let layout: LiveActivityLayout
        let weather: WeatherPresentation?
        let plugin: PluginActivityPresentation?

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
            case timeOffsetSeconds
            case accentRGBA
            case layout
            case weather
            case plugin
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
            timeOffsetSeconds: TimeInterval,
            accentRGBA: UInt32,
            layout: LiveActivityLayout,
            weather: WeatherPresentation? = nil,
            plugin: PluginActivityPresentation? = nil
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
            self.timeOffsetSeconds = timeOffsetSeconds
            self.accentRGBA = accentRGBA
            self.layout = layout
            self.weather = weather
            self.plugin = plugin
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
            timeOffsetSeconds = try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .timeOffsetSeconds
            ) ?? 0
            accentRGBA = try container.decodeIfPresent(UInt32.self, forKey: .accentRGBA) ?? 0x05ABE8FF
            layout = try container.decodeIfPresent(LiveActivityLayout.self, forKey: .layout) ?? .default
            weather = try container.decodeIfPresent(WeatherPresentation.self, forKey: .weather)
            plugin = try container.decodeIfPresent(PluginActivityPresentation.self, forKey: .plugin)
        }
    }

    let profileName: String
}
