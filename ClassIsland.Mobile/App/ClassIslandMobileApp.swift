import SwiftUI
import UserNotifications

@main
struct ClassIslandMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    init() {
        UNUserNotificationCenter.current().delegate = MobilePluginNotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !model.isReadyForPresentation {
                    ZStack {
                        Color(uiColor: .systemGroupedBackground)
                            .ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                    }
                } else if model.settings.hasCompletedOnboarding {
                    RootView()
                } else {
                    MobileOnboardingView()
                }
            }
                .environmentObject(model)
                .environmentObject(model.pluginManager)
                .tint(model.settings.accentColor)
                .preferredColorScheme(model.settings.appearance.colorScheme)
                .task {
                    await model.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.handleAppActive() }
                    } else if phase == .inactive {
                        Task { await model.refreshCurrentSchedule() }
                    }
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
