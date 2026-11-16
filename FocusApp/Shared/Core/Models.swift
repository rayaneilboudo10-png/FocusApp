import Foundation

// MARK: - Weekday

enum Weekday: Int, CaseIterable, Codable, Identifiable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// Monday-first ordering for display.
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]

    var initial: String { Calendar.current.veryShortWeekdaySymbols[rawValue - 1] }
    var shortName: String { Calendar.current.shortWeekdaySymbols[rawValue - 1] }

    static func of(_ date: Date, calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Time of day

struct TimeOfDay: Codable, Hashable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    var totalMinutes: Int { hour * 60 + minute }
    var dateComponents: DateComponents { DateComponents(hour: hour, minute: minute) }

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    var formatted: String { Self.formatter.string(from: date(on: Date())) }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Time limit

enum TimeLimit: Int, Codable, CaseIterable, Identifiable {
    case off = 0, fifteen = 15, thirty = 30, hour = 60, twoHours = 120

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .fifteen: return "15m"
        case .thirty: return "30m"
        case .hour: return "1h"
        case .twoHours: return "2h"
        }
    }

    var threshold: DateComponents { DateComponents(hour: rawValue / 60, minute: rawValue % 60) }
}

// MARK: - Schedule

struct FocusSchedule: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var start: TimeOfDay
    var end: TimeOfDay
    var days: Set<Weekday>
    var isEnabled: Bool = true
    var hardMode: Bool = false
    /// `.off` = block as soon as the schedule starts. Otherwise the apps are allowed
    /// for this much usage inside the window, then blocked.
    var timeLimit: TimeLimit = .off
    /// JSON-encoded `FamilyActivitySelection` (kept as Data so Core has no FamilyControls dependency).
    var selectionData: Data? = nil

    var spansMidnight: Bool { end.totalMinutes <= start.totalMinutes }

    var durationMinutes: Int {
        let d = end.totalMinutes - start.totalMinutes
        return d <= 0 ? d + 24 * 60 : d
    }

    /// The window containing `date`, if this schedule is active at that moment.
    func activeWindow(at date: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard isEnabled, !days.isEmpty else { return nil }
        let today = calendar.startOfDay(for: date)
        // Check today's window and yesterday's (for windows that cross midnight).
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  days.contains(Weekday.of(day, calendar: calendar)) else { continue }
            let s = start.date(on: day, calendar: calendar)
            guard let e = calendar.date(byAdding: .minute, value: durationMinutes, to: s) else { continue }
            if date >= s && date < e { return s...e }
        }
        return nil
    }

    func isActive(at date: Date = Date()) -> Bool { activeWindow(at: date) != nil }

    var timeLabel: String { "\(start.formatted) – \(end.formatted)" }

    var dayLabel: String {
        if days.count == 7 { return "Every day" }
        if days == Weekday.workdays { return "Mon – Fri" }
        if days == Weekday.weekend { return "Weekends" }
        return Weekday.displayOrder.filter(days.contains).map(\.shortName).joined(separator: " ")
    }

    static var presets: [FocusSchedule] {
        [
            FocusSchedule(name: "After School / Work",
                          start: .init(hour: 16, minute: 0), end: .init(hour: 19, minute: 0),
                          days: Weekday.workdays),
            FocusSchedule(name: "Deep Work",
                          start: .init(hour: 9, minute: 0), end: .init(hour: 12, minute: 0),
                          days: Weekday.workdays),
            FocusSchedule(name: "Wind Down",
                          start: .init(hour: 22, minute: 0), end: .init(hour: 7, minute: 0),
                          days: Set(Weekday.allCases)),
        ]
    }
}

// MARK: - Focus session

struct FocusSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
    var hardMode: Bool
    var strictLock: Bool
    /// True when real Screen Time shields were applied for this session.
    var usesScreenTime: Bool
    var scheduleID: UUID? = nil
    /// Identifies a schedule occurrence so ending it early doesn't immediately restart it.
    var occurrenceKey: String? = nil

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    func remaining(at now: Date = Date()) -> TimeInterval { max(0, endDate.timeIntervalSince(now)) }
    func isExpired(at now: Date = Date()) -> Bool { now >= endDate }

    func progress(at now: Date = Date()) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startDate) / duration))
    }
}

// MARK: - Daily limit

struct DailyLimitConfig: Codable, Equatable {
    var limit: TimeLimit = .off
    var selectionData: Data? = nil
}

// MARK: - Quotes

enum QuoteMode: String, Codable, CaseIterable {
    case daily, fixed

    var label: String {
        switch self {
        case .daily: return "Rotate daily"
        case .fixed: return "Pinned"
        }
    }
}

struct Quote: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var isCustom: Bool = true

    static let builtIns: [Quote] = [
        "Less noise. More life.",
        "You don't need more time. You need fewer distractions.",
        "Be where your feet are.",
        "Nothing in that feed is more important than this.",
        "Focus is saying no to a thousand small things.",
        "Small hours, fully lived, add up to a life.",
        "Stillness is a skill. Practice it now.",
        "Come back to the one thing.",
        "The urge will pass. The work will remain.",
        "Future you is watching. Make them proud.",
    ].enumerated().map { index, text in
        Quote(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
              text: text, isCustom: false)
    }

    static func resolve(custom: [Quote], mode: QuoteMode, selectedID: UUID?, date: Date = Date()) -> Quote {
        let all = builtIns + custom
        if mode == .fixed, let selectedID, let match = all.first(where: { $0.id == selectedID }) {
            return match
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
