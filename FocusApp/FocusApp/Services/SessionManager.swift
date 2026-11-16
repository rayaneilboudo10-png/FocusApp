import FamilyControls
import Foundation
import Observation

/// What the "Focus Breached" screen reports after you come back.
struct BreachEvent: Identifiable, Equatable {
    let id = UUID()
    let awayFor: TimeInterval
    let addedMinutes: Int
    let lostStreak: Int
    let streakReset: Bool
}

/// Owns the active focus session: start, countdown, Hard Mode enforcement,
/// escape detection and penalties, persistence across force-quits,
/// notifications and the Live Activity.
@Observable @MainActor
final class SessionManager {
    private(set) var active: FocusSession?
    private(set) var justCompleted: FocusSession?
    private(set) var breachEvent: BreachEvent?
    private(set) var streak: StreakState
    private(set) var counter: DailyCounter
    var isLockPresented = false

    @ObservationIgnored private let store = SharedStore.shared
    @ObservationIgnored private let screenTime: ScreenTimeService
    @ObservationIgnored private let liveActivity = LiveActivityService()
    @ObservationIgnored private let escapeDetector = EscapeDetector()
    @ObservationIgnored private var ticker: Timer?

    init(screenTime: ScreenTimeService) {
        self.screenTime = screenTime
        streak = SharedStore.shared.streak
        counter = SharedStore.shared.dailyCounter
        // A breach recorded before a force-quit is judged on the next launch.
        processPendingBreach()
        restore()
    }

    /// Hard Mode sessions can never be stopped before the timer reaches zero.
    var canStop: Bool {
        guard let active else { return false }
        return !active.hardMode || active.isExpired()
    }

    /// While true, the Strict Focus Lock cover must stay on screen.
    var isLockMandatory: Bool {
        guard let active else { return false }
        return active.strictLock && !active.isExpired()
    }

    var currentStreak: Int { streak.value() }

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
    func acknowledgeBreach() { breachEvent = nil }

    // MARK: Scene phase

    func didEnterBackground() {
        guard let active, !active.isExpired() else { return }

        if active.hardMode {
            // Assume the worst immediately: record the breach and start the alarms.
            store.pendingBreach = BreachRecord(sessionID: active.id, leftAt: Date())
            NotificationService.scheduleBreachAlarms(for: active)

            // Then forgive it if it turns out the phone was simply locked.
            escapeDetector.classifyBackgrounding { [weak self] wasDeviceLock in
                guard wasDeviceLock, let self else { return }
                self.store.pendingBreach = nil
                NotificationService.cancelBreachAlarms()
            }
        } else if active.strictLock {
            NotificationService.scheduleLeaveNudges(for: active, quote: store.currentQuote().text)
        }
    }

    func didBecomeActive() {
        NotificationService.cancelLeaveNudges()
        NotificationService.cancelBreachAlarms()
        processPendingBreach()
        syncFromStore()
        counter = store.dailyCounter
    }

    // MARK: Breach penalty

    private func processPendingBreach(now: Date = Date()) {
        guard let breach = store.pendingBreach else { return }
        store.pendingBreach = nil

        let away = now.timeIntervalSince(breach.leftAt)
        guard away >= 2 else { return }

        let penalty = store.breachPenalty
        var addedMinutes = 0
        if penalty.addsTime,
           var session = store.session,
           session.id == breach.sessionID,
           !session.isExpired(at: now) {
            session.endDate = session.endDate.addingTimeInterval(TimeInterval(BreachPenalty.minutes * 60))
            store.session = session
            addedMinutes = BreachPenalty.minutes
            if active?.id == session.id { applyExtension(to: session) }
        }

        var lostStreak = 0
        if penalty.resetsStreak {
            lostStreak = streak.value(at: now)
            streak.reset()
            store.streak = streak
        }

        store.recordBreach()
        counter = store.dailyCounter
        breachEvent = BreachEvent(awayFor: away,
                                  addedMinutes: addedMinutes,
                                  lostStreak: lostStreak,
                                  streakReset: penalty.resetsStreak)
    }

    private func applyExtension(to session: FocusSession) {
        active = session
        NotificationService.scheduleCompletion(for: session)
        liveActivity.start(session, quote: store.currentQuote().text, theme: store.theme)
        if session.usesScreenTime, let selection = ShieldController.decode(store.focusSelectionData) {
            screenTime.startSession(session, selection: selection)
        }
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
            if isLockMandatory { isLockPresented = true }
        }
    }

    private func restore() {
        guard let saved = store.session else { return }
        if saved.isExpired() {
            finish(saved, completed: true)
        } else {
            active = saved
            isLockPresented = saved.strictLock
            NotificationService.scheduleCompletion(for: saved)
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
        store.pendingBreach = nil

        active = nil
        isLockPresented = false
        if !completed { NotificationService.cancelCompletion() }
        NotificationService.cancelLeaveNudges()
        NotificationService.cancelBreachAlarms()
        liveActivity.end()

        if completed {
            streak.recordCompletion()
            store.streak = streak
            if announce { justCompleted = session }
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
}
