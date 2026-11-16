import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Runs in the background (even when the app is closed) at schedule boundaries and
/// when usage thresholds are reached. Applies and removes shields accordingly.
final class FocusActivityMonitorExtension: DeviceActivityMonitor {
    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity == .focusSession {
            guard let session = store.session, session.usesScreenTime, !session.isExpired(),
                  let selection = ShieldController.decode(store.focusSelectionData) else { return }
            ShieldController.shield(selection, store: .focusSession, hardMode: session.hardMode)

        } else if activity == .dailyLimit {
            // A new day began: reset yesterday's limit block.
            ShieldController.clear(.dailyLimit)

        } else if let schedule = schedule(for: activity) {
            // Repeating schedules fire daily; honour the selected weekdays here.
            guard schedule.isEnabled, schedule.days.contains(Weekday.of(Date())) else { return }
            // With a time limit, shielding waits for `eventDidReachThreshold`.
            guard schedule.timeLimit == .off,
                  let selection = ShieldController.decode(schedule.selectionData) else { return }
            ShieldController.shield(selection, store: .schedule(schedule.id), hardMode: schedule.hardMode)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity == .focusSession {
            ShieldController.clear(.focusSession)
            if let session = store.session, session.isExpired() { store.session = nil }
        } else if activity == .dailyLimit {
            ShieldController.clear(.dailyLimit)
        } else if let id = activity.scheduleID {
            ShieldController.clear(.schedule(id))
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == .limitReached else { return }

        if activity == .dailyLimit {
            guard let selection = ShieldController.decode(store.dailyLimit.selectionData) else { return }
            ShieldController.shield(selection, store: .dailyLimit, hardMode: false)

        } else if let schedule = schedule(for: activity) {
            guard schedule.isActive(),
                  let selection = ShieldController.decode(schedule.selectionData) else { return }
            ShieldController.shield(selection, store: .schedule(schedule.id), hardMode: schedule.hardMode)
        }
    }

    private func schedule(for activity: DeviceActivityName) -> FocusSchedule? {
        guard let id = activity.scheduleID else { return nil }
        return store.schedules.first { $0.id == id }
    }
}
