import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

private enum MobileOnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case license
    case general
    case appearance
    case reminders
    case finish

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "欢迎"
        case .license: "许可条款"
        case .general: "基本设置"
        case .appearance: "颜色主题"
        case .reminders: "提醒"
        case .finish: "完成"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "hand.wave.fill"
        case .license: "doc.text.fill"
        case .general: "gearshape.fill"
        case .appearance: "paintpalette.fill"
        case .reminders: "bell.badge.fill"
        case .finish: "checkmark.circle.fill"
        }
    }
}

struct MobileOnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var step = MobileOnboardingStep.welcome
    @State private var hasAcceptedLicense = false
    @State private var hasAcceptedPrivacy = false
    @State private var isImporterPresented = false

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                pageContent
                    .id(step)
                    .frame(maxWidth: 680)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: 520, alignment: .center)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
            .scrollDismissesKeyboard(.interactively)

            navigationBar
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image("ClassIslandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text("ClassIsland")
                    .font(.headline)
                Spacer()
                Text("\(step.rawValue + 1) / \(MobileOnboardingStep.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: Double(step.rawValue + 1),
                total: Double(MobileOnboardingStep.allCases.count)
            )
            .tint(model.settings.accentColor)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch step {
        case .welcome:
            welcomePage
        case .license:
            licensePage
        case .general:
            generalPage
        case .appearance:
            appearancePage
        case .reminders:
            remindersPage
        case .finish:
            finishPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Image("ClassIslandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)

            Text("ClassIsland")
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text("欢迎使用 ClassIsland。接下来将完成许可确认、基本外观与课程提醒设置。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(appVersion)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var licensePage: some View {
        OnboardingPageHeader(
            title: "同意许可条款",
            subtitle: "要继续使用 ClassIsland，请阅读并同意开源许可与隐私政策。",
            systemImage: MobileOnboardingStep.license.systemImage
        ) {
            VStack(spacing: 12) {
                OnboardingAgreementRow(
                    title: "ClassIsland 开源许可",
                    detail: "查看项目的开源许可与使用条件。",
                    isAccepted: $hasAcceptedLicense,
                    url: URL(string: "https://github.com/ClassIsland/ClassIsland/blob/master/LICENSE.txt")!
                )

                OnboardingAgreementRow(
                    title: "ClassIsland 隐私政策",
                    detail: "了解应用处理本地数据与诊断信息的方式。",
                    isAccepted: $hasAcceptedPrivacy,
                    url: URL(string: "https://github.com/ClassIsland/ClassIsland/blob/master/doc/Privacy.md")!
                )
            }
        }
    }

    private var generalPage: some View {
        OnboardingPageHeader(
            title: "基本设置",
            subtitle: "配置学期起点与课表显示方式。",
            systemImage: MobileOnboardingStep.general.systemImage
        ) {
            VStack(spacing: 12) {
                OnboardingSettingRow(
                    systemImage: "calendar.badge.clock",
                    title: "学期开始时间",
                    detail: "用于计算多周轮换课表。"
                ) {
                    DatePicker(
                        "学期开始时间",
                        selection: $model.settings.singleWeekStartTime,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                OnboardingSettingRow(
                    systemImage: "person.text.rectangle",
                    title: "显示任课教师",
                    detail: "在课表和实时活动中显示教师姓名。"
                ) {
                    Toggle("显示任课教师", isOn: $model.settings.showTeacher)
                        .labelsHidden()
                }

                OnboardingSettingRow(
                    systemImage: "rectangle.compress.vertical",
                    title: "上课时只显示当前课程",
                    detail: "进入上课状态后简化课表列表。"
                ) {
                    Toggle(
                        "上课时只显示当前课程",
                        isOn: $model.settings.showCurrentLessonOnlyOnClass
                    )
                    .labelsHidden()
                }
            }
        }
    }

    private var appearancePage: some View {
        OnboardingPageHeader(
            title: "颜色主题",
            subtitle: "设置 ClassIsland 的界面外观。",
            systemImage: MobileOnboardingStep.appearance.systemImage
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("界面模式", selection: $model.settings.appearance) {
                    ForEach(AppearancePreference.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text("强调色")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(AccentPreference.allCases) { accent in
                        OnboardingAccentButton(
                            accent: accent,
                            isSelected: model.settings.importedAccentHex == nil
                                && model.settings.accent == accent
                        ) {
                            model.setAccent(accent)
                        }
                    }
                }
            }
        }
    }

    private var remindersPage: some View {
        OnboardingPageHeader(
            title: "课程提醒",
            subtitle: "选择适合当前设备的课程提醒方式。不可用的选项会自动置灰。",
            systemImage: MobileOnboardingStep.reminders.systemImage
        ) {
            VStack(spacing: 12) {
                ForEach(ReminderSurface.allCases) { surface in
                    OnboardingSettingRow(
                        systemImage: reminderSystemImage(surface),
                        title: surface.title,
                        detail: reminderDescription(surface)
                    ) {
                        Toggle(surface.title, isOn: reminderBinding(surface))
                            .labelsHidden()
                    }
                    .disabled(!model.reminderCapabilities.supports(surface))
                    .opacity(model.reminderCapabilities.supports(surface) ? 1 : 0.5)
                }

                if model.notificationAuthorizationStatus == .denied {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Label("在系统设置中允许通知", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Label(
                    "灵动岛与锁屏实时活动由同一个 ActivityKit 活动提供；系统通知可用于不支持这些界面的设备。",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
        .task {
            await model.requestNotificationAuthorizationForOnboarding()
        }
    }

    private var finishPage: some View {
        OnboardingPageHeader(
            title: "准备完成",
            subtitle: "导入课表后即可查看完整课程状态，也可以稍后在“存储”页面完成。",
            systemImage: MobileOnboardingStep.finish.systemImage
        ) {
            VStack(spacing: 14) {
                if let profile = model.profile {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.name.isEmpty ? "课表已就绪" : profile.name)
                                .font(.body.weight(.semibold))
                            Text("已载入 \(profile.classPlans.count) 个课表与 \(profile.subjects.count) 个科目。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("导入 Profile.json", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await model.loadSampleProfile() }
                    } label: {
                        Label("载入内置示例", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("这些设置之后都可以在应用侧栏中修改。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 14) {
            if step == .welcome {
                Color.clear
                    .frame(width: 48, height: 48)
            } else {
                Button {
                    move(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .accessibilityLabel("上一步")
            }

            Spacer()

            if step == .finish {
                Button {
                    model.completeOnboarding()
                } label: {
                    Label("开始使用", systemImage: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 126, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    move(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(!canContinue)
                .accessibilityLabel("下一步")
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var canContinue: Bool {
        step != .license || (hasAcceptedLicense && hasAcceptedPrivacy)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "版本 \($0)" } ?? "ClassIsland Mobile"
    }

    private func move(by offset: Int) {
        let target = min(
            max(step.rawValue + offset, 0),
            MobileOnboardingStep.allCases.count - 1
        )
        guard let next = MobileOnboardingStep(rawValue: target) else { return }
        withAnimation(.snappy) {
            step = next
        }
    }

    private func reminderBinding(_ surface: ReminderSurface) -> Binding<Bool> {
        Binding(
            get: { model.settings.reminderSurfaces.contains(surface) },
            set: { model.setReminderSurface(surface, isEnabled: $0) }
        )
    }

    private func reminderSystemImage(_ surface: ReminderSurface) -> String {
        switch surface {
        case .dynamicIsland: "platter.filled.top.iphone"
        case .liveActivity: "iphone"
        case .systemNotification: "bell"
        }
    }

    private func reminderDescription(_ surface: ReminderSurface) -> String {
        switch surface {
        case .dynamicIsland:
            if !model.reminderCapabilities.isDynamicIslandHardwareKnown {
                return "正在检测此设备是否支持灵动岛。"
            }
            return model.reminderCapabilities.supportsDynamicIslandHardware
                ? "在灵动岛中显示课程和倒计时。"
                : "此设备不支持灵动岛。"
        case .liveActivity:
            return model.reminderCapabilities.supportsLiveActivities
                ? "在锁屏显示持续更新的课程状态。"
                : "此设备或系统设置不支持实时活动。"
        case .systemNotification:
            return "在上下课边界发送系统通知。"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task { await model.importDocument(url) }
    }
}

private struct OnboardingPageHeader<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.title.weight(.semibold))
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingSettingRow<Accessory: View>: View {
    let systemImage: String
    let title: String
    let detail: String
    let accessory: Accessory

    init(
        systemImage: String,
        title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                label
                Spacer(minLength: 12)
                accessory
            }
            VStack(alignment: .leading, spacing: 12) {
                label
                accessory
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.14))
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingAgreementRow: View {
    let title: String
    let detail: String
    @Binding var isAccepted: Bool
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("查看\(title)")
            }

            Toggle("我已阅读并同意", isOn: $isAccepted)
                .font(.subheadline)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.14))
        }
    }
}

private struct OnboardingAccentButton: View {
    let accent: AccentPreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accent.color)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                    }
                Text(accent.title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accent.color : Color.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? accent.color : Color(uiColor: .separator).opacity(0.14))
            }
        }
        .buttonStyle(.plain)
    }
}
