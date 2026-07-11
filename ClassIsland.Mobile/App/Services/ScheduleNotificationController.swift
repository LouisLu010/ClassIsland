import ActivityKit
import Foundation
import UIKit
import UserNotifications

enum ScheduleNotificationIdentifier {
    static let prefix = "classisland.schedule."
}

struct ReminderSurfaceCapabilities: Equatable, Sendable {
    let supportsDynamicIslandHardware: Bool
    let supportsLiveActivities: Bool
    let supportsSystemNotifications: Bool
    let isDynamicIslandHardwareKnown: Bool

    init(
        supportsDynamicIslandHardware: Bool,
        supportsLiveActivities: Bool,
        supportsSystemNotifications: Bool,
        isDynamicIslandHardwareKnown: Bool = true
    ) {
        self.supportsDynamicIslandHardware = supportsDynamicIslandHardware
        self.supportsLiveActivities = supportsLiveActivities
        self.supportsSystemNotifications = supportsSystemNotifications
        self.isDynamicIslandHardwareKnown = isDynamicIslandHardwareKnown
    }

    @MainActor
    static func current() -> ReminderSurfaceCapabilities {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let maximumSafeAreaInset = windows.reduce(CGFloat.zero) { current, window in
            max(
                current,
                max(
                    window.safeAreaInsets.top,
                    max(window.safeAreaInsets.left, window.safeAreaInsets.right)
                )
            )
        }
        return ReminderSurfaceCapabilities(
            supportsDynamicIslandHardware: UIDevice.current.userInterfaceIdiom == .phone
                && maximumSafeAreaInset >= 51,
            supportsLiveActivities: ActivityAuthorizationInfo().areActivitiesEnabled,
            supportsSystemNotifications: true,
            isDynamicIslandHardwareKnown: !windows.isEmpty
        )
    }

    func supports(_ surface: ReminderSurface) -> Bool {
        switch surface {
        case .dynamicIsland:
            supportsDynamicIslandHardware && supportsLiveActivities
        case .liveActivity:
            supportsLiveActivities
        case .systemNotification:
            supportsSystemNotifications
        }
    }

    func normalizedSelection(_ selection: Set<ReminderSurface>) -> Set<ReminderSurface> {
        let retainedSelection = Set(selection.filter { surface in
            supports(surface)
                || (surface == .dynamicIsland
                    && !isDynamicIslandHardwareKnown
                    && supportsLiveActivities)
        })
        let unavailableSelection = selection.subtracting(retainedSelection)
        var result = retainedSelection
        if !unavailableSelection.isEmpty,
           supportsSystemNotifications {
            result.insert(.systemNotification)
        }
        return result
    }
}

struct ScheduleNotificationPlan: Equatable, Sendable {
    let identifier: String
    let fireDate: Date
    let title: String
    let body: String
}

struct ScheduleNotificationSynchronizationResult {
    let authorizationStatus: UNAuthorizationStatus
    let wasApplied: Bool
}

enum ScheduleNotificationPlanner {
    static let maximumScheduledNotifications = 56

    static func makePlans(
        snapshots: [ScheduleSnapshot],
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        now: Date = Date()
    ) -> [ScheduleNotificationPlan] {
        let plans = snapshots.flatMap { snapshot in
            plans(
                for: snapshot,
                settings: settings,
                weather: weather,
                plugin: plugin
            )
        }
        var identifiers = Set<String>()
        return plans
            .filter { $0.fireDate > now.addingTimeInterval(1) }
            .sorted { $0.fireDate < $1.fireDate }
            .filter { identifiers.insert($0.identifier).inserted }
            .prefix(maximumScheduledNotifications)
            .map { $0 }
    }

    private static func plans(
        for snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?
    ) -> [ScheduleNotificationPlan] {
        let sessions = snapshot.sessions.sorted { $0.start < $1.start }
        guard !sessions.isEmpty else { return [] }

        var plans: [ScheduleNotificationPlan] = []
        for (index, session) in sessions.enumerated() {
            let next = sessions.dropFirst(index + 1).first
            if let fireDate = snapshot.systemDate(forCourseDate: session.start) {
                let eventSnapshot = eventSnapshot(
                    basedOn: snapshot,
                    phase: .inClass,
                    current: session,
                    currentBreak: nil,
                    next: next
                )
                plans.append(
                    plan(
                        identifierSuffix: "class-start-\(session.index)",
                        fireDate: fireDate,
                        snapshot: eventSnapshot,
                        settings: settings,
                        weather: weather,
                        plugin: plugin
                    )
                )
            }

            let hasImmediateNextClass = next.map {
                abs($0.start.timeIntervalSince(session.end)) <= 1
            } ?? false
            guard !hasImmediateNextClass,
                  let fireDate = snapshot.systemDate(forCourseDate: session.end) else {
                continue
            }

            let phase: SchedulePhase = next == nil ? .afterSchool : .breakTime
            let currentBreak = next.flatMap { nextSession in
                snapshot.breaks.first {
                    $0.start <= session.end && $0.end >= nextSession.start
                }
            }
            let eventSnapshot = eventSnapshot(
                basedOn: snapshot,
                phase: phase,
                current: nil,
                currentBreak: currentBreak,
                next: next
            )
            plans.append(
                plan(
                    identifierSuffix: next == nil ? "after-school" : "class-end-\(session.index)",
                    fireDate: fireDate,
                    snapshot: eventSnapshot,
                    settings: settings,
                    weather: weather,
                    plugin: plugin
                )
            )
        }
        return plans
    }

    private static func eventSnapshot(
        basedOn snapshot: ScheduleSnapshot,
        phase: SchedulePhase,
        current: ScheduleSession?,
        currentBreak: ScheduleBreak?,
        next: ScheduleSession?
    ) -> ScheduleSnapshot {
        ScheduleSnapshot(
            date: snapshot.date,
            profileName: snapshot.profileName,
            planName: snapshot.planName,
            phase: phase,
            sessions: snapshot.sessions,
            breaks: snapshot.breaks,
            current: current,
            currentBreak: currentBreak,
            next: next,
            timeOffsetSeconds: snapshot.timeOffsetSeconds
        )
    }

    private static func plan(
        identifierSuffix: String,
        fireDate: Date,
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?
    ) -> ScheduleNotificationPlan {
        let content = ScheduleNotificationTextRenderer.render(
            snapshot: snapshot,
            settings: settings,
            weather: weather,
            plugin: plugin,
            eventDate: fireDate
        )
        return ScheduleNotificationPlan(
            identifier: "\(ScheduleNotificationIdentifier.prefix)"
                + "\(Int(fireDate.timeIntervalSince1970)).\(identifierSuffix)",
            fireDate: fireDate,
            title: content.title,
            body: content.body
        )
    }
}

enum ScheduleNotificationTextRenderer {
    static func render(
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        eventDate: Date
    ) -> (title: String, body: String) {
        let title = text(
            for: .notificationTitle,
            snapshot: snapshot,
            settings: settings,
            weather: weather,
            plugin: plugin,
            eventDate: eventDate
        )
        let body = text(
            for: .notificationBody,
            snapshot: snapshot,
            settings: settings,
            weather: weather,
            plugin: plugin,
            eventDate: eventDate
        )
        return (
            clipped(title.isEmpty ? fallbackTitle(snapshot) : title, limit: 80),
            clipped(body.isEmpty ? fallbackBody(snapshot, settings: settings) : body, limit: 180)
        )
    }

    private static func text(
        for region: LiveActivityRegion,
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        eventDate: Date
    ) -> String {
        settings.liveActivityLayout.components(in: region)
            .compactMap {
                value(
                    for: $0,
                    snapshot: snapshot,
                    settings: settings,
                    weather: weather,
                    plugin: plugin,
                    eventDate: eventDate
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static func value(
        for component: LiveActivityComponentConfiguration,
        snapshot: ScheduleSnapshot,
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        eventDate: Date
    ) -> String? {
        switch component.kind {
        case .status:
            snapshot.phase.title
        case .currentLesson:
            currentLessonText(snapshot, settings: settings)
        case .countdown:
            countdownText(snapshot)
        case .progress:
            nil
        case .nextLesson:
            snapshot.next.map { "下一节 \($0.subject) \(timeText($0.start))" }
        case .profileName:
            snapshot.profileName.isEmpty ? "ClassIsland" : snapshot.profileName
        case .weather:
            weather?.value(for: component.weatherMetric)
        case .clock:
            let date = component.clockUsesSystemTime
                ? eventDate
                : snapshot.courseDate(forSystemDate: eventDate)
            return timeText(date, showsSeconds: component.clockShowsSeconds)
        case .date:
            dateText(snapshot.courseDate(forSystemDate: eventDate))
        case .plugin:
            guard let plugin else { return nil }
            return [plugin.title, plugin.value].filter { !$0.isEmpty }.joined(separator: " ")
        case .customText:
            component.customText
        }
    }

    private static func currentLessonText(
        _ snapshot: ScheduleSnapshot,
        settings: MobileSettings
    ) -> String {
        if let current = snapshot.current {
            let teacher = settings.showTeacher
                ? current.teacher.trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            return teacher.isEmpty ? current.subject : "\(current.subject) \(teacher)"
        }
        if let currentBreak = snapshot.currentBreak {
            return currentBreak.name
        }
        return snapshot.phase.title
    }

    private static func countdownText(_ snapshot: ScheduleSnapshot) -> String? {
        let endDate: Date? = switch snapshot.phase {
        case .inClass: snapshot.current?.end
        case .upcoming, .breakTime: snapshot.next?.start ?? snapshot.currentBreak?.end
        case .afterSchool, .noSchedule: nil
        }
        return endDate.map { "至 \(timeText($0))" }
    }

    private static func fallbackTitle(_ snapshot: ScheduleSnapshot) -> String {
        snapshot.phase == .inClass
            ? snapshot.current?.subject ?? snapshot.phase.title
            : snapshot.phase.title
    }

    private static func fallbackBody(
        _ snapshot: ScheduleSnapshot,
        settings: MobileSettings
    ) -> String {
        let current = currentLessonText(snapshot, settings: settings)
        let next = snapshot.next.map { "下一节 \($0.subject) \(timeText($0.start))" }
        return [current, next].compactMap { $0 }.joined(separator: " · ")
    }

    private static func timeText(_ date: Date, showsSeconds: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = showsSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: date)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }
}

private actor ScheduleNotificationSynchronizationGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func unlock() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
final class ScheduleNotificationController {
    static let shared = ScheduleNotificationController()

    private let center: UNUserNotificationCenter
    private let synchronizationGate = ScheduleNotificationSynchronizationGate()
    private var synchronizationGeneration = 0

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func synchronize(
        snapshots: [ScheduleSnapshot],
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        now: Date = Date(),
        requestAuthorizationIfNeeded: Bool
    ) async throws -> ScheduleNotificationSynchronizationResult {
        synchronizationGeneration &+= 1
        let generation = synchronizationGeneration
        await synchronizationGate.lock()
        do {
            let result = try await performSynchronization(
                snapshots: snapshots,
                settings: settings,
                weather: weather,
                plugin: plugin,
                now: now,
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded,
                generation: generation
            )
            await synchronizationGate.unlock()
            return result
        } catch {
            await synchronizationGate.unlock()
            throw error
        }
    }

    private func performSynchronization(
        snapshots: [ScheduleSnapshot],
        settings: MobileSettings,
        weather: WeatherPresentation?,
        plugin: PluginActivityPresentation?,
        now: Date,
        requestAuthorizationIfNeeded: Bool,
        generation: Int
    ) async throws -> ScheduleNotificationSynchronizationResult {
        guard settings.systemNotificationsEnabled else {
            await cancelAll(generation: generation)
            let status = await authorizationStatus()
            return ScheduleNotificationSynchronizationResult(
                authorizationStatus: status,
                wasApplied: generation == synchronizationGeneration
            )
        }

        var status = await authorizationStatus()
        guard generation == synchronizationGeneration else {
            return ScheduleNotificationSynchronizationResult(
                authorizationStatus: status,
                wasApplied: false
            )
        }
        if status == .notDetermined && requestAuthorizationIfNeeded {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            status = await authorizationStatus()
            guard generation == synchronizationGeneration else {
                return ScheduleNotificationSynchronizationResult(
                    authorizationStatus: status,
                    wasApplied: false
                )
            }
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            await cancelAll(generation: generation)
            return ScheduleNotificationSynchronizationResult(
                authorizationStatus: status,
                wasApplied: generation == synchronizationGeneration
            )
        }

        let plans = ScheduleNotificationPlanner.makePlans(
            snapshots: snapshots,
            settings: settings,
            weather: weather,
            plugin: plugin,
            now: now
        )
        let existingRequests = await scheduledRequests()
        let existingIdentifiers = Set(existingRequests.map(\.identifier))
        guard generation == synchronizationGeneration else {
            return ScheduleNotificationSynchronizationResult(
                authorizationStatus: status,
                wasApplied: false
            )
        }
        let desiredIdentifiers = Set(plans.map(\.identifier))
        let staleIdentifiers = existingIdentifiers.subtracting(desiredIdentifiers)
        if !staleIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIdentifiers))
        }
        let calendar = Calendar.current
        do {
            for plan in plans {
                let content = UNMutableNotificationContent()
                content.title = plan.title
                content.body = plan.body
                content.sound = .default
                let dateComponents = calendar.dateComponents(
                    [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                    from: plan.fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                try await center.add(
                    UNNotificationRequest(
                        identifier: plan.identifier,
                        content: content,
                        trigger: trigger
                    )
                )
                guard generation == synchronizationGeneration else {
                    return ScheduleNotificationSynchronizationResult(
                        authorizationStatus: status,
                        wasApplied: false
                    )
                }
            }
        } catch {
            let newlyAddedIdentifiers = desiredIdentifiers.subtracting(existingIdentifiers)
            if !newlyAddedIdentifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: Array(newlyAddedIdentifiers))
            }
            for request in existingRequests {
                try? await center.add(request)
            }
            throw error
        }
        return ScheduleNotificationSynchronizationResult(
            authorizationStatus: status,
            wasApplied: true
        )
    }

    func cancelAll() async {
        synchronizationGeneration &+= 1
        let generation = synchronizationGeneration
        await synchronizationGate.lock()
        await cancelAll(generation: generation)
        await synchronizationGate.unlock()
    }

    private func cancelAll(generation: Int) async {
        let identifiers = await scheduledIdentifiers()
        guard generation == synchronizationGeneration else { return }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
    }

    private func scheduledIdentifiers() async -> Set<String> {
        let requests = await scheduledRequests()
        return Set(requests.map(\.identifier))
    }

    private func scheduledRequests() async -> [UNNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.filter {
            $0.identifier.hasPrefix(ScheduleNotificationIdentifier.prefix)
        }
    }
}
