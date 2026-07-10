import ActivityKit
import SwiftUI
import WidgetKit

struct ClassIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleActivityAttributes.self) { context in
            ConfigurableLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.035, green: 0.055, blue: 0.07))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedRegionView(context: context, region: .expandedLeading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedRegionView(context: context, region: .expandedTrailing)
                }

                DynamicIslandExpandedRegion(.center) {
                    ExpandedRegionView(context: context, region: .expandedCenter)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedRegionView(context: context, region: .expandedBottom)
                }
            } compactLeading: {
                CompactRegionView(context: context, region: .compactLeading)
            } compactTrailing: {
                CompactRegionView(context: context, region: .compactTrailing)
                    .frame(minWidth: 28)
            } minimal: {
                MinimalRegionView(context: context)
            }
            .keylineTint(activityAccentColor(context.state.accentRGBA))
            .widgetURL(URL(string: "classisland://schedule"))
        }
    }
}

private struct ConfigurableLockScreenView: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>

    private var accentColor: Color {
        activityAccentColor(context.state.accentRGBA)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(visibleRegions) { region in
                LockScreenLine(context: context, region: region)
            }
        }
        .padding(16)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)
        }
        .widgetURL(URL(string: "classisland://schedule"))
    }

    private var visibleRegions: [LiveActivityRegion] {
        [
            LiveActivityRegion.lockHeader,
            .lockPrimary,
            .lockProgress,
            .lockFooter
        ].filter { !context.state.layout.components(in: $0).isEmpty }
    }
}

private struct LockScreenLine: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>
    let region: LiveActivityRegion

    private var components: [LiveActivityComponentConfiguration] {
        context.state.layout.components(in: region)
    }

    var body: some View {
        if !components.isEmpty {
            HStack(alignment: region == .lockPrimary ? .firstTextBaseline : .center, spacing: 10) {
                ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                    if index > 0 {
                        Spacer(minLength: 6)
                    }
                    LiveActivityComponentView(
                        component: component,
                        context: context,
                        presentation: .lockScreen
                    )
                    .frame(
                        maxWidth: component.kind.prefersFlexibleWidth ? .infinity : nil,
                        alignment: component.kind == .countdown ? .trailing : .leading
                    )
                }
            }
        }
    }
}

private struct ExpandedRegionView: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>
    let region: LiveActivityRegion

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 5) {
            ForEach(context.state.layout.components(in: region)) { component in
                LiveActivityComponentView(
                    component: component,
                    context: context,
                    presentation: .expanded
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch region {
        case .expandedTrailing: .trailing
        case .expandedCenter: .center
        default: .leading
        }
    }

    private var frameAlignment: Alignment {
        switch region {
        case .expandedTrailing: .trailing
        case .expandedCenter: .center
        default: .leading
        }
    }
}

private struct CompactRegionView: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>
    let region: LiveActivityRegion

    private var component: LiveActivityComponentConfiguration? {
        context.state.layout.components(in: region).first
    }

    var body: some View {
        if let component {
            LiveActivityComponentView(
                component: component,
                context: context,
                presentation: .compact
            )
        }
    }
}

private struct MinimalRegionView: View {
    let context: ActivityViewContext<ScheduleActivityAttributes>

    private var component: LiveActivityComponentConfiguration? {
        context.state.layout.components(in: .minimal).first
    }

    var body: some View {
        if let component {
            LiveActivityComponentView(
                component: component,
                context: context,
                presentation: .minimal
            )
        }
    }
}

private enum LiveActivityPresentation: Equatable {
    case lockScreen
    case expanded
    case compact
    case minimal
}

private struct LiveActivityComponentView: View {
    let component: LiveActivityComponentConfiguration
    let context: ActivityViewContext<ScheduleActivityAttributes>
    let presentation: LiveActivityPresentation

    private var emphasizedColor: Color {
        component.isEmphasized ? accentColor : .primary
    }

    private var accentColor: Color {
        activityAccentColor(context.state.accentRGBA)
    }

    var body: some View {
        Group {
            switch presentation {
            case .compact:
                compactContent
            case .minimal:
                minimalContent
            case .lockScreen, .expanded:
                fullContent
            }
        }
        .foregroundStyle(emphasizedColor)
    }

    @ViewBuilder
    private var fullContent: some View {
        switch component.kind {
        case .status:
            Label {
                Text(context.isStale ? "待同步" : phaseLabel(context.state.phase))
            } icon: {
                if component.showsIcon {
                    Image(systemName: context.isStale ? "arrow.clockwise.circle" : phaseIcon(context.state.phase))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                context.isStale
                    ? Color.orange
                    : component.isEmphasized ? accentColor : Color.secondary
            )

        case .currentLesson:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if component.showsIcon {
                    Image(systemName: "book.closed.fill")
                        .font(.caption)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.headline)
                        .font(presentation == .lockScreen ? .title2.weight(.bold) : .headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !context.state.teacher.isEmpty {
                        Text(context.state.teacher)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

        case .countdown:
            HStack(spacing: 4) {
                if component.showsIcon {
                    Image(systemName: "timer")
                        .font(.caption)
                }
                CountdownLabel(state: context.state, compact: false)
                    .font(presentation == .lockScreen ? .title2.weight(.semibold) : .title3.weight(.semibold))
                    .monospacedDigit()
            }

        case .progress:
            HStack(spacing: 6) {
                if component.showsIcon {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                }
                ProgressBar(
                    state: context.state,
                    tint: component.isEmphasized ? accentColor : .secondary
                )
            }

        case .nextLesson:
            if !context.state.nextTitle.isEmpty {
                HStack(spacing: 7) {
                    if component.showsIcon {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                    Text("下一节")
                        .foregroundStyle(.secondary)
                    Text(context.state.nextTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if let date = context.state.nextStart {
                        Text(date, style: .time)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

        case .profileName:
            iconText(
                text: context.attributes.profileName,
                systemImage: "person.crop.rectangle",
                font: .caption2
            )

        case .clock:
            HStack(spacing: 4) {
                if component.showsIcon { Image(systemName: "clock") }
                Text(context.state.updatedAt, style: .time)
                    .monospacedDigit()
            }
            .font(.caption)

        case .date:
            HStack(spacing: 4) {
                if component.showsIcon { Image(systemName: "calendar") }
                Text(context.state.updatedAt, format: .dateTime.month().day())
            }
            .font(.caption)

        case .customText:
            iconText(
                text: component.customText.isEmpty ? "ClassIsland" : component.customText,
                systemImage: "textformat",
                font: .caption
            )
        }
    }

    @ViewBuilder
    private var compactContent: some View {
        switch component.kind {
        case .status:
            if component.showsIcon {
                Image(systemName: phaseIcon(context.state.phase))
            } else {
                Text(shortPhaseLabel(context.state.phase))
                    .font(.caption2.weight(.bold))
            }
        case .currentLesson:
            compactLabel(
                text: context.state.compactTitle,
                systemImage: "book.closed.fill"
            )
        case .countdown:
            HStack(spacing: 3) {
                if component.showsIcon {
                    Image(systemName: "timer")
                }
                CountdownLabel(state: context.state, compact: true)
                    .monospacedDigit()
            }
            .font(.caption2.weight(.semibold))
        case .progress:
            if component.showsIcon {
                Image(systemName: "chart.bar.fill")
            } else {
                ProgressBar(
                    state: context.state,
                    tint: component.isEmphasized ? accentColor : .secondary
                )
                .frame(width: 18)
            }
        case .nextLesson:
            compactLabel(
                text: String(context.state.nextTitle.prefix(2)),
                systemImage: "arrow.right.circle"
            )
        case .profileName:
            compactLabel(
                text: String(context.attributes.profileName.prefix(2)),
                systemImage: "person.crop.rectangle"
            )
        case .clock:
            HStack(spacing: 3) {
                if component.showsIcon { Image(systemName: "clock") }
                Text(context.state.updatedAt, style: .time)
                    .monospacedDigit()
            }
            .font(.caption2)
        case .date:
            HStack(spacing: 3) {
                if component.showsIcon { Image(systemName: "calendar") }
                Text(context.state.updatedAt, format: .dateTime.month().day())
            }
            .font(.caption2)
        case .customText:
            compactLabel(
                text: String((component.customText.isEmpty ? "CI" : component.customText).prefix(2)),
                systemImage: "textformat"
            )
        }
    }

    @ViewBuilder
    private var minimalContent: some View {
        switch component.kind {
        case .status:
            if component.showsIcon {
                Image(systemName: phaseIcon(context.state.phase))
            } else {
                Text(shortPhaseLabel(context.state.phase))
                    .font(.caption2.weight(.bold))
            }
        case .currentLesson:
            minimalLabel(
                text: String(context.state.compactTitle.prefix(1)),
                systemImage: "book.closed.fill"
            )
        case .countdown:
            minimalLabel(text: "计", systemImage: "timer")
        case .progress:
            minimalLabel(text: "进", systemImage: "chart.bar.fill")
        case .nextLesson:
            minimalLabel(
                text: String(context.state.nextTitle.prefix(1)),
                systemImage: "arrow.right.circle"
            )
        case .profileName:
            minimalLabel(
                text: String(context.attributes.profileName.prefix(1)),
                systemImage: "person.crop.rectangle"
            )
        case .clock:
            minimalLabel(text: "时", systemImage: "clock")
        case .date:
            minimalLabel(text: "日", systemImage: "calendar")
        case .customText:
            minimalLabel(
                text: String((component.customText.isEmpty ? "C" : component.customText).prefix(1)),
                systemImage: "textformat"
            )
        }
    }

    private func compactLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 3) {
            if component.showsIcon {
                Image(systemName: systemImage)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
    }

    @ViewBuilder
    private func minimalLabel(text: String, systemImage: String) -> some View {
        if component.showsIcon {
            Image(systemName: systemImage)
        } else {
            Text(text.isEmpty ? "-" : text)
                .font(.caption2.weight(.bold))
        }
    }

    private func iconText(text: String, systemImage: String, font: Font) -> some View {
        HStack(spacing: 4) {
            if component.showsIcon {
                Image(systemName: systemImage)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(font)
        .foregroundStyle(component.isEmphasized ? accentColor : Color.secondary)
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
    let tint: Color

    var body: some View {
        if let start = state.timerStart,
           let end = state.timerEnd,
           end > start {
            ProgressView(timerInterval: start...end, countsDown: true)
                .tint(tint)
        } else {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 4)
        }
    }
}

private extension LiveActivityComponentKind {
    var prefersFlexibleWidth: Bool {
        self == .currentLesson || self == .progress || self == .nextLesson
    }
}

private func activityAccentColor(_ rgba: UInt32) -> Color {
    Color(
        red: Double((rgba >> 24) & 0xFF) / 255,
        green: Double((rgba >> 16) & 0xFF) / 255,
        blue: Double((rgba >> 8) & 0xFF) / 255,
        opacity: Double(rgba & 0xFF) / 255
    )
}

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

private func shortPhaseLabel(_ phase: SchedulePhase) -> String {
    switch phase {
    case .noSchedule: "无"
    case .upcoming: "待"
    case .inClass: "课"
    case .breakTime: "休"
    case .afterSchool: "完"
    }
}
