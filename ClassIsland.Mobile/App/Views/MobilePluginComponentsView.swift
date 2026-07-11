import SwiftUI

struct MobilePluginComponentsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pluginManager: MobilePluginManager

    let schedule: ScheduleSnapshot?
    var pluginID: String?
    var showsHeader = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let context = MobilePluginRuntimeContext(
                now: timeline.date,
                schedule: schedule,
                weather: model.weather
            )
            let components = pluginManager.renderedComponents(context: context).filter {
                pluginID == nil || $0.pluginID == pluginID
            }

            if !components.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if showsHeader {
                        HStack {
                            Label("插件组件", systemImage: "puzzlepiece.extension")
                                .font(.headline)
                            Spacer()
                            Text("\(components.count) 个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 2)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 230, maximum: 380), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(components) { component in
                            if let action = component.action {
                                Button {
                                    Task {
                                        await pluginManager.performComponentAction(
                                            action,
                                            pluginID: component.pluginID,
                                            context: context
                                        )
                                    }
                                } label: {
                                    MobilePluginComponentCard(component: component, showsAction: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                MobilePluginComponentCard(component: component, showsAction: false)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MobilePluginComponentCard: View {
    let component: RenderedMobilePluginComponent
    let showsAction: Bool

    private var tint: Color {
        component.tint.flatMap { Color(pluginHex: $0) } ?? .accentColor
    }

    private var systemImage: String {
        UIImage(systemName: component.systemImage) == nil
            ? "puzzlepiece.extension"
            : component.systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(component.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if !component.subtitle.isEmpty {
                        Text(component.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                if showsAction {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            componentContent

            Text(component.pluginName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.14))
        }
    }

    @ViewBuilder
    private var componentContent: some View {
        switch component.kind {
        case .text:
            Text(component.body.isEmpty ? component.value : component.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

        case .metric:
            Text(component.value.isEmpty ? "--" : component.value)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.72)
                .lineLimit(1)

        case .status:
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text(component.value.isEmpty ? component.body : component.value)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }

        case .progress:
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    if !component.body.isEmpty {
                        Text(component.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(component.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: component.progress)
                    .tint(tint)
            }

        case .list:
            VStack(spacing: 8) {
                ForEach(component.items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let systemImage = item.systemImage {
                            Image(systemName: systemImage)
                                .foregroundStyle(tint)
                                .frame(width: 18)
                        }
                        Text(item.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(item.value)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

private extension Color {
    init?(pluginHex: String) {
        let value = pluginHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
