import ActivityKit
import SwiftUI
import WidgetKit

struct ClassIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleActivityAttributes.self) { context in
            LockScreenScheduleView(context: context)
                .activityBackgroundTint(Color(red: 0.035, green: 0.055, blue: 0.07))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: phaseIcon(context.state.phase))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(classIslandBlue)
                        Text(context.isStale ? "待同步" : phaseLabel(context.state.phase))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(context.isStale ? Color.orange : Color.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(state: context.state, compact: false)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(classIslandBlue)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.headline)
                            .font(.headline)
                            .lineLimit(1)
                        if !context.state.teacher.isEmpty {
                            Text(context.state.teacher)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if !context.state.nextTitle.isEmpty {
                            Label("下一节", systemImage: "arrow.right.circle")
                                .foregroundStyle(.secondary)
                            Text(context.state.nextTitle)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            if let date = context.state.nextStart {
                                Text(date, style: .time)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ProgressBar(state: context.state)
                        }
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Text(context.state.compactTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(classIslandBlue)
                    .lineLimit(1)
            } compactTrailing: {
                CountdownLabel(state: context.state, compact: true)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 36)
            } minimal: {
                Image(systemName: phaseIcon(context.state.phase))
                    .foregroundStyle(classIslandBlue)
            }
            .keylineTint(classIslandBlue)
            .widgetURL(URL(string: "classisland://schedule"))
        }
    }
}

private struct LockScreenScheduleView: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label {
                    Text(phaseLabel(context.state.phase))
                } icon: {
                    Image(systemName: phaseIcon(context.state.phase))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(classIslandBlue)

                Spacer()

                if context.isStale {
                    Label("待同步", systemImage: "arrow.clockwise.circle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text(context.attributes.profileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.headline)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !context.state.teacher.isEmpty {
                        Text(context.state.teacher)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                CountdownLabel(state: context.state, compact: false)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(classIslandBlue)
            }

            ProgressBar(state: context.state)

            if !context.state.nextTitle.isEmpty {
                HStack {
                    Text("下一节")
                        .foregroundStyle(.secondary)
                    Text(context.state.nextTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if let date = context.state.nextStart {
                        Text(date, style: .time)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
        .padding(16)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(classIslandBlue)
                .frame(width: 4)
        }
        .widgetURL(URL(string: "classisland://schedule"))
    }
}

private struct CountdownLabel: View {
    let state: ScheduleActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        if let start = state.timerStart,
           let end = state.timerEnd,
           end > start {
            Text(
                timerInterval: start...end,
                countsDown: true,
                showsHours: !compact
            )
        } else {
            Image(systemName: state.phase == .afterSchool ? "checkmark" : "minus")
        }
    }
}

private struct ProgressBar: View {
    let state: ScheduleActivityAttributes.ContentState

    var body: some View {
        if let start = state.timerStart,
           let end = state.timerEnd,
           end > start {
            ProgressView(timerInterval: start...end, countsDown: true)
                .tint(classIslandBlue)
        } else {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 4)
        }
    }
}

private let classIslandBlue = Color(red: 0.02, green: 0.67, blue: 0.91)

private func phaseIcon(_ phase: SchedulePhase) -> String {
    switch phase {
    case .noSchedule: "calendar.badge.minus"
    case .upcoming: "hourglass"
    case .inClass: "book.closed.fill"
    case .breakTime: "cup.and.saucer.fill"
    case .afterSchool: "checkmark.circle.fill"
    }
}

private func phaseLabel(_ phase: SchedulePhase) -> String {
    switch phase {
    case .noSchedule: "无课程"
    case .upcoming: "即将开始"
    case .inClass: "正在上课"
    case .breakTime: "课间休息"
    case .afterSchool: "已放学"
    }
}
