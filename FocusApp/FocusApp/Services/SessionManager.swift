import FamilyControls
import Foundation
import Observation

/// Owns the active focus session: start, countdown, Hard Mode enforcement,
/// persistence across force-quits, notifications and the Live Activity.
@Observable @MainActor
final class SessionManager {
    private(set) var active: FocusSession?
    private(set) var justCompleted: FocusSession?
    var isLockPresented = false

    @ObservationIgnored private let store = SharedStore.shared
    @ObservationIgnored private let screenTime: ScreenTimeService
    @ObservationIgnored private let liveActivity = LiveActivityService()
    @ObservationIgnored private var ticker: Timer?

    init(screenTime: ScreenTimeService) {
        self.screenTime = screenTime
        restore()
    }

    /// Hard Mode sessions can never be stopped before the timer reaches zero.
    var canStop: Bool {
        guard let active else { return false }
        return !active.hardMode || active.isExpired()
    }

    // MARK: Lifecycle

    func start(endDate: Date,
               hardMode: Bool,
               strictLock: Bool,
               selection: FamilyActivitySelection,
               scheduleID: UUID? = nil,
               occurrenceKey: String? = nil) {
        guard active == nil, endDate > Date().addingTimeInterval(5) else { return }

        let usesScreenTime = screenTime.isAuthorized && !selection.isEmptySelection
        let session = FocusSession(
            startDate: Date(),
            endDate: endDate,
            hardMode: hardMode,
            // Without Screen Time, the full-screen lock is the blocking mechanism.
            strictLock: strictLock || !screenTime.isAuthorized,
            usesScreenTime: usesScreenTime,
            scheduleID: scheduleID,
            occurrenceKey: occurrenceKey
        )

        // Persist first so a crash / force-quit right after start can't escape Hard Mode.
        store.session = session
        active = session
        justCompleted = nil

        if usesScreenTime { screenTime.startSession(session, selection: selection) }
        NotificationService.scheduleCompletion(for: session)
        liveActivity.start(session, quote: store.currentQuote().text, theme: store.theme)
        isLockPresented = session.strictLock
        startTicker()
    }

    func stop() {
        guard let active, canStop else { return }
        finish(active, completed: active.isExpired())
    }

    func presentLock() {
        if active?.strictLock == true { isLockPresented = true }
    }

    func acknowledgeCompletion() { justCompleted = nil }

    // MARK: Scene phase

    func didEnterBackground() {
        guard let active, active.strictLock, !active.isExpired() else { return }
        NotificationService.scheduleLeaveNudges(for: active, quote: store.currentQuote().text)
    }

    func didBecomeActive() {
        NotificationService.cancelLeaveNudges()
        syncFromStore()
    }

    // MARK: Private

    private func syncFromStore() {
        guard let active else {
            restore()
            return
        }
        // The shield's "End focus" button may have ended a soft session while we were away.
        if store.session == nil && !active.hardMode {
            finish(active, completed: false, announce: false)
        } else {
            tick()
        }
    }

    private func restore() {
        guard let saved = store.session else { return }
        if saved.isExpired() {
            finish(saved, completed: true)
        } else {
            active = saved
            isLockPresented = saved.strictLock
            liveActivity.resume(saved, quote: store.currentQuote().text, theme: store.theme)
            startTicker()
        }
    }

    private func tick() {
        if let active, active.isExpired() { finish(active, completed: true) }
    }

    private func finish(_ session: FocusSession, completed: Bool, announce: Bool = true) {
        ticker?.invalidate()
        ticker = nil

        if session.usesScreenTime { screenTime.endSession() }
        if let key = session.occurrenceKey { store.markDismissed(key) }
        store.session = nil

        active = nil
        isLockPresented = false
        if !completed { NotificationService.cancelCompletion() }
        NotificationService.cancelLeaveNudges()
        liveActivity.end()

        if completed && announce { justCompleted = session }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
}
