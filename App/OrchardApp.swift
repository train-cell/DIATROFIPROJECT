import SwiftUI

@main
struct OrchardApp: App {
    @StateObject private var container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                TodayView()
                    .tabItem {
                        Label(String(localized: "tab_today"), systemImage: "apple.logo")
                    }

                LogView()
                    .tabItem {
                        Label(String(localized: "tab_log"), systemImage: "plus.circle")
                    }

                InsightsView()
                    .tabItem {
                        Label(String(localized: "tab_insights"), systemImage: "chart.xyaxis.line")
                    }

                PlanView()
                    .tabItem {
                        Label(String(localized: "tab_plan"), systemImage: "calendar")
                    }

                SettingsView()
                    .tabItem {
                        Label(String(localized: "tab_settings"), systemImage: "gearshape")
                    }
            }
            .tint(OrchardColors.appleRed)
            .fontDesign(.rounded)
            .environmentObject(container)
        }
    }
}
