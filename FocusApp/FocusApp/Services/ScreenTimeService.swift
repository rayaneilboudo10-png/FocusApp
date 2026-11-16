import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// Wraps every Screen Time API call behind an authorization check.
///
/// Free / personal signing certificates don't carry the `family-controls`
/// entitlement, so authorization fails. In that case `isAuthorized` stays false,
/// every method here becomes a no-op, and the app relies on Strict Focus Lock.
@Observable @MainActor
final class ScreenTimeService {
    enum State: Equatable {
        case unknown
        case authorized
        case denied
        case unavailable(String)
    }

    private(set) var state: State = .unknown
    var isAuthorized: Bool { state == .authorized }

    @ObservationIgnored private let center = DeviceActivityCenter()

    init() { refresh() }

    func refresh() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: state = .authorized
        case .denied: state = .denied
        case .notDetermined:
            if state == .authorized { state = .unknown }
        @unknown default: break
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
            if !isAuthorized { state = .denied }
        } catch {
            state = .unavailable(error.localizedDescription)
        }
    }

    // MARK: Manual sessions

    func startSession(_ session: FocusSession, selection: FamilyActivitySelection) {
        guard isAuthorized else { return }
        ShieldController.shield(selection, store: .focusSession, hardMode: session.hardMode)

        // Monitor the session so the extension lifts the shield on time even if the app
        // is never reopened. DeviceActivity needs >= 15 min intervals, so short sessions
        // get a back-dated start (the end time is what matters).
        let minimum: TimeInterval = 15 * 60 + 30
        var start = Date()
        if session.endDate.timeIntervalSince(start) < minimum {
            start = session.endDate.addingTimeInterval(-minimum)
        }
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: session.endDate),
            repeats: false
        )
        center.stopMonitoring([.focusSession])
        do {
            try center.startMonitoring(.focusSession, during: schedule)
        } catch {
            print("[ScreenTime] session monitoring failed: \(error)")
        }
    }

    func endSession() {
        guard isAuthorized else { return }
        center.stopMonitoring([.focusSession])
        ShieldController.clear(.focusSession)
    }

    // MARK: Schedules

    func sync(_ schedule: FocusSchedule) {
        guard isAuthorized else { return }
        let name = DeviceActivityName.schedule(schedule.id)
        center.stopMonitoring([name])

        guard schedule.isEnabled, !schedule.days.isEmpty else {
            ShieldController.clear(.schedule(schedule.id))
            return
        }

        let selection = ShieldController.decode(schedule.selectionData) ?? FamilyActivitySelection()
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if schedule.timeLimit != .off, !selection.isEmptySelection {
            events[.limitReached] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: schedule.timeLimit.threshold
            )
        }

        // One daily repeating interval per schedule (keeps us far below the 20-activity
        // cap); the monitor extension checks the weekday when it fires.
        let interval = DeviceActivitySchedule(
            intervalStart: schedule.start.dateComponents,
            intervalEnd: schedule.end.dateComponents,
            repeats: true
        )
        do {
            try center.startMonitoring(name, during: interval, events: events)
        } catch {
            print("[ScreenTime] schedule monitoring failed: \(error)")
        }

        if schedule.isActive() {
            if schedule.timeLimit == .off {
                ShieldController.shield(selection, store: .schedule(schedule.id), hardMode: schedule.hardMode)
            }
        } else {
            ShieldController.clear(.schedule(schedule.id))
        }
    }

    func syncAll(_ schedules: [FocusSchedule]) {
        guard isAuthorized else { return }
        let wanted = Set(schedules.map(\.id))
        for activity in center.activities {
            if let id = activity.scheduleID, !wanted.contains(id) { remove(id) }
        }
        schedules.forEach(sync)
    }

    func remove(_ scheduleID: UUID) {
        guard isAuthorized else { return }
        center.stopMonitoring([.schedule(scheduleID)])
        ShieldController.clear(.schedule(scheduleID))
    }

    // MARK: Daily limits

    func syncDailyLimit(_ config: DailyLimitConfig) {
        guard isAuthorized else { return }
        center.stopMonitoring([.dailyLimit])
        ShieldController.clear(.dailyLimit)

        guard config.limit != .off,
              let selection = ShieldController.decode(config.selectionData),
              !selection.isEmptySelection else { return }

        let day = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: config.limit.threshold
        )
        do {
            try center.startMonitoring(.dailyLimit, during: day, events: [.limitReached: event])
        } catch {
            print("[ScreenTime] daily limit monitoring failed: \(error)")
        }
    }
}
