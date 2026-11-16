import FamilyControls
import Foundation
import Observation
import SwiftUI

/// App-wide state. Every mutation is persisted to the shared App Group so the
/// extensions (shield, monitor) always see the same schedules, theme and quotes.
@Observable @MainActor
final class AppModel {
    let screenTime: ScreenTimeService
    let sessions: SessionManager

    @ObservationIgnored private let store = SharedStore.shared
    @ObservationIgnored private var scheduleTimer: Timer?

    // MARK: Persisted state

    var schedules: [FocusSchedule] {
        didSet {
            store.schedules = schedules
            NotificationService.syncScheduleReminders(schedules, screenTimeActive: screenTime.isAuthorized)
        }
    }

    var theme: BlockTheme { didSet { store.theme = theme } }
    var customQuotes: [Quote] { didSet { store.customQuotes = customQuotes } }
    var quoteMode: QuoteMode { didSet { store.quoteMode = quoteMode } }
    var selectedQuoteID: UUID? { didSet { store.selectedQuoteID = selectedQuoteID } }

    var focusMinutes: Int { didSet { store.focusMinutes = focusMinutes } }
    var hardModeEnabled: Bool { didSet { store.hardModeEnabled = hardModeEnabled } }
    var strictLockEnabled: Bool { didSet { store.strictLockEnabled = strictLockEnabled } }
    var breachPenalty: BreachPenalty { didSet { store.breachPenalty = breachPenalty } }

    var focusSelection: FamilyActivitySelection {
        didSet { store.focusSelectionData = ShieldController.encode(focusSelection) }
    }

    var dailyLimit: DailyLimitConfig {
        didSet {
            guard dailyLimit != oldValue else { return }
            store.dailyLimit = dailyLimit
            screenTime.syncDailyLimit(dailyLimit)
        }
    }

    var dailyLimitSelection: FamilyActivitySelection {
        get { ShieldController.decode(dailyLimit.selectionData) ?? FamilyActivitySelection() }
        set { dailyLimit.selectionData = ShieldController.encode(newValue) }
    }

    // MARK: Init

    init() {
        let shared = SharedStore.shared
        let screenTime = ScreenTimeService()
        self.screenTime = screenTime
        self.sessions = SessionManager(screenTime: screenTime)

        schedules = shared.schedules
        theme = shared.theme
        customQuotes = shared.customQuotes
        quoteMode = shared.quoteMode
        selectedQuoteID = shared.selectedQuoteID
        focusMinutes = shared.focusMinutes
        hardModeEnabled = shared.hardModeEnabled
        strictLockEnabled = shared.strictLockEnabled
        breachPenalty = shared.breachPenalty
        focusSelection = ShieldController.decode(shared.focusSelectionData) ?? FamilyActivitySelection()
        dailyLimit = shared.dailyLimit

        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateSchedules() }
        }
        evaluateSchedules()
    }

    // MARK: Derived

    var allQuotes: [Quote] { Quote.builtIns + customQuotes }

    var currentQuote: Quote {
        Quote.resolve(custom: customQuotes, mode: quoteMode, selectedID: selectedQuoteID)
    }

    /// Any Hard Mode lock (manual or scheduled) currently engaged.
    var hardLockEnd: Date? { store.hardLockEndDate() }

    var strictLockForced: Bool { !screenTime.isAuthorized }

    // MARK: Screen Time

    func connectScreenTime() async {
        await screenTime.requestAuthorization()
        guard screenTime.isAuthorized else { return }
        screenTime.syncAll(schedules)
        screenTime.syncDailyLimit(dailyLimit)
        NotificationService.syncScheduleReminders(schedules, screenTimeActive: true)
    }

    // MARK: Focus

    func startFocus() {
        Task { await NotificationService.requestAuthorization() }
        sessions.start(
            endDate: Date().addingTimeInterval(TimeInterval(focusMinutes * 60)),
            hardMode: hardModeEnabled,
            strictLock: strictLockEnabled,
            selection: focusSelection
        )
    }

    // MARK: Schedules

    func isLocked(_ schedule: FocusSchedule, at now: Date = Date()) -> Bool {
        schedule.hardMode && schedule.isActive(at: now)
    }

    func save(_ schedule: FocusSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            guard !isLocked(schedules[index]) else { return }
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
        Task { await NotificationService.requestAuthorization() }
        screenTime.sync(schedule)
        evaluateSchedules()
    }

    func delete(_ schedule: FocusSchedule) {
        guard !isLocked(schedule) else { return }
        schedules.removeAll { $0.id == schedule.id }
        screenTime.remove(schedule.id)
    }

    func setEnabled(_ schedule: FocusSchedule, _ enabled: Bool) {
        guard !isLocked(schedule), let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index].isEnabled = enabled
        screenTime.sync(schedules[index])
        if enabled { evaluateSchedules() }
    }

    /// In-app enforcement of schedules: when Screen Time isn't available (or Strict
    /// Focus Lock is on), an active schedule automatically starts a full-screen lock.
    func evaluateSchedules(now: Date = Date()) {
        guard sessions.active == nil, !screenTime.isAuthorized || strictLockEnabled else { return }
        let dismissed = Set(store.dismissedOccurrences)

        for schedule in schedules {
            guard let window = schedule.activeWindow(at: now) else { continue }
            let key = SharedStore.occurrenceKey(schedule, window: window)
            guard !dismissed.contains(key), window.upperBound.timeIntervalSince(now) > 30 else { continue }

            // With Screen Time on, the monitor extension already shields the schedule's apps.
            sessions.start(
                endDate: window.upperBound,
                hardMode: schedule.hardMode,
                strictLock: true,
                selection: FamilyActivitySelection(),
                scheduleID: schedule.id,
                occurrenceKey: key
            )
            return
        }
    }

    // MARK: Quotes

    func selectQuote(_ quote: Quote) {
        selectedQuoteID = quote.id
        quoteMode = .fixed
    }

    func addQuote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let quote = Quote(text: trimmed)
        customQuotes.append(quote)
        selectQuote(quote)
    }

    func updateQuote(_ quote: Quote, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = customQuotes.firstIndex(where: { $0.id == quote.id }) else { return }
        customQuotes[index].text = trimmed
    }

    func deleteQuote(_ quote: Quote) {
        customQuotes.removeAll { $0.id == quote.id }
        if selectedQuoteID == quote.id {
            selectedQuoteID = nil
            quoteMode = .daily
        }
    }

    // MARK: Scene phase

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            screenTime.refresh()
            sessions.didBecomeActive()
            evaluateSchedules()
        case .background:
            sessions.didEnterBackground()
        default:
            break
        }
    }
}
