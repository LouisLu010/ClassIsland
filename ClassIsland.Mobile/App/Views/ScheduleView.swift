import SwiftUI
import UniformTypeIdentifiers

struct ScheduleView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var isImporterPresented = false
    @State private var followsToday = true

    private var snapshot: ScheduleSnapshot? {
        model.snapshot(for: selectedDate)
    }

    private var courseToday: Date {
        Calendar.current.startOfDay(
            for: Date().addingTimeInterval(model.settings.timeOffsetSeconds)
        )
    }

    private func isCourseToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: courseToday)
    }

    private func displayedSessions(_ snapshot: ScheduleSnapshot) -> [ScheduleSession] {
        if model.settings.showCurrentLessonOnlyOnClass,
           isCourseToday(selectedDate),
           let current = snapshot.current {
            return [current]
        }
        return snapshot.sessions
    }

    var body: some View {
        Group {
            if model.profile == nil {
                emptyState
            } else {
                scheduleContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("课表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("上一天", systemImage: "chevron.left") {
                    shiftDate(by: -1)
                }
                .labelStyle(.iconOnly)

                Button("今天", systemImage: "scope") {
                    withAnimation(.snappy) {
                        selectedDate = courseToday
                        followsToday = true
                    }
                }
                .labelStyle(.iconOnly)

                Button("下一天", systemImage: "chevron.right") {
                    shiftDate(by: 1)
                }
                .labelStyle(.iconOnly)
            }
        }
        .refreshable {
            await model.refreshCurrentSchedule()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await model.importDocument(url) }
            case .failure:
                break
            }
        }
        .onChange(of: model.currentSnapshot?.date) { _, date in
            guard followsToday, let date else { return }
            selectedDate = Calendar.current.startOfDay(for: date)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有课表", systemImage: "calendar.badge.plus")
        } description: {
            Text("从 Windows 版 ClassIsland 的 Profiles 目录选择 Profile.json。")
        } actions: {
            Button("导入课表") {
                isImporterPresented = true
            }
            .buttonStyle(.borderedProminent)

            Button("载入示例") {
                Task { await model.loadSampleProfile() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var scheduleContent: some View {
        let renderedSnapshot = snapshot
        return ScrollView {
            LazyVStack(spacing: 14) {
                DateHeader(selectedDate: selectedDate, snapshot: renderedSnapshot)

                if let snapshot = renderedSnapshot {
                    let sessions = displayedSessions(snapshot)
                    let lastSessionID = sessions.last?.id
                    ScheduleStatusCard(
                        snapshot: snapshot,
                        isToday: isCourseToday(selectedDate),
                        accentColor: model.settings.accentColor,
                        activityStatus: model.activityStatus,
                        showTeacher: model.settings.showTeacher
                    )

                    MobilePluginComponentsView(schedule: snapshot)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("全天课程")
                                .font(.headline)
                            Spacer()
                            Text("\(sessions.count) 节")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.leading, 16)

                        if sessions.isEmpty {
                            Text("当天没有匹配的课表")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        } else {
                            ForEach(sessions) { session in
                                DailySessionRow(
                                    session: session,
                                    isCurrent: snapshot.current?.id == session.id
                                        && isCourseToday(selectedDate),
                                    accentColor: model.settings.accentColor,
                                    showTeacher: model.settings.showTeacher
                                )
                                if session.id != lastSessionID {
                                    Divider()
                                        .padding(.leading, 76)
                                }
                            }
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if !model.statusMessage.isEmpty {
                    Label(model.statusMessage, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: 760)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }

    private func shiftDate(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        withAnimation(.snappy) {
            selectedDate = date
            followsToday = isCourseToday(date)
        }
    }
}

private struct DateHeader: View {
    let selectedDate: Date
    let snapshot: ScheduleSnapshot?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                    .font(.title2.weight(.semibold))
                    .contentTransition(.numericText())
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let name = snapshot?.planName, !name.isEmpty {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct ScheduleStatusCard: View {
    let snapshot: ScheduleSnapshot
    let isToday: Bool
    let accentColor: Color
    let activityStatus: String
    let showTeacher: Bool

    private var focus: ScheduleSession? {
        snapshot.current ?? snapshot.next
    }

    private var headline: String {
        if snapshot.phase == .breakTime {
            return snapshot.currentBreak?.name ?? snapshot.phase.title
        }
        return focus?.subject ?? snapshot.phase.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(isToday ? snapshot.phase.title : "课程预览", systemImage: phaseIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                Spacer()
                if isToday {
                    Text(activityStatus)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let focus {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(headline)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if snapshot.phase != .breakTime, focus.isOutdoor {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    if snapshot.phase == .breakTime, let currentBreak = snapshot.currentBreak {
                        Label(timeRange(currentBreak), systemImage: "clock")
                    } else {
                        Label(timeRange(focus), systemImage: "clock")
                    }
                    if snapshot.phase != .breakTime,
                       showTeacher,
                       !focus.teacher.isEmpty {
                        Label(focus.teacher, systemImage: "person")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if isToday, snapshot.phase == .inClass, let current = snapshot.current {
                    ScheduleProgressView(
                        start: current.start,
                        end: current.end,
                        timeOffsetSeconds: snapshot.timeOffsetSeconds,
                        tint: accentColor
                    )
                } else if isToday,
                          snapshot.phase == .breakTime,
                          let currentBreak = snapshot.currentBreak {
                    ScheduleProgressView(
                        start: currentBreak.start,
                        end: currentBreak.end,
                        timeOffsetSeconds: snapshot.timeOffsetSeconds,
                        tint: accentColor
                    )
                }

                if snapshot.phase == .inClass || snapshot.phase == .breakTime,
                   let next = snapshot.next {
                    HStack {
                        Text("下一节")
                            .foregroundStyle(.secondary)
                        Text(next.subject)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(next.start, style: .time)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            } else {
                Text(snapshot.phase.title)
                    .font(.title3.weight(.semibold))
                Text("换个日期看看，或在设置中重新导入课表。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)
        }
    }

    private var phaseIcon: String {
        switch snapshot.phase {
        case .noSchedule: "calendar.badge.minus"
        case .upcoming: "hourglass"
        case .inClass: "book.closed.fill"
        case .breakTime: "cup.and.saucer.fill"
        case .afterSchool: "checkmark.circle.fill"
        }
    }

    private func timeRange(_ session: ScheduleSession) -> String {
        "\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))"
    }

    private func timeRange(_ scheduleBreak: ScheduleBreak) -> String {
        "\(scheduleBreak.start.formatted(date: .omitted, time: .shortened)) – \(scheduleBreak.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ScheduleProgressView: View {
    let start: Date
    let end: Date
    let timeOffsetSeconds: TimeInterval
    let tint: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ProgressView(
                value: progress(
                    now: context.date.addingTimeInterval(timeOffsetSeconds)
                )
            )
            .tint(tint)
        }
    }

    private func progress(now: Date) -> Double {
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 0 }
        return min(max(now.timeIntervalSince(start) / duration, 0), 1)
    }
}

private struct DailySessionRow: View {
    let session: ScheduleSession
    let isCurrent: Bool
    let accentColor: Color
    let showTeacher: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text("\(session.index + 1)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isCurrent ? .white : accentColor)
                .frame(width: 34, height: 34)
                .background(isCurrent ? accentColor : accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.subject)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                    if session.isOutdoor {
                        Image(systemName: "figure.run")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if showTeacher, !session.teacher.isEmpty {
                    Text(session.teacher)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(session.start, style: .time)
                Text(session.end, style: .time)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrent ? accentColor.opacity(0.08) : Color.clear)
    }
}
