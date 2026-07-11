import SwiftUI

enum AppPage: String, CaseIterable, Hashable, Identifiable {
    case schedule
    case profile
    case general
    case clock
    case weather
    case storage
    case appearance
    case components
    case notification
    case plugins
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .schedule: "课表"
        case .profile: "档案编辑"
        case .general: "基本"
        case .clock: "时钟"
        case .weather: "天气"
        case .storage: "存储"
        case .appearance: "外观"
        case .components: "提醒组件"
        case .notification: "提醒"
        case .plugins: "插件"
        case .about: "关于 ClassIsland"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule: "calendar.day.timeline.leading"
        case .profile: "doc.text"
        case .general: "gearshape"
        case .clock: "clock"
        case .weather: "cloud.sun"
        case .storage: "internaldrive"
        case .appearance: "paintbrush"
        case .components: "square.grid.2x2"
        case .notification: "bell"
        case .plugins: "puzzlepiece.extension"
        case .about: "info.circle"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .schedule: "calendar.day.timeline.leading"
        case .profile: "doc.text.fill"
        case .general: "gearshape.fill"
        case .clock: "clock.fill"
        case .weather: "cloud.sun.fill"
        case .storage: "internaldrive.fill"
        case .appearance: "paintbrush.fill"
        case .components: "square.grid.2x2.fill"
        case .notification: "bell.fill"
        case .plugins: "puzzlepiece.extension.fill"
        case .about: "info.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var pluginManager: MobilePluginManager
    @State private var selectedPage: AppPage? = .schedule
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SettingsSidebar(selectedPage: $selectedPage)
                .navigationSplitViewColumnWidth(min: 238, ideal: 283, max: 320)
        } detail: {
            if let selectedPage {
                destination(for: selectedPage)
                    .id(selectedPage)
            } else {
                ContentUnavailableView("请选择页面", systemImage: "sidebar.left")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: pluginManager.pendingInstall?.id) { _, pendingID in
            guard pendingID != nil else { return }
            selectedPage = .plugins
        }
        .onChange(of: pluginManager.isImporting) { _, isImporting in
            guard isImporting else { return }
            selectedPage = .plugins
        }
        .sheet(item: $pluginManager.pendingInstall) { pending in
            PluginInstallReviewView(pending: pending)
                .environmentObject(pluginManager)
        }
    }

    @ViewBuilder
    private func destination(for page: AppPage) -> some View {
        switch page {
        case .schedule:
            ScheduleView()
        case .profile:
            ProfileEditorView()
        case .components:
            LiveActivityComponentsEditorView()
        case .plugins:
            PluginsSettingsView()
        case .general, .clock, .weather, .storage, .appearance, .notification, .about:
            SettingsView(page: page)
        }
    }
}

private struct SettingsSidebar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedPage: AppPage?

    var body: some View {
        List(selection: $selectedPage) {
            Section {
                brandHeader
            }
            .listRowBackground(Color.clear)

            Section {
                pageLink(.schedule)
                pageLink(.profile)
            }

            Section("通用") {
                pageLink(.general)
                pageLink(.clock)
                pageLink(.weather)
                pageLink(.storage)
            }

            Section("主界面") {
                pageLink(.appearance)
                pageLink(.components)
            }

            Section {
                pageLink(.notification)
            }

            Section("扩展") {
                pageLink(.plugins)
            }

            Section {
                pageLink(.about)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("应用设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("刷新课表", systemImage: "arrow.clockwise") {
                        Task { await model.refreshCurrentSchedule() }
                    }

                    Link(
                        "ClassIsland 项目",
                        destination: URL(string: "https://github.com/ClassIsland/ClassIsland")!
                    )
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更多")
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image("ClassIslandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClassIsland")
                    .font(.headline)
                Text("应用设置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func pageLink(_ page: AppPage) -> some View {
        NavigationLink(value: page) {
            Label {
                Text(page.title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: selectedPage == page ? page.selectedSystemImage : page.systemImage)
                    .frame(width: 22)
            }
        }
        .tag(page)
    }
}
