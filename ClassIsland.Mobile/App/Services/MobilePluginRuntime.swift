import Foundation

struct MobilePluginRuntime: Sendable {
    func renderComponents(
        plugins: [InstalledMobilePlugin],
        settings: [String: [String: MobilePluginValue]],
        context: MobilePluginRuntimeContext
    ) -> [RenderedMobilePluginComponent] {
        plugins.flatMap { plugin in
            let values = settings[plugin.id] ?? [:]
            return plugin.definition.components.compactMap { component in
                guard component.placement == .schedule,
                      conditionMatches(
                          component.when,
                          plugin: plugin,
                          settings: values,
                          context: context
                      ) else {
                    return nil
                }

                let minimum = component.minimum ?? 0
                let maximum = component.maximum ?? 1
                let resolvedValue = resolve(
                    component.value,
                    plugin: plugin,
                    settings: values,
                    context: context
                )
                let parsedValue = Double(resolvedValue)
                let numericValue = parsedValue.flatMap { $0.isFinite ? $0 : nil } ?? minimum
                let progress = maximum > minimum
                    ? min(max((numericValue - minimum) / (maximum - minimum), 0), 1)
                    : 0
                let items = component.items.map { item in
                    RenderedMobilePluginItem(
                        id: "\(plugin.id).\(component.id).\(item.id)",
                        label: clipped(
                            resolve(item.label, plugin: plugin, settings: values, context: context),
                            limit: 80
                        ),
                        value: clipped(
                            resolve(item.value, plugin: plugin, settings: values, context: context),
                            limit: 160
                        ),
                        systemImage: item.systemImage
                    )
                }

                return RenderedMobilePluginComponent(
                    id: "\(plugin.id).\(component.id)",
                    pluginID: plugin.id,
                    pluginName: plugin.manifest.name,
                    kind: component.kind,
                    title: clipped(
                        resolve(component.title, plugin: plugin, settings: values, context: context),
                        limit: 80
                    ),
                    subtitle: clipped(
                        resolve(component.subtitle, plugin: plugin, settings: values, context: context),
                        limit: 240
                    ),
                    value: clipped(resolvedValue, limit: 160),
                    body: clipped(
                        resolve(component.body, plugin: plugin, settings: values, context: context),
                        limit: 512
                    ),
                    systemImage: component.systemImage,
                    tint: component.tint,
                    progress: progress,
                    items: items,
                    action: component.action
                )
            }
        }
    }

    func activityPresentation(
        plugins: [InstalledMobilePlugin],
        settings: [String: [String: MobilePluginValue]],
        context: MobilePluginRuntimeContext
    ) -> PluginActivityPresentation? {
        for plugin in plugins where plugin.state.grantedCapabilities.contains(.liveActivityRender) {
            guard let definition = plugin.definition.liveActivity else { continue }
            let values = settings[plugin.id] ?? [:]
            let title = resolve(definition.title, plugin: plugin, settings: values, context: context)
            let value = resolve(definition.value, plugin: plugin, settings: values, context: context)
            guard !title.isEmpty || !value.isEmpty else { continue }
            return PluginActivityPresentation(
                title: title,
                value: value,
                systemImage: definition.systemImage
            )
        }
        return nil
    }

    func conditionMatches(
        _ condition: MobilePluginCondition?,
        plugin: InstalledMobilePlugin,
        settings: [String: MobilePluginValue],
        context: MobilePluginRuntimeContext
    ) -> Bool {
        guard let condition else { return true }
        let value = tokenValue(
            condition.source,
            plugin: plugin,
            settings: settings,
            context: context
        )
        if let expected = condition.equals, value != expected {
            return false
        }
        if let excluded = condition.notEquals, value == excluded {
            return false
        }
        if let isEmpty = condition.isEmpty, value.isEmpty != isEmpty {
            return false
        }
        return true
    }

    func resolve(
        _ template: String,
        plugin: InstalledMobilePlugin,
        settings: [String: MobilePluginValue],
        context: MobilePluginRuntimeContext
    ) -> String {
        guard template.contains("{{") else { return template }
        guard let expression = try? NSRegularExpression(
            pattern: #"\{\{\s*([A-Za-z0-9._-]+)\s*\}\}"#
        ) else {
            return template
        }
        let fullRange = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = expression.matches(in: template, range: fullRange)
        var result = template
        for match in matches.reversed() {
            guard let tokenRange = Range(match.range(at: 1), in: template),
                  let replacementRange = Range(match.range(at: 0), in: result) else {
                continue
            }
            let token = String(template[tokenRange])
            let replacement = tokenValue(
                token,
                plugin: plugin,
                settings: settings,
                context: context
            )
            result.replaceSubrange(replacementRange, with: replacement)
        }
        return result
    }

    private func tokenValue(
        _ token: String,
        plugin: InstalledMobilePlugin,
        settings: [String: MobilePluginValue],
        context: MobilePluginRuntimeContext
    ) -> String {
        if token.hasPrefix("settings.") {
            return settings[String(token.dropFirst("settings.".count))]?.stringValue ?? ""
        }
        if token.hasPrefix("schedule.") {
            guard plugin.state.grantedCapabilities.contains(.scheduleRead),
                  let schedule = context.schedule else {
                return ""
            }
            return scheduleValue(String(token.dropFirst("schedule.".count)), schedule: schedule, now: context.now)
        }
        if token.hasPrefix("weather.") {
            guard plugin.state.grantedCapabilities.contains(.weatherRead),
                  let weather = context.weather else {
                return ""
            }
            return weatherValue(String(token.dropFirst("weather.".count)), weather: weather)
        }
        switch token {
        case "now.time": time(context.now)
        case "now.date": context.now.formatted(date: .abbreviated, time: .omitted)
        case "plugin.name": plugin.manifest.name
        case "plugin.version": plugin.manifest.version
        default: ""
        }
    }

    private func scheduleValue(_ key: String, schedule: ScheduleSnapshot, now: Date) -> String {
        switch key {
        case "phase": schedule.phase.rawValue
        case "phase.title": schedule.phase.title
        case "profile": schedule.profileName
        case "plan": schedule.planName
        case "current.subject": schedule.current?.subject ?? ""
        case "current.initial": schedule.current?.initial ?? ""
        case "current.teacher": schedule.current?.teacher ?? ""
        case "current.start": schedule.current.map { time($0.start) } ?? ""
        case "current.end": schedule.current.map { time($0.end) } ?? ""
        case "break.name": schedule.currentBreak?.name ?? ""
        case "break.start": schedule.currentBreak.map { time($0.start) } ?? ""
        case "break.end": schedule.currentBreak.map { time($0.end) } ?? ""
        case "next.subject": schedule.next?.subject ?? ""
        case "next.initial": schedule.next?.initial ?? ""
        case "next.teacher": schedule.next?.teacher ?? ""
        case "next.start": schedule.next.map { time($0.start) } ?? ""
        case "next.end": schedule.next.map { time($0.end) } ?? ""
        case "session.count": String(schedule.sessions.count)
        case "progress": String(scheduleProgress(schedule, now: now))
        default: ""
        }
    }

    private func weatherValue(_ key: String, weather: WeatherSnapshot) -> String {
        switch key {
        case "city": weather.city.displayName
        case "condition": weather.presentation.conditionTitle
        case "temperature": weather.current.temperature
        case "feelsLike": weather.current.feelsLike
        case "humidity": weather.current.humidity
        case "pressure": weather.current.pressure
        case "windSpeed": weather.current.windSpeed
        case "aqi": weather.airQualityIndex
        case "alert.count": String(weather.alerts.count)
        default: ""
        }
    }

    private func scheduleProgress(_ schedule: ScheduleSnapshot, now: Date) -> Double {
        let interval: (Date, Date)? = switch schedule.phase {
        case .inClass:
            schedule.current.map { ($0.start, $0.end) }
        case .breakTime:
            schedule.currentBreak.map { ($0.start, $0.end) }
        case .upcoming, .afterSchool, .noSchedule:
            nil
        }
        guard let interval else { return 0 }
        let duration = interval.1.timeIntervalSince(interval.0)
        guard duration > 0 else { return 0 }
        let courseNow = schedule.courseDate(forSystemDate: now)
        return min(max(courseNow.timeIntervalSince(interval.0) / duration, 0), 1)
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func clipped(_ value: String, limit: Int) -> String {
        String(value.prefix(limit))
    }
}
