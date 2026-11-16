import ManagedSettings

/// Handles taps on the shield's buttons.
/// - Primary ("Close"): sends the user home.
/// - Secondary ("End focus"): only exists outside Hard Mode; lifts soft blocks.
final class FocusShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completion: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completion(.close)
        case .secondaryButtonPressed:
            // Defence in depth: even if a stale shield still shows the button,
            // Hard Mode can never be ended from here.
            guard !SharedStore.shared.isHardModeEngaged() else {
                completion(.close)
                return
            }
            ShieldController.liftSoftBlocks()
            completion(.defer)
        @unknown default:
            completion(.close)
        }
    }
}
