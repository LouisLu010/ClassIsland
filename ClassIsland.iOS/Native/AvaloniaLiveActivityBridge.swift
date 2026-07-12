import ActivityKit
import Darwin
import Foundation
import UIKit

private enum BridgeResult: Int32 {
    case accepted = 0
    case unsupportedSystem = 1
    case disabledBySystem = 2
    case invalidPayload = 3
    case failed = 4
}

private struct BridgeTimelineEntry: Decodable {
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

    var activityEntry: ScheduleActivityTimelineEntry {
        ScheduleActivityTimelineEntry(
            startsAt: startsAt,
            endsAt: endsAt,
            phase: phase,
            headline: headline,
            compactTitle: compactTitle,
            teacher: teacher,
            timerStart: timerStart,
            timerEnd: timerEnd,
            nextTitle: nextTitle,
            nextStart: nextStart
        )
    }
}

private struct BridgePluginPresentation: Decodable {
    let title: String
    let value: String
    let systemImage: String

    var activityPresentation: PluginActivityPresentation {
        PluginActivityPresentation(
            title: title,
            value: value,
            systemImage: systemImage
        )
    }
}

private struct BridgePayload: Decodable {
    let profileName: String
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
    let accentRgba: UInt32
    let staleAt: Date?
    let layout: LiveActivityLayout?
    let weather: WeatherPresentation?
    let plugin: BridgePluginPresentation?
    let timeline: [BridgeTimelineEntry]

    private enum CodingKeys: String, CodingKey {
        case profileName
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
        case accentRgba
        case staleAt
        case layout
        case weather
        case plugin
        case timeline
    }

    func makeContentState() -> ScheduleActivityAttributes.ContentState {
        var state = ScheduleActivityAttributes.ContentState(
            phase: phase,
            headline: String(headline.prefix(48)),
            compactTitle: String(compactTitle.prefix(2)),
            teacher: String(teacher.prefix(48)),
            timerStart: timerStart,
            timerEnd: timerEnd,
            nextTitle: String(nextTitle.prefix(48)),
            nextStart: nextStart,
            updatedAt: updatedAt,
            timeOffsetSeconds: timeOffsetSeconds,
            accentRGBA: accentRgba,
            layout: (layout ?? .default).activityKitPayloadLayout,
            weather: weather,
            plugin: plugin?.activityPresentation,
            timeline: timeline.map(\.activityEntry)
        )

        let encoder = JSONEncoder()
        while state.timeline.count > 1,
              (try? encoder.encode(state).count) ?? 0 > 3_600 {
            var reduced = state.timeline
            reduced.remove(at: max(reduced.count - 2, 0))
            state = state.replacingTimeline(reduced)
        }
        return state
    }
}

@available(iOS 16.1, *)
@MainActor
private final class AvaloniaLiveActivityController {
    static let shared = AvaloniaLiveActivityController()

    private init() {}

    func synchronize(_ payload: BridgePayload) async throws {
        let profileName = String(
            (payload.profileName.isEmpty ? "ClassIsland" : payload.profileName).prefix(48)
        )
        let state = payload.makeContentState()
        let content = ActivityContent(state: state, staleDate: payload.staleAt)

        if let activity = Activity<ScheduleActivityAttributes>.activities.first {
            if activity.attributes.profileName == profileName {
                await activity.update(content)
                return
            }
            await endAll()
        }

        _ = try Activity.request(
            attributes: ScheduleActivityAttributes(profileName: profileName),
            content: content,
            pushType: nil
        )
    }

    func endAll() async {
        let finalState = ScheduleActivityAttributes.ContentState(
            phase: .afterSchool,
            headline: "今日课程结束",
            compactTitle: "完",
            teacher: "",
            timerStart: nil,
            timerEnd: nil,
            nextTitle: "",
            nextStart: nil,
            updatedAt: Date(),
            timeOffsetSeconds: 0,
            accentRGBA: 0x05ABE8FF,
            layout: .default.activityKitPayloadLayout
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        for activity in Activity<ScheduleActivityAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }
}

@_cdecl("ClassIslandLiveActivityIsEnabled")
func classIslandLiveActivityIsEnabled() -> Int32 {
    guard #available(iOS 16.1, *) else {
        return 0
    }
    return ActivityAuthorizationInfo().areActivitiesEnabled ? 1 : 0
}

@_cdecl("ClassIslandDynamicIslandIsAvailable")
func classIslandDynamicIslandIsAvailable() -> Int32 {
    guard UIDevice.current.userInterfaceIdiom == .phone else {
        return 0
    }

    let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        ?? hardwareModelIdentifier()
    guard identifier.hasPrefix("iPhone") else {
        return 0
    }

    let model = identifier.dropFirst("iPhone".count).split(separator: ",").first
    guard let model, let majorVersion = Int(model) else {
        return 0
    }
    return majorVersion >= 15 ? 1 : 0
}

@_cdecl("ClassIslandLiveActivityUpdate")
func classIslandLiveActivityUpdate(_ payloadJson: UnsafePointer<CChar>?) -> Int32 {
    guard #available(iOS 16.1, *) else {
        return BridgeResult.unsupportedSystem.rawValue
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        return BridgeResult.disabledBySystem.rawValue
    }
    guard let payloadJson else {
        return BridgeResult.invalidPayload.rawValue
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    guard let data = String(cString: payloadJson).data(using: .utf8),
          let payload = try? decoder.decode(BridgePayload.self, from: data) else {
        return BridgeResult.invalidPayload.rawValue
    }

    Task { @MainActor in
        do {
            try await AvaloniaLiveActivityController.shared.synchronize(payload)
        } catch {
            NSLog("ClassIsland ActivityKit update failed: %@", error.localizedDescription)
        }
    }
    return BridgeResult.accepted.rawValue
}

@_cdecl("ClassIslandLiveActivityEnd")
func classIslandLiveActivityEnd() -> Int32 {
    guard #available(iOS 16.1, *) else {
        return BridgeResult.unsupportedSystem.rawValue
    }

    Task { @MainActor in
        await AvaloniaLiveActivityController.shared.endAll()
    }
    return BridgeResult.accepted.rawValue
}

private func hardwareModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
}
