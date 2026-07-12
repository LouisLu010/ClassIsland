import ActivityKit
import Foundation

struct ScheduleActivityTimelineEntry: Codable, Hashable, Sendable {
    let startsAt: Date
    let endsAt: Date?
    let phase: SchedulePhase
    let headline: String
    let compactTitle: String
    let teacher: String
    let timerStart: Date?
    let timerEnd: Date?
    let nextTitle: String
    let nextStart: Date?

    private enum CodingKeys: String, CodingKey {
        case startsAt = "s"
        case endsAt = "e"
        case phase = "p"
        case headline = "h"
        case compactTitle = "c"
        case teacher = "t"
        case timerStart = "ts"
        case timerEnd = "te"
        case nextTitle = "n"
        case nextStart = "ns"
    }
}

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
        let timeline: [ScheduleActivityTimelineEntry]

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
            case timeline = "tl"
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
            plugin: PluginActivityPresentation? = nil,
            timeline: [ScheduleActivityTimelineEntry] = []
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
            self.timeline = timeline
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
            timeline = try container.decodeIfPresent(
                [ScheduleActivityTimelineEntry].self,
                forKey: .timeline
            ) ?? []
        }

        func resolved(at date: Date) -> ContentState {
            guard let entry = timeline.last(where: { $0.startsAt <= date }) else {
                return self
            }

            return ContentState(
                phase: entry.phase,
                headline: entry.headline,
                compactTitle: entry.compactTitle,
                teacher: entry.teacher,
                timerStart: entry.timerStart,
                timerEnd: entry.timerEnd,
                nextTitle: entry.nextTitle,
                nextStart: entry.nextStart,
                updatedAt: updatedAt,
                timeOffsetSeconds: timeOffsetSeconds,
                accentRGBA: accentRGBA,
                layout: layout,
                weather: weather,
                plugin: plugin,
                timeline: timeline
            )
        }

        func replacingTimeline(_ value: [ScheduleActivityTimelineEntry]) -> ContentState {
            ContentState(
                phase: phase,
                headline: headline,
                compactTitle: compactTitle,
                teacher: teacher,
                timerStart: timerStart,
                timerEnd: timerEnd,
                nextTitle: nextTitle,
                nextStart: nextStart,
                updatedAt: updatedAt,
                timeOffsetSeconds: timeOffsetSeconds,
                accentRGBA: accentRGBA,
                layout: layout,
                weather: weather,
                plugin: plugin,
                timeline: value
            )
        }
    }

    let profileName: String
}
