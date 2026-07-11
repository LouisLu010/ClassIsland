import Foundation

struct ScheduleEngine: Sendable {
    func snapshot(
        profile: ClassIslandProfile,
        settings: MobileSettings,
        at now: Date,
        for selectedDate: Date? = nil,
        calendar sourceCalendar: Calendar = .current
    ) -> ScheduleSnapshot {
        var calendar = sourceCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        let courseNow = now.addingTimeInterval(settings.timeOffsetSeconds)
        let date = selectedDate ?? courseNow
        let planEntry = selectPlan(profile: profile, settings: settings, date: date, calendar: calendar)
        let sessions = planEntry.map {
            buildSessions(profile: profile, planId: $0.key, plan: $0.value, date: date, calendar: calendar)
        } ?? []
        let breaks = planEntry.map {
            buildBreaks(profile: profile, planId: $0.key, plan: $0.value, date: date, calendar: calendar)
        } ?? []

        guard !sessions.isEmpty else {
            return ScheduleSnapshot(
                date: date,
                profileName: profile.name,
                planName: planEntry?.value.name ?? "",
                phase: .noSchedule,
                sessions: [],
                breaks: breaks,
                current: nil,
                currentBreak: nil,
                next: nil,
                timeOffsetSeconds: settings.timeOffsetSeconds
            )
        }

        let isToday = calendar.isDate(date, inSameDayAs: courseNow)
        let referenceTime = isToday ? courseNow : calendar.startOfDay(for: date)
        let current = isToday
            ? sessions.first(where: { $0.start <= referenceTime && referenceTime < $0.end })
            : nil
        let currentBreak = isToday
            ? breaks.first(where: { $0.start <= referenceTime && referenceTime < $0.end })
            : nil
        let next = isToday
            ? sessions.first(where: { session in
                if let current {
                    return session.start > current.start
                }
                return session.start > referenceTime
            })
            : sessions.first

        let phase: SchedulePhase
        if !isToday || referenceTime < sessions[0].start {
            phase = .upcoming
        } else if current != nil {
            phase = .inClass
        } else if referenceTime >= sessions[sessions.count - 1].end {
            phase = .afterSchool
        } else {
            phase = .breakTime
        }

        return ScheduleSnapshot(
            date: date,
            profileName: profile.name,
            planName: planEntry?.value.name ?? "",
            phase: phase,
            sessions: sessions,
            breaks: breaks,
            current: current,
            currentBreak: currentBreak,
            next: next,
            timeOffsetSeconds: settings.timeOffsetSeconds
        )
    }

    private func selectPlan(
        profile: ClassIslandProfile,
        settings: MobileSettings,
        date: Date,
        calendar: Calendar
    ) -> (key: String, value: ClassIslandClassPlan)? {
        if let ordered = profile.orderedSchedules.first(where: {
            ClassIslandDateParser.isSameDay($0.key, as: date, calendar: calendar)
        }), let plan = value(in: profile.classPlans, id: ordered.value.classPlanId),
           !plan.isOverlay || profile.isOverlayClassPlanEnabled {
            return (ordered.value.classPlanId, plan)
        }

        if let tempId = profile.tempClassPlanId,
           let setupValue = profile.tempClassPlanSetupTime,
           let setupDate = ClassIslandDateParser.date(from: setupValue, calendar: calendar),
           calendar.startOfDay(for: setupDate) >= calendar.startOfDay(for: date),
           let plan = value(in: profile.classPlans, id: tempId) {
            return (tempId, plan)
        }

        let tempGroupNotExpired = profile.tempClassPlanGroupExpireTime.flatMap {
            ClassIslandDateParser.date(from: $0, calendar: calendar)
        }.map {
            calendar.startOfDay(for: $0) >= calendar.startOfDay(for: date)
        } ?? false
        let tempGroupActive = profile.isTempClassPlanGroupEnabled
            && profile.tempClassPlanGroupId != nil
            && tempGroupNotExpired

        return profile.classPlans
            .filter { _, plan in
                guard matchesGroup(plan, profile: profile, tempGroupActive: tempGroupActive) else { return false }
                return matchesTimeRule(plan, settings: settings, date: date, calendar: calendar)
            }
            .sorted { left, right in
                let leftPriority = groupPriority(left.value.associatedGroup, profile: profile, tempGroupActive: tempGroupActive)
                let rightPriority = groupPriority(right.value.associatedGroup, profile: profile, tempGroupActive: tempGroupActive)
                if leftPriority != rightPriority { return leftPriority > rightPriority }
                return left.key.localizedCaseInsensitiveCompare(right.key) == .orderedAscending
            }
            .first
    }

    private func matchesGroup(
        _ plan: ClassIslandClassPlan,
        profile: ClassIslandProfile,
        tempGroupActive: Bool
    ) -> Bool {
        let group = normalizedId(plan.associatedGroup)
        let selected = normalizedId(profile.selectedClassPlanGroupId)
        let global = normalizedId(ClassIslandClassPlan.globalGroupId)
        let temp = profile.tempClassPlanGroupId.map { normalizedId($0) }

        guard tempGroupActive, let temp else {
            return group == selected || group == global
        }
        switch profile.tempClassPlanGroupType {
        case 0:
            return group == temp || group == global
        case 1:
            return group == temp || group == selected || group == global
        default:
            return group == selected || group == global
        }
    }

    private func groupPriority(
        _ groupId: String,
        profile: ClassIslandProfile,
        tempGroupActive: Bool
    ) -> Int {
        let group = normalizedId(groupId)
        if tempGroupActive,
           let tempGroupId = profile.tempClassPlanGroupId,
           group == normalizedId(tempGroupId) {
            return 3
        }
        if group == normalizedId(profile.selectedClassPlanGroupId) { return 2 }
        if group == normalizedId(ClassIslandClassPlan.globalGroupId) { return 1 }
        return 0
    }

    private func matchesTimeRule(
        _ plan: ClassIslandClassPlan,
        settings: MobileSettings,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        guard !plan.isOverlay, plan.isEnabled else { return false }
        let dotNetWeekday = calendar.component(.weekday, from: date) - 1
        guard plan.timeRule.weekDay == dotNetWeekday else { return false }
        guard plan.timeRule.weekCountDivTotal <= settings.maxRotationCycle else { return false }
        guard plan.timeRule.weekCountDiv > 0 else { return true }
        return plan.timeRule.weekCountDiv == rotationPosition(
            date: date,
            cycleLength: plan.timeRule.weekCountDivTotal,
            settings: settings,
            calendar: calendar
        )
    }

    private func rotationPosition(
        date: Date,
        cycleLength: Int,
        settings: MobileSettings,
        calendar: Calendar
    ) -> Int {
        let anchor = calendar.startOfDay(for: settings.singleWeekStartTime)
        let target = calendar.startOfDay(for: date)
        let elapsedDays = calendar.dateComponents([.day], from: anchor, to: target).day ?? 0
        let elapsedWeeks = Int(floor(Double(elapsedDays) / 7.0))
        let offset = settings.rotationOffset(for: cycleLength)
        let zeroBased = ((elapsedWeeks + offset) % cycleLength + cycleLength) % cycleLength
        return zeroBased + 1
    }

    private func buildSessions(
        profile: ClassIslandProfile,
        planId: String,
        plan: ClassIslandClassPlan,
        date: Date,
        calendar: Calendar
    ) -> [ScheduleSession] {
        guard let layout = value(in: profile.timeLayouts, id: plan.timeLayoutId) else { return [] }
        let classPoints = layout.layouts.filter { $0.timeType == 0 }
        return classPoints.enumerated().compactMap { index, point in
            guard index < plan.classes.count,
                  plan.classes[index].isEnabled,
                  let startSeconds = ClassIslandDateParser.secondsSinceMidnight(point.startTimeValue),
                  let endSeconds = ClassIslandDateParser.secondsSinceMidnight(point.endTimeValue),
                  let start = calendar.date(byAdding: .second, value: Int(startSeconds), to: calendar.startOfDay(for: date)),
                  var end = calendar.date(byAdding: .second, value: Int(endSeconds), to: calendar.startOfDay(for: date)) else {
                return nil
            }
            let subject = value(in: profile.subjects, id: plan.classes[index].subjectId)
            if end < start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            return ScheduleSession(
                id: "\(planId)-\(index)",
                index: index,
                start: start,
                end: end,
                subject: subject?.name ?? "未命名课程",
                initial: subject?.initial ?? "",
                teacher: subject?.teacherName ?? "",
                isOutdoor: subject?.isOutdoor ?? false
            )
        }.sorted { $0.start < $1.start }
    }

    private func buildBreaks(
        profile: ClassIslandProfile,
        planId: String,
        plan: ClassIslandClassPlan,
        date: Date,
        calendar: Calendar
    ) -> [ScheduleBreak] {
        guard let layout = value(in: profile.timeLayouts, id: plan.timeLayoutId) else { return [] }
        return layout.layouts.enumerated().compactMap { index, point in
            guard point.timeType == 1,
                  let startSeconds = ClassIslandDateParser.secondsSinceMidnight(point.startTimeValue),
                  let endSeconds = ClassIslandDateParser.secondsSinceMidnight(point.endTimeValue),
                  let start = calendar.date(byAdding: .second, value: Int(startSeconds), to: calendar.startOfDay(for: date)),
                  var end = calendar.date(byAdding: .second, value: Int(endSeconds), to: calendar.startOfDay(for: date)) else {
                return nil
            }
            if end < start {
                end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            }
            return ScheduleBreak(
                id: "\(planId)-break-\(index)",
                start: start,
                end: end,
                name: point.breakName.isEmpty ? "课间休息" : point.breakName
            )
        }.sorted { $0.start < $1.start }
    }

    private func normalizedId(_ value: String) -> String {
        value.lowercased()
    }

    private func value<Value>(in dictionary: [String: Value], id: String) -> Value? {
        dictionary[id] ?? dictionary.first(where: { normalizedId($0.key) == normalizedId(id) })?.value
    }
}
