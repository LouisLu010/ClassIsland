import SwiftUI

@main
struct ClassIslandMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(model.settings.accentColor)
                .preferredColorScheme(model.settings.appearance.colorScheme)
                .task {
                    await model.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await model.refreshCurrentSchedule() }
                }
                .onOpenURL { url in
                    if url.isFileURL {
                        Task { await model.importDocument(url) }
                    } else if url.scheme == "classisland" {
                        Task { await model.refreshCurrentSchedule() }
                    }
                }
        }
        .backgroundTask(.appRefresh(ScheduleRefreshScheduler.taskIdentifier)) {
            await model.handleBackgroundRefresh()
        }
    }
}
