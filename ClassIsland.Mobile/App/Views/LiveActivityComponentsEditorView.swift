import SwiftUI

private enum LiveActivityEditorSurface: String, CaseIterable, Identifiable {
    case lockScreen
    case expanded
    case compact
    case minimal

    var id: Self { self }

    var title: String {
        switch self {
        case .lockScreen: "锁屏"
        case .expanded: "展开"
        case .compact: "紧凑"
        case .minimal: "最小"
        }
    }

    var systemImage: String {
        switch self {
        case .lockScreen: "iphone"
        case .expanded: "platter.filled.top.iphone"
        case .compact: "capsule"
        case .minimal: "circle"
        }
    }

    var regions: [LiveActivityRegion] {
        switch self {
        case .lockScreen: [.lockHeader, .lockPrimary, .lockProgress, .lockFooter]
        case .expanded: [.expandedLeading, .expandedCenter, .expandedTrailing, .expandedBottom]
        case .compact: [.compactLeading, .compactTrailing]
        case .minimal: [.minimal]
        }
    }
}

struct LiveActivityComponentsEditorView: View {
    @EnvironmentObject private var model: AppModel

    @State private var layout = LiveActivityLayout.default
    @State private var baseline = LiveActivityLayout.default
    @State private var selectedSurface = LiveActivityEditorSurface.lockScreen
    @State private var addingRegion: LiveActivityRegion?
    @State private var editingComponent: ComponentEditingContext?

    private var hasChanges: Bool {
        layout != baseline
    }

    var body: some View {
        VStack(spacing: 0) {
            surfacePicker
            Divider()

            ScrollView {
                LiveActivityLayoutPreview(layout: layout, surface: selectedSurface)
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
            }
            .scrollDisabled(true)
            .frame(height: selectedSurface == .lockScreen ? 220 : 180)

            componentList
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("灵动岛组件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Menu {
                    Button("恢复当前视图", systemImage: "arrow.counterclockwise") {
                        for region in selectedSurface.regions {
                            layout.reset(region: region)
                        }
                    }
                    Button("恢复全部默认布局", systemImage: "arrow.triangle.2.circlepath") {
                        layout = .default
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多")

                Button("保存", systemImage: "checkmark") {
                    saveLayout()
                }
                .disabled(!hasChanges)
            }
        }
        .onAppear {
            layout = model.settings.liveActivityLayout
            baseline = layout
        }
        .onDisappear {
            if hasChanges {
                saveLayout()
            }
        }
        .sheet(item: $addingRegion) { region in
            ComponentLibraryView(region: region) { kind in
                layout.add(LiveActivityComponentConfiguration(kind: kind), to: region)
            }
        }
        .sheet(item: $editingComponent) { context in
            LiveActivityComponentSettingsSheet(context: context) { updated in
                layout.update(updated, in: context.region)
            }
        }
    }

    private func saveLayout() {
        var settings = model.settings
        settings.liveActivityLayout = layout
        model.settings = settings
        baseline = layout
    }

    private var surfacePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(LiveActivityEditorSurface.allCases) { surface in
                    Button {
                        withAnimation(.snappy) { selectedSurface = surface }
                    } label: {
                        Label(surface.title, systemImage: surface.systemImage)
                            .font(.subheadline.weight(selectedSurface == surface ? .semibold : .regular))
                            .foregroundStyle(selectedSurface == surface ? Color.accentColor : Color.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(selectedSurface == surface ? Color.accentColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedSurface == surface ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.regularMaterial)
    }

    private var componentList: some View {
        List {
            ForEach(selectedSurface.regions) { region in
                Section {
                    let components = layout.components(in: region)
                    if components.isEmpty {
                        Text("未添加组件")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(components) { component in
                            Button {
                                editingComponent = ComponentEditingContext(region: region, component: component)
                            } label: {
                                LiveActivityComponentRow(component: component)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { layout.remove(at: $0, from: region) }
                        .onMove { layout.move(from: $0, to: $1, in: region) }
                    }
                } header: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.title)
                            Text("\(layout.components(in: region).count)/\(region.maximumComponentCount) 个组件")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                        Spacer()
                        Button("添加", systemImage: "plus") {
                            addingRegion = region
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                        .disabled(layout.components(in: region).count >= region.maximumComponentCount)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

private struct LiveActivityComponentRow: View {
    let component: LiveActivityComponentConfiguration

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: component.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(component.kind.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            if component.isEmphasized {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("强调显示")
            }
            if !component.showsIcon {
                Image(systemName: "photo.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("隐藏图标")
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        switch component.kind {
        case .customText where !component.customText.isEmpty:
            component.customText
        case .weather:
            "显示\(component.weatherMetric.title)。"
        case .plugin:
            "显示首个可用的插件实时活动内容。"
        default:
            component.kind.description
        }
    }
}

private struct ComponentEditingContext: Identifiable {
    let id = UUID()
    let region: LiveActivityRegion
    let component: LiveActivityComponentConfiguration
}

private struct LiveActivityComponentSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let region: LiveActivityRegion
    let onSave: (LiveActivityComponentConfiguration) -> Void
    @State private var component: LiveActivityComponentConfiguration

    init(
        context: ComponentEditingContext,
        onSave: @escaping (LiveActivityComponentConfiguration) -> Void
    ) {
        region = context.region
        self.onSave = onSave
        _component = State(initialValue: context.component)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("组件") {
                    LabeledContent("类型", value: component.kind.title)
                    LabeledContent("区域", value: region.title)
                }

                if component.kind == .customText {
                    Section("内容") {
                        TextField("自定义文本", text: $component.customText)
                            .onChange(of: component.customText) { _, value in
                                if value.count > LiveActivityComponentConfiguration.maximumCustomTextLength {
                                    component.customText = String(
                                        value.prefix(LiveActivityComponentConfiguration.maximumCustomTextLength)
                                    )
                                }
                            }
                    }
                }

                if component.kind == .clock {
                    Section {
                        Toggle("显示秒数", isOn: $component.clockShowsSeconds)
                        Toggle("使用系统时间", isOn: $component.clockUsesSystemTime)
                    } header: {
                        Text("时钟")
                    } footer: {
                        Text("使用系统时间后，该组件不会应用“时钟”设置页中的课程时间偏移。")
                    }
                }

                if component.kind == .weather {
                    Section("天气") {
                        Picker("显示内容", selection: $component.weatherMetric) {
                            ForEach(WeatherMetric.allCases) { metric in
                                Label(metric.title, systemImage: metric.systemImage)
                                    .tag(metric)
                            }
                        }
                    }
                }

                Section("外观") {
                    Toggle("显示图标", isOn: $component.showsIcon)
                    Toggle("使用主题色强调", isOn: $component.isEmphasized)
                }
            }
            .navigationTitle("组件设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(component)
                        dismiss()
                    }
                    .disabled(
                        component.kind == .customText
                            && component.customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ComponentLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let region: LiveActivityRegion
    let onSelect: (LiveActivityComponentKind) -> Void

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(LiveActivityComponentKind.allCases) { kind in
                        Button {
                            onSelect(kind)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: kind.systemImage)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 38, height: 38)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Text(kind.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(kind.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.16))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("添加到“\(region.title)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

private struct LiveActivityLayoutPreview: View {
    let layout: LiveActivityLayout
    let surface: LiveActivityEditorSurface

    var body: some View {
        ZStack {
            previewBackground
            switch surface {
            case .lockScreen:
                lockScreenPreview
            case .expanded:
                expandedPreview
            case .compact:
                compactPreview
            case .minimal:
                minimalPreview
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: surface == .lockScreen ? 184 : 144)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .topLeading) {
            Label("预览", systemImage: "eye")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(10)
        }
        .environment(\.dynamicTypeSize, .medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("实时活动布局预览")
    }

    private var previewBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.025, green: 0.12, blue: 0.15),
                Color(red: 0.04, green: 0.055, blue: 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lockScreenPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(
                LiveActivityEditorSurface.lockScreen.regions.filter {
                    !layout.components(in: $0).isEmpty
                }
            ) { region in
                previewLine(region)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)
        }
    }

    private var expandedPreview: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                previewStack(.expandedLeading, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Capsule()
                    .fill(Color.black)
                    .frame(width: 82, height: 26)

                previewStack(.expandedTrailing, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            previewStack(.expandedCenter, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

            previewStack(.expandedBottom, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 34)
        .padding(.bottom, 12)
    }

    private var compactPreview: some View {
        HStack(spacing: 10) {
            previewStack(.compactLeading, alignment: .leading)
            Spacer(minLength: 52)
            previewStack(.compactTrailing, alignment: .trailing)
                .frame(minWidth: 44, alignment: .trailing)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .frame(width: 230, height: 38)
        .background(Color.black)
        .clipShape(Capsule())
    }

    private var minimalPreview: some View {
        previewStack(.minimal, alignment: .center)
            .frame(width: 38, height: 38)
            .background(Color.black)
            .clipShape(Circle())
    }

    private func previewLine(_ region: LiveActivityRegion) -> some View {
        HStack(spacing: 8) {
            let components = layout.components(in: region)
            ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                if index > 0 { Spacer(minLength: 4) }
                PreviewComponentView(component: component, presentation: .full)
            }
        }
    }

    private func previewStack(
        _ region: LiveActivityRegion,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            ForEach(layout.components(in: region)) { component in
                PreviewComponentView(
                    component: component,
                    presentation: region == .minimal
                        ? .minimal
                        : region == .compactLeading || region == .compactTrailing
                            ? .compact
                            : .full
                )
            }
        }
    }
}

private enum PreviewComponentPresentation: Equatable {
    case full
    case compact
    case minimal
}

private struct PreviewComponentView: View {
    let component: LiveActivityComponentConfiguration
    let presentation: PreviewComponentPresentation

    private var color: Color {
        component.isEmphasized ? Color.accentColor : .white
    }

    private var isCompact: Bool {
        presentation != .full
    }

    var body: some View {
        Group {
            if presentation == .minimal {
                minimalContent
            } else {
                switch component.kind {
                case .status:
                    previewLabel(isCompact ? "课" : "正在上课", icon: "book.closed.fill")
                case .currentLesson:
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if component.showsIcon {
                            Image(systemName: "book.closed.fill")
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isCompact ? "数" : "数学")
                                .font(isCompact ? .caption2.weight(.bold) : .headline)
                            if !isCompact {
                                Text("周老师")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                case .countdown:
                    previewLabel("24:18", icon: "timer")
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                case .progress:
                    if component.showsIcon && isCompact {
                        Image(systemName: "chart.bar.fill")
                    } else {
                        ProgressView(value: 0.46)
                            .tint(color)
                            .frame(minWidth: isCompact ? 18 : 90)
                    }
                case .nextLesson:
                    previewLabel(isCompact ? "英" : "下一节 英语 09:50", icon: "arrow.right.circle")
                case .profileName:
                    previewLabel(isCompact ? "高二" : "高二（3）班", icon: "person.crop.rectangle")
                case .weather:
                    previewLabel(weatherPreviewText, icon: weatherPreviewIcon)
                case .clock:
                    previewLabel(
                        component.clockShowsSeconds ? "08:21:36" : "08:21",
                        icon: "clock"
                    )
                        .monospacedDigit()
                case .date:
                    previewLabel("7月10日", icon: "calendar")
                case .plugin:
                    previewLabel(isCompact ? "插" : "插件 下一节英语", icon: "puzzlepiece.extension")
                case .customText:
                    previewLabel(
                        component.customText.isEmpty ? "ClassIsland" : component.customText,
                        icon: "textformat"
                    )
                }
            }
        }
        .foregroundStyle(color)
        .lineLimit(1)
    }

    @ViewBuilder
    private var minimalContent: some View {
        switch component.kind {
        case .status: minimalLabel("课", icon: "book.closed.fill")
        case .currentLesson: minimalLabel("数", icon: "book.closed.fill")
        case .countdown: minimalLabel("计", icon: "timer")
        case .progress: minimalLabel("进", icon: "chart.bar.fill")
        case .nextLesson: minimalLabel("英", icon: "arrow.right.circle")
        case .profileName: minimalLabel("高", icon: "person.crop.rectangle")
        case .weather:
            minimalLabel(component.weatherMetric.shortTitle, icon: weatherPreviewIcon)
        case .clock: minimalLabel("时", icon: "clock")
        case .date: minimalLabel("日", icon: "calendar")
        case .plugin: minimalLabel("插", icon: "puzzlepiece.extension")
        case .customText:
            minimalLabel(
                String((component.customText.isEmpty ? "C" : component.customText).prefix(1)),
                icon: "textformat"
            )
        }
    }

    private var weatherPreviewText: String {
        switch component.weatherMetric {
        case .condition: isCompact ? "晴 27°" : "晴 27℃"
        case .humidity: "湿度 65%"
        case .wind: "风速 8 km/h"
        case .airQuality: "AQI 42"
        case .pressure: "气压 1012 hPa"
        case .feelsLike: "体感 29℃"
        }
    }

    private var weatherPreviewIcon: String {
        component.weatherMetric == .condition
            ? "sun.max.fill"
            : component.weatherMetric.systemImage
    }

    private func previewLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            if component.showsIcon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(isCompact ? .caption2.weight(.semibold) : .caption.weight(.medium))
    }

    @ViewBuilder
    private func minimalLabel(_ text: String, icon: String) -> some View {
        if component.showsIcon {
            Image(systemName: icon)
        } else {
            Text(text)
                .font(.caption2.weight(.bold))
        }
    }
}
