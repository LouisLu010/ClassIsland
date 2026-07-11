import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let classIslandPlugin = UTType(
        exportedAs: "cn.classisland.plugin-package",
        conformingTo: .zip
    )
}

struct PluginsSettingsView: View {
    @EnvironmentObject private var pluginManager: MobilePluginManager
    @State private var isImporterPresented = false

    var body: some View {
        SettingsPageLayout(title: "插件") {
            SettingsSectionTitle("本地插件", systemImage: "puzzlepiece.extension")

            Button {
                isImporterPresented = true
            } label: {
                HStack(spacing: 14) {
                    PluginIcon(systemImage: "square.and.arrow.down")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("安装本地插件")
                            .font(.body.weight(.medium))
                        Text("选择包含声明式移动入口的 .cipx 插件包。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if pluginManager.isImporting || pluginManager.isInstalling {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .settingsCardBackground()
            }
            .buttonStyle(.plain)
            .disabled(pluginManager.isImporting || pluginManager.isInstalling)

            SettingsInfoBanner(
                "iOS 只读取插件包内的声明式移动入口，不会加载或执行桌面插件 DLL。"
            )

            SettingsSectionTitle("已安装", systemImage: "shippingbox")

            if pluginManager.plugins.isEmpty {
                SettingsCard(
                    systemImage: "puzzlepiece.extension",
                    title: "尚未安装移动插件",
                    description: "兼容插件会在 manifest.yml 中声明 mobile 入口。"
                ) {
                    EmptyView()
                }
            } else {
                ForEach(pluginManager.plugins) { plugin in
                    PluginSummaryCard(plugin: plugin)
                }
            }

            if !pluginManager.statusMessage.isEmpty {
                SettingsStatusMessage(pluginManager.statusMessage)
            }
        }
        .navigationTitle("插件")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.classIslandPlugin, .zip],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await pluginManager.prepareInstallation(from: url) }
        }
    }
}

private struct PluginSummaryCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pluginManager: MobilePluginManager
    let plugin: InstalledMobilePlugin

    private var missingDependency: MobilePluginDependency? {
        pluginManager.missingRequiredDependencies(for: plugin).first
    }

    private var isOperational: Bool {
        pluginManager.isOperational(pluginID: plugin.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                PluginPackageIcon(plugin: plugin)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plugin.manifest.name)
                        .font(.body.weight(.medium))
                    Text("\(plugin.manifest.author.isEmpty ? plugin.id : plugin.manifest.author) · v\(plugin.manifest.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Toggle(
                    "启用 \(plugin.manifest.name)",
                    isOn: Binding(
                        get: { plugin.state.isEnabled },
                        set: {
                            pluginManager.setEnabled($0, pluginID: plugin.id)
                            Task { await model.refreshCurrentSchedule() }
                        }
                    )
                )
                .labelsHidden()
            }
            .padding(14)

            Divider()
                .padding(.leading, 58)

            HStack(spacing: 10) {
                if let missingDependency {
                    Label("缺少 \(missingDependency.id)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else if plugin.state.isEnabled && !isOperational {
                    Label("等待依赖启用", systemImage: "link.badge.plus")
                        .foregroundStyle(.orange)
                } else {
                    Label(
                        isOperational ? "运行中" : "已停用",
                        systemImage: isOperational ? "checkmark.circle" : "pause.circle"
                    )
                    .foregroundStyle(isOperational ? Color.green : Color.secondary)
                }
                Spacer()
                NavigationLink("管理") {
                    MobilePluginDetailView(pluginID: plugin.id)
                }
                .font(.subheadline.weight(.medium))
            }
            .font(.caption)
            .padding(12)
        }
        .settingsCardBackground()
    }
}

struct MobilePluginDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pluginManager: MobilePluginManager
    let pluginID: String

    @State private var isUninstallConfirmationPresented = false

    private var plugin: InstalledMobilePlugin? {
        pluginManager.plugin(id: pluginID)
    }

    var body: some View {
        Group {
            if let plugin {
                SettingsPageLayout(title: plugin.manifest.name) {
                    pluginHeader(plugin)
                    stateSection(plugin)
                    permissionSection(plugin)
                    settingsSection(plugin)
                    metadataSection(plugin)

                    Button(role: .destructive) {
                        isUninstallConfirmationPresented = true
                    } label: {
                        Label("卸载插件", systemImage: "trash")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .settingsCardBackground()
                    }
                    .buttonStyle(.plain)

                    if !pluginManager.statusMessage.isEmpty {
                        SettingsStatusMessage(pluginManager.statusMessage)
                    }
                }
            } else {
                ContentUnavailableView("插件已被移除", systemImage: "puzzlepiece.extension")
            }
        }
        .navigationTitle(plugin?.manifest.name ?? "插件")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task { await model.refreshCurrentSchedule() }
        }
        .confirmationDialog(
            "卸载这个插件？",
            isPresented: $isUninstallConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("卸载", role: .destructive) {
                Task {
                    await pluginManager.uninstall(pluginID: pluginID)
                    await model.refreshCurrentSchedule()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("插件文件会被移除；插件配置会保留，便于以后重新安装。")
        }
    }

    private func pluginHeader(_ plugin: InstalledMobilePlugin) -> some View {
        HStack(alignment: .top, spacing: 14) {
            PluginPackageIcon(plugin: plugin, size: 58)
            VStack(alignment: .leading, spacing: 5) {
                Text(plugin.manifest.name)
                    .font(.title3.weight(.semibold))
                Text(plugin.manifest.description.isEmpty ? "暂无插件说明" : plugin.manifest.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(plugin.manifest.author.isEmpty ? plugin.id : plugin.manifest.author) · v\(plugin.manifest.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .settingsCardBackground()
    }

    @ViewBuilder
    private func stateSection(_ plugin: InstalledMobilePlugin) -> some View {
        SettingsSectionTitle("运行", systemImage: "power")
        SettingsCard(
            systemImage: "power",
            title: "启用插件",
            description: "停用后，组件、事件和实时活动内容都会停止。"
        ) {
            Toggle(
                "启用插件",
                isOn: Binding(
                    get: { plugin.state.isEnabled },
                    set: {
                        pluginManager.setEnabled($0, pluginID: plugin.id)
                        Task { await model.refreshCurrentSchedule() }
                    }
                )
            )
            .labelsHidden()
        }
        if let dependency = pluginManager.missingRequiredDependencies(for: plugin).first {
            SettingsInfoBanner("启用前需要先安装并启用：\(dependency.id)")
        }
    }

    @ViewBuilder
    private func permissionSection(_ plugin: InstalledMobilePlugin) -> some View {
        SettingsSectionTitle("权限", systemImage: "hand.raised")
        SettingsPanel(
            systemImage: "hand.raised",
            title: "宿主能力",
            description: "插件只能使用这里列出并由你允许的能力。"
        ) {
            ForEach(Array(plugin.manifest.mobile.capabilities.enumerated()), id: \.offset) { index, capability in
                if index > 0 { Divider().padding(.leading, 12) }
                SettingsInlineRow(title: capability.title, description: capability.description) {
                    Toggle(
                        capability.title,
                        isOn: Binding(
                            get: { plugin.state.grantedCapabilities.contains(capability) },
                            set: { value in
                                Task {
                                    await pluginManager.setCapability(
                                        capability,
                                        granted: value,
                                        pluginID: plugin.id
                                    )
                                    await model.refreshCurrentSchedule()
                                }
                            }
                        )
                    )
                    .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private func settingsSection(_ plugin: InstalledMobilePlugin) -> some View {
        if !plugin.definition.settings.isEmpty {
            SettingsSectionTitle("插件设置", systemImage: "slider.horizontal.3")
            SettingsPanel(
                systemImage: "slider.horizontal.3",
                title: "\(plugin.manifest.name) 设置",
                description: "这些选项由插件的声明式配置生成。"
            ) {
                ForEach(Array(plugin.definition.settings.enumerated()), id: \.offset) { index, setting in
                    if index > 0 { Divider().padding(.leading, 12) }
                    MobilePluginSettingControl(pluginID: plugin.id, definition: setting)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataSection(_ plugin: InstalledMobilePlugin) -> some View {
        SettingsSectionTitle("包信息", systemImage: "shippingbox")
        SettingsPanel(systemImage: "shippingbox", title: "安装信息") {
            SettingsValueRow(title: "插件 ID", value: plugin.id)
            Divider()
            SettingsValueRow(title: "移动 API", value: "v\(plugin.manifest.mobile.apiVersion)")
            Divider()
            SettingsValueRow(title: "运行时", value: plugin.manifest.mobile.runtime)
            if !plugin.definition.allowedDomains.isEmpty {
                Divider()
                SettingsValueRow(
                    title: "网络域名",
                    value: plugin.definition.allowedDomains.joined(separator: "、")
                )
            }
            Divider()
            SettingsValueRow(
                title: "SHA-256",
                value: String(plugin.installation.packageSHA256.prefix(16)) + "…"
            )
            Divider()
            SettingsValueRow(title: "签名", value: "未签名")
        }
    }
}

private struct MobilePluginSettingControl: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pluginManager: MobilePluginManager
    let pluginID: String
    let definition: MobilePluginSettingDefinition

    var body: some View {
        SettingsInlineRow(title: definition.title, description: definition.description) {
            control
        }
        .task(id: pluginManager.settingValue(pluginID: pluginID, key: definition.key)?.stringValue ?? "") {
            guard definition.type == .text else { return }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            await model.refreshCurrentSchedule()
        }
    }

    @ViewBuilder
    private var control: some View {
        switch definition.type {
        case .toggle:
            Toggle(definition.title, isOn: boolBinding)
                .labelsHidden()
        case .text:
            TextField(definition.placeholder, text: stringBinding)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 120, maxWidth: 260)
        case .number:
            Stepper(
                value: numberBinding,
                in: (definition.minimum ?? -1_000_000)...(definition.maximum ?? 1_000_000),
                step: definition.step ?? 1
            ) {
                Text(numberBinding.wrappedValue.formatted())
                    .monospacedDigit()
                    .frame(minWidth: 64, alignment: .trailing)
            }
            .fixedSize()
        case .choice:
            Picker(definition.title, selection: stringBinding) {
                ForEach(definition.options) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { pluginManager.settingValue(pluginID: pluginID, key: definition.key)?.boolValue ?? false },
            set: {
                pluginManager.setSettingValue(.bool($0), pluginID: pluginID, key: definition.key)
                Task { await model.refreshCurrentSchedule() }
            }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { pluginManager.settingValue(pluginID: pluginID, key: definition.key)?.stringValue ?? "" },
            set: {
                pluginManager.setSettingValue(.string($0), pluginID: pluginID, key: definition.key)
                if definition.type == .choice {
                    Task { await model.refreshCurrentSchedule() }
                }
            }
        )
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: { pluginManager.settingValue(pluginID: pluginID, key: definition.key)?.numberValue ?? 0 },
            set: {
                pluginManager.setSettingValue(.number($0), pluginID: pluginID, key: definition.key)
                Task { await model.refreshCurrentSchedule() }
            }
        )
    }
}

struct PluginInstallReviewView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var pluginManager: MobilePluginManager
    @Environment(\.dismiss) private var dismiss

    let pending: PendingMobilePluginInstall
    @State private var grantedCapabilities: Set<MobilePluginCapability>
    @State private var isInstalling = false

    init(pending: PendingMobilePluginInstall) {
        self.pending = pending
        _grantedCapabilities = State(
            initialValue: pending.initialGrantedCapabilities
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pending.installation.manifest.name)
                            .font(.title3.weight(.semibold))
                        Text(pending.installation.manifest.description.isEmpty
                            ? "暂无插件说明"
                            : pending.installation.manifest.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(pending.installation.manifest.author) · v\(pending.installation.manifest.version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                Section("请求的权限") {
                    ForEach(pending.installation.manifest.mobile.capabilities) { capability in
                        Toggle(isOn: capabilityBinding(capability)) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(capability.title)
                                    Text(capability.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: capability.systemImage)
                            }
                        }
                    }
                }

                if !pending.installation.manifest.dependencies.isEmpty {
                    Section("依赖") {
                        ForEach(pending.installation.manifest.dependencies, id: \.id) { dependency in
                            Label(
                                dependency.id,
                                systemImage: dependency.isRequired ? "link" : "link.badge.plus"
                            )
                        }
                    }
                }

                if !pending.installation.definition.allowedDomains.isEmpty {
                    Section("允许访问的网络域名") {
                        ForEach(pending.installation.definition.allowedDomains, id: \.self) { domain in
                            Label(domain, systemImage: "network")
                        }
                    }
                }

                Section {
                    Label("该插件包未包含可验证的数字签名。请只安装你信任的来源。", systemImage: "exclamationmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                if !pluginManager.statusMessage.isEmpty {
                    Section {
                        Text(pluginManager.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(pending.isUpdate ? "更新插件" : "安装插件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        pluginManager.cancelPendingInstallation(pending)
                        dismiss()
                    }
                    .disabled(isInstalling)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(pending.isUpdate ? "更新" : "安装") {
                        isInstalling = true
                        Task {
                            await pluginManager.installPending(
                                grantedCapabilities: grantedCapabilities
                            )
                            await model.refreshCurrentSchedule()
                            isInstalling = false
                            if pluginManager.pendingInstall == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isInstalling)
                }
            }
            .overlay {
                if isInstalling {
                    ProgressView(pending.isUpdate ? "正在更新…" : "正在安装…")
                        .padding(18)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
        }
        .interactiveDismissDisabled(isInstalling)
        .onDisappear {
            pluginManager.cancelPendingInstallation(pending)
        }
    }

    private func capabilityBinding(_ capability: MobilePluginCapability) -> Binding<Bool> {
        Binding(
            get: { grantedCapabilities.contains(capability) },
            set: { granted in
                if granted {
                    grantedCapabilities.insert(capability)
                } else {
                    grantedCapabilities.remove(capability)
                }
            }
        )
    }
}

private struct PluginPackageIcon: View {
    @EnvironmentObject private var pluginManager: MobilePluginManager
    let plugin: InstalledMobilePlugin
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let url = pluginManager.iconURL(for: plugin),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.18))
        }
        .accessibilityHidden(true)
    }
}

private struct PluginIcon: View {
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
