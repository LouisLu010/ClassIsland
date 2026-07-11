import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let page: AppPage

    @State private var isImporterPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        pageContent
            .navigationTitle(horizontalSizeClass == .compact ? page.title : "")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImport
            )
            .confirmationDialog(
                "删除本机课表？",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    Task { await model.removeProfile() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("课表文件将从本机移除，实时活动也会停止。")
            }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .schedule:
            ScheduleView()
        case .profile:
            ProfileEditorView()
        case .general:
            generalPage
        case .clock:
            clockPage
        case .weather:
            WeatherSettingsView()
        case .storage:
            storagePage
        case .appearance:
            appearancePage
        case .components:
            LiveActivityComponentsEditorView()
        case .notification:
            notificationPage
        case .plugins:
            PluginsSettingsView()
        case .about:
            aboutPage
        }
    }

    private var generalPage: some View {
        SettingsPageLayout(title: page.title) {
            SettingsSectionTitle("课表显示", systemImage: "rectangle.on.rectangle")

            SettingsCard(
                systemImage: "person.text.rectangle",
                title: "显示任课教师",
                description: "在课程详情和实时活动中显示教师姓名。"
            ) {
                Toggle("显示任课教师", isOn: $model.settings.showTeacher)
                    .labelsHidden()
            }

            SettingsCard(
                systemImage: "rectangle.compress.vertical",
                title: "上课时只显示当前课程",
                description: "进入上课状态后，课表页面仅保留正在进行的课程。"
            ) {
                Toggle(
                    "上课时只显示当前课程",
                    isOn: $model.settings.showCurrentLessonOnlyOnClass
                )
                .labelsHidden()
            }

            SettingsSectionTitle("多周轮换", systemImage: "arrow.triangle.2.circlepath")

            SettingsCard(
                systemImage: "calendar.badge.clock",
                title: "学期开始时间",
                description: "作为多周轮换课表的计算起点和每周第一天。"
            ) {
                DatePicker(
                    "学期开始时间",
                    selection: $model.settings.singleWeekStartTime,
                    displayedComponents: .date
                )
                .labelsHidden()
            }

            SettingsPanel(
                systemImage: "repeat",
                title: "轮换周期",
                description: "设置课表的最大轮换周数及各周期偏移。"
            ) {
                SettingsInlineRow(title: "最大多周轮换周数") {
                    Stepper(value: $model.settings.maxRotationCycle, in: 2...12) {
                        Text("\(model.settings.maxRotationCycle) 周")
                            .monospacedDigit()
                    }
                    .fixedSize()
                }

                ForEach(2...model.settings.maxRotationCycle, id: \.self) { cycle in
                    Divider()
                    SettingsInlineRow(
                        title: "\(cycle) 周课表偏移",
                        description: "当前偏移 \(model.settings.rotationOffset(for: cycle)) 周"
                    ) {
                        Stepper(
                            value: Binding(
                                get: { model.settings.rotationOffset(for: cycle) },
                                set: { model.setRotationOffset($0, for: cycle) }
                            ),
                            in: 0...(cycle - 1)
                        ) {
                            Text("\(model.settings.rotationOffset(for: cycle))")
                                .monospacedDigit()
                        }
                        .fixedSize()
                    }
                }
            }

            SettingsInfoBanner(
                "导入 Windows 版 Settings.json 时，学期起始日、轮换周期和偏移会自动同步。"
            )
        }
    }

    private var appearancePage: some View {
        SettingsPageLayout(title: page.title) {
            SettingsSectionTitle("基本", systemImage: "paintbrush")

            SettingsPanel(
                systemImage: "circle.lefthalf.filled",
                title: "应用主题",
                description: "设置应用内界面使用的明暗外观。"
            ) {
                Picker("应用主题", selection: $model.settings.appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(12)
            }

            SettingsPanel(
                systemImage: "paintpalette",
                title: "主题色",
                description: "用于选中状态、进度和实时活动重点信息。"
            ) {
                accentPalette
                    .padding(12)
            }

            SettingsSectionTitle("实时活动", systemImage: "platter.filled.top.iphone")

            SettingsCard(
                systemImage: "character.textbox",
                title: "紧凑区使用科目简称",
                description: "灵动岛空间不足时优先显示科目简称。"
            ) {
                Toggle(
                    "紧凑区使用科目简称",
                    isOn: $model.settings.useInitialInCompactIsland
                )
                .labelsHidden()
            }
        }
    }

    private var clockPage: some View {
        SettingsPageLayout(title: page.title) {
            SettingsSectionTitle("当前时间", systemImage: "clock")

            SettingsPanel(
                systemImage: "clock.fill",
                title: "课程时钟",
                description: "显示应用用于判断上下课状态的当前时间。"
            ) {
                ClockPreview(offsetSeconds: model.settings.timeOffsetSeconds)
                    .padding(18)
            }

            SettingsSectionTitle("时间校准", systemImage: "clock.arrow.2.circlepath")

            SettingsPanel(
                systemImage: "plus.forwardslash.minus",
                title: "时间偏移",
                description: "正值会让课程状态提前切换，负值会让课程状态延后切换。"
            ) {
                SettingsInlineRow(
                    title: "偏移秒数",
                    description: "可在 -300 秒到 300 秒之间调整。"
                ) {
                    Stepper(
                        value: $model.settings.timeOffsetSeconds,
                        in: MobileSettings.timeOffsetRange,
                        step: 0.5
                    ) {
                        Text(formattedTimeOffset)
                            .monospacedDigit()
                            .frame(minWidth: 74, alignment: .trailing)
                    }
                    .fixedSize()
                }

                Divider()
                    .padding(.leading, 12)

                HStack {
                    Spacer()
                    Button("重置偏移", systemImage: "arrow.counterclockwise") {
                        model.settings.timeOffsetSeconds = 0
                    }
                    .disabled(abs(model.settings.timeOffsetSeconds) < 0.001)
                }
                .padding(12)
            }

            SettingsInfoBanner(
                "导入 Windows 版 Settings.json 时，时间偏移也会自动同步。"
            )
        }
    }

    private var formattedTimeOffset: String {
        let value = model.settings.timeOffsetSeconds
        guard abs(value) >= 0.001 else { return "0.0 秒" }
        return String(format: "%+.1f 秒", value)
    }

    private var accentPalette: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 94, maximum: 150), spacing: 10)],
            spacing: 10
        ) {
            if model.settings.importedAccentHex != nil {
                ColorSwatchButton(
                    title: "已导入",
                    color: model.settings.accentColor,
                    isSelected: true,
                    action: {}
                )
                .disabled(true)
            }

            ForEach(AccentPreference.allCases) { option in
                ColorSwatchButton(
                    title: option.title,
                    color: option.color,
                    isSelected: model.settings.importedAccentHex == nil
                        && model.settings.accent == option
                ) {
                    withAnimation(.snappy) {
                        model.setAccent(option)
                    }
                }
            }
        }
    }

    private var notificationPage: some View {
        SettingsPageLayout(title: page.title) {
            SettingsSectionTitle("实时活动与灵动岛", systemImage: "bell.badge")

            SettingsCard(
                systemImage: "platter.filled.top.iphone",
                title: "启用实时活动",
                description: "在锁屏显示当前课程，并在支持的 iPhone 上显示灵动岛。"
            ) {
                Toggle("启用实时活动", isOn: $model.settings.liveActivitiesEnabled)
                    .labelsHidden()
            }

            SettingsCard(
                systemImage: "clock.badge.checkmark",
                title: "放学后保留",
                description: "当天课程结束后继续保留放学状态。"
            ) {
                Toggle("放学后保留", isOn: $model.settings.keepAfterSchoolActivity)
                    .labelsHidden()
            }

            SettingsCard(
                systemImage: "waveform.path.ecg",
                title: "当前状态",
                description: "ActivityKit 与当前课表的同步状态。"
            ) {
                ActivityStatusBadge(text: model.activityStatus)
            }

            SettingsPanel(
                systemImage: "arrow.triangle.2.circlepath",
                title: "活动控制",
                description: "立即同步课表，或结束当前设备上的实时活动。"
            ) {
                ActivityControlButtons()
                .padding(12)
            }

            SettingsInfoBanner(
                "课程倒计时由系统持续显示；课程边界更新受后台刷新调度影响。"
            )
        }
    }

    private var storagePage: some View {
        SettingsPageLayout(title: page.title) {
            SettingsSectionTitle("课表数据", systemImage: "internaldrive")

            if let profile = model.profile {
                SettingsPanel(
                    systemImage: "person.crop.rectangle.stack",
                    title: profile.name.isEmpty ? model.profileFileName : profile.name,
                    description: "当前加载的课表档案。"
                ) {
                    SettingsValueRow(title: "文件", value: model.profileFileName)
                    Divider()
                    SettingsValueRow(title: "课表数量", value: "\(profile.classPlans.count)")
                    Divider()
                    SettingsValueRow(title: "科目数量", value: "\(profile.subjects.count)")
                }
            } else {
                SettingsCard(
                    systemImage: "person.crop.rectangle.stack",
                    title: "尚未导入课表",
                    description: "本机当前没有 ClassIsland 课表数据。"
                ) {
                    EmptyView()
                }
            }

            SettingsActionCard(
                systemImage: "square.and.arrow.down",
                title: "导入 ClassIsland 数据",
                description: "选择 Profile.json 或 Windows 版 Settings.json。"
            ) {
                isImporterPresented = true
            }

            SettingsActionCard(
                systemImage: "sparkles",
                title: "载入内置示例",
                description: "使用内置课表快速查看应用内显示效果。"
            ) {
                Task { await model.loadSampleProfile() }
            }

            if model.profile != nil {
                SettingsActionCard(
                    systemImage: "trash",
                    title: "删除本机课表",
                    description: "移除已导入的课表，并结束当前实时活动。",
                    role: .destructive
                ) {
                    isDeleteConfirmationPresented = true
                }
            }

            if !model.statusMessage.isEmpty {
                SettingsStatusMessage(model.statusMessage)
            }
        }
    }

    private var aboutPage: some View {
        SettingsPageLayout(title: page.title) {
            Image("ClassIslandAboutBanner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(red: 0.05, green: 0.07, blue: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityLabel("ClassIsland")

            SettingsPanel(
                systemImage: "app.badge",
                title: "ClassIsland",
                description: "你的课表，无限可能"
            ) {
                SettingsValueRow(title: "版本", value: "0.1.0")
                Divider()
                SettingsValueRow(title: "移动端", value: "iOS / iPadOS")
                Divider()
                HStack {
                    Text("许可证")
                    Spacer()
                    Link(
                        "GNU GPL v3.0",
                        destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
                    )
                }
                .font(.subheadline)
                .padding(12)
            }

            SettingsSectionTitle("常用链接", systemImage: "link")

            SettingsLinkCard(
                systemImage: "globe",
                title: "项目主页",
                destination: URL(string: "https://classisland.tech")!
            )

            SettingsLinkCard(
                systemImage: "book.closed",
                title: "帮助文档",
                destination: URL(string: "https://docs.classisland.tech")!
            )

            SettingsLinkCard(
                systemImage: "chevron.left.forwardslash.chevron.right",
                title: "GitHub",
                destination: URL(string: "https://github.com/ClassIsland/ClassIsland")!
            )

            Text("Copyright © 2023–\(Calendar.current.component(.year, from: Date())) HelloWRC")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task { await model.importDocument(url) }
    }
}

private struct ClockPreview: View {
    let offsetSeconds: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date.addingTimeInterval(offsetSeconds)
            VStack(alignment: .leading, spacing: 5) {
                Text(
                    date,
                    format: .dateTime
                        .hour(.twoDigitsNoAMPM)
                        .minute(.twoDigits)
                        .second(.twoDigits)
                        .locale(Locale(identifier: "en_GB"))
                )
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

                Text(
                    date,
                    format: .dateTime
                        .year()
                        .month(.wide)
                        .day()
                        .weekday(.wide)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsPageLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if horizontalSizeClass == .regular {
                    Text(title)
                        .font(.title.weight(.regular))
                        .padding(.bottom, 4)
                }

                content
            }
            .frame(maxWidth: 780, alignment: .leading)
            .padding(.horizontal, horizontalSizeClass == .regular ? 24 : 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}

struct SettingsSectionTitle: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.horizontal, 2)
    }
}

struct SettingsCard<Accessory: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemImage: String
    let title: String
    let description: String?
    let accessory: Accessory

    init(
        systemImage: String,
        title: String,
        description: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.accessory = accessory()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    label
                    accessory
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    label
                    Spacer(minLength: 8)
                    accessory
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .settingsCardBackground()
    }

    private var label: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct SettingsPanel<Content: View>: View {
    let systemImage: String
    let title: String
    let description: String?
    let content: Content

    init(
        systemImage: String,
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                SettingsIcon(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if let description {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)

            Divider()
                .padding(.leading, 58)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCardBackground()
    }
}

private struct SettingsIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 32, height: 32)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsInlineRow<Accessory: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let description: String?
    let accessory: Accessory

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.description = description
        self.accessory = accessory()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    label
                    accessory
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    label
                    Spacer(minLength: 8)
                    accessory
                }
            }
        }
        .padding(12)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.subheadline)
        .padding(12)
    }
}

private struct SettingsActionCard: View {
    let systemImage: String
    let title: String
    let description: String?
    let role: ButtonRole?
    let action: () -> Void

    init(
        systemImage: String,
        title: String,
        description: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 14) {
                SettingsIcon(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if let description {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .settingsCardBackground()
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLinkCard: View {
    let systemImage: String
    let title: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 14) {
                SettingsIcon(systemImage: systemImage)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .settingsCardBackground()
        }
        .buttonStyle(.plain)
    }
}

private struct ColorSwatchButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.horizontal, 6)
            .background(isSelected ? color.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.65) : Color(uiColor: .separator).opacity(0.2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ActivityStatusBadge: View {
    let text: String

    private var color: Color {
        switch text {
        case "正在显示": .green
        case "不可用": .red
        case "已停止": .orange
        default: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ActivityControlButtons: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                refreshButton
                stopButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 10) {
                refreshButton
                stopButton
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var refreshButton: some View {
        Button("立即刷新", systemImage: "arrow.clockwise") {
            Task { await model.refreshCurrentSchedule() }
        }
        .buttonStyle(.borderedProminent)
    }

    private var stopButton: some View {
        Button("停止实时活动", systemImage: "stop.circle") {
            Task { await model.stopLiveActivity() }
        }
        .buttonStyle(.bordered)
    }
}

struct SettingsInfoBanner: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SettingsStatusMessage: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    private var isError: Bool {
        text.contains("失败") || text.contains("错误") || text.contains("不可用")
    }

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
            .font(.footnote)
            .foregroundStyle(isError ? Color.orange : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .settingsCardBackground()
    }
}

extension View {
    func settingsCardBackground() -> some View {
        background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.16))
            }
    }
}
