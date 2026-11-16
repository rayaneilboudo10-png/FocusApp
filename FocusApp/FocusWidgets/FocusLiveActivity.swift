import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FocusWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusLiveActivityWidget()
    }
}

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(context: context)
                .activityBackgroundTint(context.attributes.theme.palette.background)
                .activitySystemActionForegroundColor(context.attributes.theme.palette.text)
        } dynamicIsland: { context in
            let palette = context.attributes.theme.palette
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.hardMode ? "lock.fill" : "moon.fill")
                        .foregroundStyle(palette.accent)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: context.state)
                        .font(.system(size: 22, weight: .light, design: .rounded).monospacedDigit())
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.quote)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: context.state.hardMode ? "lock.fill" : "moon.fill")
                    .foregroundStyle(palette.accent)
            } compactTrailing: {
                CountdownText(state: context.state)
                    .monospacedDigit()
                    .frame(width: 52)
            } minimal: {
                Image(systemName: "moon.fill").foregroundStyle(palette.accent)
            }
        }
    }
}

private struct CountdownText: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        let lower = min(state.startDate, state.endDate)
        Text(timerInterval: lower...state.endDate, countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}

private struct FocusLockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        let palette = context.attributes.theme.palette
        let state = context.state

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: state.hardMode ? "lock.fill" : "moon.fill")
                    Text(context.isStale ? "Session complete" : (state.hardMode ? "Hard Mode" : context.attributes.title))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accent)

                if context.isStale {
                    Text("Done.")
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(palette.text)
                } else {
                    CountdownText(state: state)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 40, weight: .light, design: .rounded).monospacedDigit())
                        .foregroundStyle(palette.text)
                }

                Text(state.quote)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !context.isStale {
                ProgressView(timerInterval: min(state.startDate, state.endDate)...state.endDate,
                             countsDown: true,
                             label: { EmptyView() },
                             currentValueLabel: { EmptyView() })
                    .progressViewStyle(.circular)
                    .tint(palette.accent)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
