import Foundation
import WebKit

/// View model used for the web view controller to setup Jetpack connection during the login flow.
///
final class JetpackConnectionWebViewModel: AuthenticatedWebViewModel {
    let title = Localization.title

    let initialURL: URL?
    let siteURL: String
    let completionHandler: () -> Void

    private let analytics: Analytics

    init(initialURL: URL,
         siteURL: String,
         analytics: Analytics = ServiceLocator.analytics,
         completion: @escaping () -> Void) {
        self.analytics = analytics
        self.initialURL = initialURL
        self.siteURL = siteURL
        self.completionHandler = completion
    }

    func handleDismissal() {
        analytics.track(.loginJetpackConnectDismissed)
    }

    func handleRedirect(for url: URL?) {
        guard let path = url?.absoluteString else {
            return
        }
        handleCompletionIfPossible(path)
    }

    func decidePolicy(for navigationURL: URL) async -> WKNavigationActionPolicy {
        let url = navigationURL.absoluteString
        if handleCompletionIfPossible(url) {
            return .cancel
        }
        return .allow
    }

    private func handleSetupCompletion() {
        analytics.track(.loginJetpackConnectCompleted)
        completionHandler()
    }

    @discardableResult
    func handleCompletionIfPossible(_ url: String) -> Bool {
        // When the web view navigates to the site address or Jetpack plans page,
        // we can assume that the setup has completed.
        if url.hasPrefix(Constants.plansPage) ||
            (url.hasPrefix(siteURL) && !url.contains(Constants.jetpackSiteConnectionPage)) {
            // Running on the main thread is necessary if this method is triggered from `decidePolicy`.
            DispatchQueue.main.async { [weak self] in
                self?.handleSetupCompletion()
            }
            return true
        }
        return false
    }
}

private extension JetpackConnectionWebViewModel {
    enum Constants {
        static let plansPage = "https://wordpress.com/jetpack/connect/plans"
        static let jetpackSiteConnectionPage = "/wp-admin/admin.php?page=jetpack&action=register"
    }

    enum Localization {
        static let title = NSLocalizedString("Connect Jetpack", comment: "Title of the Jetpack connection web view in the login flow")
    }
}
