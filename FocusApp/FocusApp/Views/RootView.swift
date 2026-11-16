import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .focus

    enum AppTab: Hashable { case focus, schedules, themes }

    var body: some View {
        let sessions = model.sessions

        // Guarded binding: nothing (gesture, system, stray code) can dismiss the lock
        // while it's mandatory. Only the session ending flips it off.
        let lockBinding = Binding(
            get: { sessions.isLockPresented },
            set: { newValue in
                if newValue || !sessions.isLockMandatory { sessions.isLockPresented = newValue }
            }
        )

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
        // Breach screen for Hard Mode sessions that aren't using the full-screen lock.
        .overlay {
            if let event = sessions.breachEvent, !sessions.isLockPresented {
                BreachView(event: event) { sessions.acknowledgeBreach() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessions.breachEvent)
        // Strict Focus Lock covers the whole app, tab bar included.
        .fullScreenCover(isPresented: lockBinding) {
            StrictLockView()
                .interactiveDismissDisabled()
        }
    }
}
