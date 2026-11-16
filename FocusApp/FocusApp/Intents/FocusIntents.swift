import AppIntents

/// Shortcuts actions that power "app redirects": an automation runs when a distracting
/// app opens, checks `Is Focus Locked`, and if true runs `Open Focus Lock`.
struct IsFocusLockedIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Focus Locked"
    static var description = IntentDescription(
        "Returns true while a focus session or focus schedule is active. Use it in an If action before Open Focus Lock."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: SharedStore.shared.isFocusLocked)
    }
}

struct OpenFocusLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Focus Lock"
    static var description = IntentDescription("Brings you back to Focus and counts a redirected attempt.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if SharedStore.shared.isFocusLocked { SharedStore.shared.recordRedirect() }
        return .result()
    }
}

struct FocusAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenFocusLockIntent(),
                    phrases: ["Open \(.applicationName) lock"],
                    shortTitle: "Open Focus Lock",
                    systemImageName: "lock.fill")
        AppShortcut(intent: IsFocusLockedIntent(),
                    phrases: ["Is \(.applicationName) locked"],
                    shortTitle: "Is Focus Locked",
                    systemImageName: "questionmark.circle")
    }
}
