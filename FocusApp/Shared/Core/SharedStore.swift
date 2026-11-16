import Foundation

/// Single source of persisted truth, readable by the app and every extension.
///
/// Backed by the App Group's `UserDefaults` suite. When the group container isn't
/// available (common with free / re-signed sideload builds) it falls back to
/// `UserDefaults.standard`, so the app keeps working on its own.
///
/// Hard Mode sessions are additionally mirrored into `UserDefaults.standard` so a
/// lock can't be bypassed by anything that only resets the shared suite.
final class SharedStore {
    static let shared = SharedStore()

    let defaults: UserDefaults
    let isAppGroupShared: Bool
    private let mirror: UserDefaults?

    private enum Key: String {
        case schedules, session, theme, customQuotes, quoteMode, selectedQuoteID
        case focusSelection, dailyLimit, strictLock, hardModeEnabled, focusMinutes
        case dismissedOccurrences
    }

    init() {
        let id = AppGroup.identifier
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil,
           let suite = UserDefaults(suiteName: id) {
            defaults = suite
            isAppGroupShared = true
            mirror = .standard
        } else {
            defaults = .standard
            isAppGroupShared = false
            mirror = nil
        }
    }

    // MARK: Codable helpers

    private func decode<T: Decodable>(_ type: T.Type, _ key: Key, from source: UserDefaults? = nil) -> T? {
        guard let data = (source ?? defaults).data(forKey: key.rawValue) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T?, _ key: Key, to target: UserDefaults? = nil) {
        let target = target ?? defaults
        guard let value, let data = try? JSONEncoder().encode(value) else {
            target.removeObject(forKey: key.rawValue)
            return
        }
        target.set(data, forKey: key.rawValue)
    }

    private func bool(_ key: Key, default value: Bool) -> Bool {
        defaults.object(forKey: key.rawValue) as? Bool ?? value
    }

    // MARK: Schedules

    var schedules: [FocusSchedule] {
        get { decode([FocusSchedule].self, .schedules) ?? [] }
        set { encode(newValue, .schedules) }
    }

    // MARK: Active session (Hard Mode persistence)

    var session: FocusSession? {
        get {
            let shared = decode(FocusSession.self, .session)
            let mirrored = mirror.flatMap { decode(FocusSession.self, .session, from: $0) }
            switch (shared, mirrored) {
            case let (a?, b?):
                return a.endDate >= b.endDate ? a : b
            case let (a?, nil):
                return a
            case let (nil, b?):
                // Only trust the mirror for an unexpired Hard Mode lock; non-hard sessions
                // may legitimately be cleared by the shield-action extension.
                return (b.hardMode && !b.isExpired()) ? b : nil
            default:
                return nil
            }
        }
        set {
            encode(newValue, .session)
            if let mirror { encode(newValue, .session, to: mirror) }
        }
    }

    // MARK: Appearance & quotes

    var theme: BlockTheme {
        get { defaults.string(forKey: Key.theme.rawValue).flatMap(BlockTheme.init(rawValue:)) ?? .pureOLED }
        set { defaults.set(newValue.rawValue, forKey: Key.theme.rawValue) }
    }

    var customQuotes: [Quote] {
        get { decode([Quote].self, .customQuotes) ?? [] }
        set { encode(newValue, .customQuotes) }
    }

    var quoteMode: QuoteMode {
        get { defaults.string(forKey: Key.quoteMode.rawValue).flatMap(QuoteMode.init(rawValue:)) ?? .daily }
        set { defaults.set(newValue.rawValue, forKey: Key.quoteMode.rawValue) }
    }

    var selectedQuoteID: UUID? {
        get { defaults.string(forKey: Key.selectedQuoteID.rawValue).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: Key.selectedQuoteID.rawValue) }
    }

    func currentQuote(at date: Date = Date()) -> Quote {
        Quote.resolve(custom: customQuotes, mode: quoteMode, selectedID: selectedQuoteID, date: date)
    }

    // MARK: Blocking configuration

    var focusSelectionData: Data? {
        get { defaults.data(forKey: Key.focusSelection.rawValue) }
        set { defaults.set(newValue, forKey: Key.focusSelection.rawValue) }
    }

    var dailyLimit: DailyLimitConfig {
        get { decode(DailyLimitConfig.self, .dailyLimit) ?? DailyLimitConfig() }
        set { encode(newValue, .dailyLimit) }
    }

    var strictLockEnabled: Bool {
        get { bool(.strictLock, default: false) }
        set { defaults.set(newValue, forKey: Key.strictLock.rawValue) }
    }

    var hardModeEnabled: Bool {
        get { bool(.hardModeEnabled, default: false) }
        set { defaults.set(newValue, forKey: Key.hardModeEnabled.rawValue) }
    }

    var focusMinutes: Int {
        get { let v = defaults.integer(forKey: Key.focusMinutes.rawValue); return v > 0 ? v : 25 }
        set { defaults.set(newValue, forKey: Key.focusMinutes.rawValue) }
    }

    // MARK: Schedule occurrences ended early

    var dismissedOccurrences: [String] {
        get { defaults.stringArray(forKey: Key.dismissedOccurrences.rawValue) ?? [] }
        set { defaults.set(Array(newValue.suffix(60)), forKey: Key.dismissedOccurrences.rawValue) }
    }

    func markDismissed(_ key: String) {
        guard !dismissedOccurrences.contains(key) else { return }
        dismissedOccurrences.append(key)
    }

    static func occurrenceKey(_ schedule: FocusSchedule, window: ClosedRange<Date>) -> String {
        "\(schedule.id.uuidString)@\(Int(window.lowerBound.timeIntervalSince1970))"
    }

    // MARK: Hard Mode

    /// The latest moment any Hard Mode lock (manual session or active schedule) ends.
    func hardLockEndDate(at now: Date = Date()) -> Date? {
        var ends: [Date] = []
        if let s = session, s.hardMode, s.endDate > now { ends.append(s.endDate) }
        for schedule in schedules where schedule.hardMode {
            if let window = schedule.activeWindow(at: now) { ends.append(window.upperBound) }
        }
        return ends.max()
    }

    func isHardModeEngaged(at now: Date = Date()) -> Bool { hardLockEndDate(at: now) != nil }
}
