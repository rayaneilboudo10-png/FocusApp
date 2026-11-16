import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .focus

    enum AppTab: Hashable { case focus, schedules, themes }

    var body: some View {
        @Bindable var sessions = model.sessions

        TabView(selection: $tab) {
            FocusView()
                .tabItem { Label("Focus", systemImage: "circle.circle") }
                .tag(AppTab.focus)

            SchedulesView()
                .tabItem { Label("Schedules", systemImage: "calendar") }
                .tag(AppTab.schedules)

            ThemesView()
                .tabItem { Label("Themes", systemImage: "circle.lefthalf.filled") }
                .tag(AppTab.themes)
        }
        .tint(DS.Palette.text)
        .background(DS.Palette.background.ignoresSafeArea())
        // Strict Focus Lock covers the whole app, tab bar included.
        .fullScreenCover(isPresented: $sessions.isLockPresented) {
            StrictLockView()
                .interactiveDismissDisabled()
        }
    }
}
