import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// MARK: - Names shared by the app and extensions

extension ManagedSettingsStore.Name {
    static let focusSession = ManagedSettingsStore.Name(rawValue: "focus.session")
    static let dailyLimit = ManagedSettingsStore.Name(rawValue: "focus.dailyLimit")
    static func schedule(_ id: UUID) -> ManagedSettingsStore.Name {
        ManagedSettingsStore.Name(rawValue: "focus.schedule.\(id.uuidString)")
    }
}

extension DeviceActivityName {
    static let focusSession = DeviceActivityName(rawValue: "focus.session")
    static let dailyLimit = DeviceActivityName(rawValue: "focus.dailyLimit")

    private static let schedulePrefix = "focus.schedule."

    static func schedule(_ id: UUID) -> DeviceActivityName {
        DeviceActivityName(rawValue: schedulePrefix + id.uuidString)
    }

    var scheduleID: UUID? {
        guard rawValue.hasPrefix(Self.schedulePrefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(Self.schedulePrefix.count)))
    }
}

extension DeviceActivityEvent.Name {
    static let limitReached = DeviceActivityEvent.Name(rawValue: "focus.limitReached")
}

// MARK: - Selection helpers

extension FamilyActivitySelection {
    var isEmptySelection: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    var summary: String {
        var parts: [String] = []
        let apps = applicationTokens.count, cats = categoryTokens.count, sites = webDomainTokens.count
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if sites > 0 { parts.append("\(sites) site\(sites == 1 ? "" : "s")") }
        return parts.isEmpty ? "None selected" : parts.joined(separator: " · ")
    }
}

// MARK: - Shield controller

/// Thin wrapper around ManagedSettings. Only call these when FamilyControls is
/// authorized (the app gates this through `ScreenTimeService`).
enum ShieldController {
    static func decode(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    static func shield(_ selection: FamilyActivitySelection, store name: ManagedSettingsStore.Name, hardMode: Bool) {
        let store = ManagedSettingsStore(named: name)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        // Hard Mode: also prevent deleting apps (incl. this one) to escape the lock.
        store.application.denyAppRemoval = hardMode ? true : nil
    }

    static func clear(_ name: ManagedSettingsStore.Name) {
        ManagedSettingsStore(named: name).clearAllSettings()
    }

    /// Called from the shield's secondary button ("End focus") when no Hard Mode lock
    /// is engaged. Lifts every soft block that is currently in effect.
    static func liftSoftBlocks(using shared: SharedStore = .shared, now: Date = Date()) {
        guard !shared.isHardModeEngaged(at: now) else { return }

        if let session = shared.session, !session.hardMode {
            clear(.focusSession)
            DeviceActivityCenter().stopMonitoring([.focusSession])
            if let key = session.occurrenceKey { shared.markDismissed(key) }
            shared.session = nil
        }

        clear(.dailyLimit)

        for schedule in shared.schedules where !schedule.hardMode {
            if let window = schedule.activeWindow(at: now) {
                clear(.schedule(schedule.id))
                shared.markDismissed(SharedStore.occurrenceKey(schedule, window: window))
            }
        }
    }
}
