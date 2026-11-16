import Foundation
import UIKit

/// Tells "switched to another app" apart from "locked the phone".
///
/// Both send the app to the background, but only the first is a breach. When the
/// app is backgrounded we keep it alive for a short grace period and check whether
/// the device locked at the same moment, using:
///  - SpringBoard's Darwin notification `com.apple.springboard.lockcomplete`
///    (not App Store–safe, fine for a sideloaded build), and
///  - `protectedDataWillBecomeUnavailable` (fires on lock when a passcode is set).
@MainActor
final class EscapeDetector {
    private var lastLockDate: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var protectedDataObserver: NSObjectProtocol?

    init() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let detector = Unmanaged<EscapeDetector>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in detector.markLocked() }
            },
            "com.apple.springboard.lockcomplete" as CFString,
            nil,
            .deliverImmediately
        )

        protectedDataObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.markLocked() }
        }
    }

    private func markLocked() { lastLockDate = Date() }

    /// Calls `completion(true)` if the backgrounding was the device locking.
    func classifyBackgrounding(grace: TimeInterval = 1.5,
                               _ completion: @escaping @MainActor (_ wasDeviceLock: Bool) -> Void) {
        let leftAt = Date()
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "focus.escape-check") { [weak self] in
            MainActor.assumeIsolated { self?.endBackgroundTask() }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(grace))
            guard let self else { return }
            // Lock events can arrive slightly before or after the background transition.
            let wasLock = self.lastLockDate.map { $0 >= leftAt.addingTimeInterval(-2) } ?? false
            completion(wasLock)
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
