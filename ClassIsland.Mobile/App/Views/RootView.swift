import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("课表", systemImage: "calendar.day.timeline.leading")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "slider.horizontal.3")
                }
        }
    }
}
