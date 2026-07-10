import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            Form {
                dataSection
                liveActivitySection
                displaySection
                rotationSection
                aboutSection
            }
            .navigationTitle("设置")
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
    }

    private var dataSection: some View {
        Section("课表数据") {
            if let profile = model.profile {
                LabeledContent("当前档案", value: profile.name.isEmpty ? model.profileFileName : profile.name)
                LabeledContent("课表数量", value: "\(profile.classPlans.count)")
                LabeledContent("科目数量", value: "\(profile.subjects.count)")
            } else {
                Text("尚未导入课表")
                    .foregroundStyle(.secondary)
            }

            Button("导入 ClassIsland JSON", systemImage: "square.and.arrow.down") {
                isImporterPresented = true
            }

            Button("载入内置示例", systemImage: "sparkles") {
                Task { await model.loadSampleProfile() }
            }

            if model.profile != nil {
                Button("删除本机课表", systemImage: "trash", role: .destructive) {
                    Task { await model.removeProfile() }
                }
            }

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var liveActivitySection: some View {
        Section {
            Toggle("启用实时活动", isOn: $model.settings.liveActivitiesEnabled)
            Toggle("放学后保留", isOn: $model.settings.keepAfterSchoolActivity)

            LabeledContent("当前状态", value: model.activityStatus)

            Button("立即刷新", systemImage: "arrow.clockwise") {
                Task { await model.refreshCurrentSchedule() }
            }

            Button("停止实时活动", systemImage: "stop.circle") {
                Task { await model.stopLiveActivity() }
            }
        } header: {
            Text("实时活动与灵动岛")
        } footer: {
            Text("iPhone 会在灵动岛和锁屏显示；iPad 会在锁屏显示。应用会在前台同步，并请求系统在课程边界后台刷新。")
        }
    }

    private var displaySection: some View {
        Section("显示") {
            Toggle("显示任课教师", isOn: $model.settings.showTeacher)
            Toggle("上课时只显示当前课程", isOn: $model.settings.showCurrentLessonOnlyOnClass)
            Toggle("灵动岛紧凑区使用科目简称", isOn: $model.settings.useInitialInCompactIsland)

            Picker("外观", selection: $model.settings.appearance) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            if let importedAccentHex = model.settings.importedAccentHex {
                LabeledContent("Windows 强调色") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.settings.accentColor)
                            .frame(width: 14, height: 14)
                        Text(importedAccentHex)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Picker(
                "预设强调色",
                selection: Binding(
                    get: { model.settings.accent },
                    set: { model.setAccent($0) }
                )
            ) {
                ForEach(AccentPreference.allCases) { option in
                    Label {
                        Text(option.title)
                    } icon: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 12, height: 12)
                    }
                    .tag(option)
                }
            }
        }
    }

    private var rotationSection: some View {
        Section {
            DatePicker(
                "轮换起始日",
                selection: $model.settings.singleWeekStartTime,
                displayedComponents: .date
            )

            Stepper("最大轮换周期：\(model.settings.maxRotationCycle) 周", value: $model.settings.maxRotationCycle, in: 2...12)

            ForEach(2...model.settings.maxRotationCycle, id: \.self) { cycle in
                Stepper(
                    "\(cycle) 周轮换偏移：\(model.settings.rotationOffset(for: cycle))",
                    value: Binding(
                        get: { model.settings.rotationOffset(for: cycle) },
                        set: { model.setRotationOffset($0, for: cycle) }
                    ),
                    in: 0...(cycle - 1)
                )
            }
        } header: {
            Text("多周轮换")
        } footer: {
            Text("也可直接导入 Windows 版 Settings.json，应用会自动读取轮换起始日、周期与偏移。")
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: "0.1.0")
            LabeledContent("移动端范围", value: "课表与实时活动")
            Link("ClassIsland 项目", destination: URL(string: "https://github.com/ClassIsland/ClassIsland")!)
        }
    }
}
