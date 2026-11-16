import Foundation
import UserNotifications

/// Local notifications: session completion, "come back" nudges when you leave
/// during Strict Focus Lock, and schedule start reminders.
enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }

    private static let completionID = "focus.session.complete"
    private static let nudgePrefix = "focus.session.nudge."
    private static let schedulePrefix = "focus.schedule."
    private static let nudgeOffsets: [TimeInterval] = [2, 60, 300, 900, 1800]

    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: Session

    static func scheduleCompletion(for session: FocusSession) {
        let content = UNMutableNotificationContent()
        content.title = "Focus complete"
        content.body = session.usesScreenTime
            ? "Nice work. Your apps are unblocked."
            : "Nice work. You stayed with it."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.endDate.timeIntervalSinceNow),
                                                        repeats: false)
        center.add(UNNotificationRequest(identifier: completionID, content: content, trigger: trigger))
    }

    static func cancelCompletion() {
        center.removePendingNotificationRequests(withIdentifiers: [completionID])
    }

    static func scheduleLeaveNudges(for session: FocusSession, quote: String) {
        let now = Date()
        for (index, offset) in nudgeOffsets.enumerated() {
            let fireDate = now.addingTimeInterval(offset)
            guard fireDate < session.endDate.addingTimeInterval(-10) else { continue }

            let content = UNMutableNotificationContent()
            let minutesLeft = max(1, Int(session.endDate.timeIntervalSince(fireDate) / 60))
            if index == 0 {
                content.title = "Come back to focus"
                content.body = quote
            } else {
                content.title = session.hardMode ? "Hard Mode is still on" : "Still focusing?"
                content.body = "\(minutesLeft) min left. Return to your session."
            }
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: offset, repeats: false)
            center.add(UNNotificationRequest(identifier: nudgePrefix + "\(index)", content: content, trigger: trigger))
        }
    }

    static func cancelLeaveNudges() {
        let ids = nudgeOffsets.indices.map { nudgePrefix + "\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: Schedules

    static func syncScheduleReminders(_ schedules: [FocusSchedule], screenTimeActive: Bool) {
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(schedulePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)

            for schedule in schedules where schedule.isEnabled {
                for day in schedule.days {
                    let content = UNMutableNotificationContent()
                    content.title = "\(schedule.name) has started"
                    content.body = screenTimeActive
                        ? "Your apps are blocked until \(schedule.end.formatted)."
                        : "Open Focus to lock in until \(schedule.end.formatted)."
                    content.sound = .default

                    var components = schedule.start.dateComponents
                    components.weekday = day.rawValue
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let id = "\(schedulePrefix)\(schedule.id.uuidString).\(day.rawValue)"
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}
