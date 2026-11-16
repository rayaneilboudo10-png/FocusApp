import ActivityKit
import Foundation

/// Starts / ends the Lock Screen Live Activity for a focus session.
@MainActor
final class LiveActivityService {
    private var activity: Activity<FocusActivityAttributes>?

    func start(_ session: FocusSession, quote: String, theme: BlockTheme) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let attributes = FocusActivityAttributes(
            title: session.scheduleID == nil ? "Focusing" : "Scheduled focus",
            themeRaw: theme.rawValue
        )
        let state = FocusActivityAttributes.ContentState(
            startDate: session.startDate,
            endDate: session.endDate,
            hardMode: session.hardMode,
            quote: quote
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: session.endDate),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] request failed: \(error)")
        }
    }

    /// Re-attach to an activity that survived an app relaunch, or start a new one.
    func resume(_ session: FocusSession, quote: String, theme: BlockTheme) {
        if let existing = Activity<FocusActivityAttributes>.activities.first,
           existing.content.state.endDate == session.endDate {
            activity = existing
        } else {
            start(session, quote: quote, theme: theme)
        }
    }

    func end() {
        let running = Activity<FocusActivityAttributes>.activities
        activity = nil
        guard !running.isEmpty else { return }
        Task {
            for item in running {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
