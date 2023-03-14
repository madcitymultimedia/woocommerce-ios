import Foundation
import UIKit

/// Empty state screen shown when the store stats version is not supported
///
final class DeprecatedDashboardStatsViewController: UIViewController {
    /// Set externally to try refreshing stats data if available.
    var onPullToRefresh: @MainActor () async -> Void = {}

    /// Empty state screen
    ///
    private lazy var emptyStateViewController = EmptyStateViewController(style: .basic)

    /// Empty state screen configuration
    ///
    private let emptyStateConfig: EmptyStateViewController.Config = {
        let message = NSAttributedString(string: Constants.title, attributes: [.font: EmptyStateViewController.Config.messageFont.bold])
        return .withSupportRequest(message: message,
                                   image: .noStoreImage,
                                   details: Constants.details,
                                   buttonTitle: Constants.buttonTitle)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        displayEmptyViewController()
    }

    /// Shows the EmptyStateViewController
    ///
    private func displayEmptyViewController() {
        addChild(emptyStateViewController)

        emptyStateViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateViewController.view)
        view.pinSubviewToSafeArea(emptyStateViewController.view)

        emptyStateViewController.didMove(toParent: self)
        emptyStateViewController.configure(emptyStateConfig)
    }
}

// MARK: DashboardUI conformance
// Everything is empty as this deprecated stats screen is static
extension DeprecatedDashboardStatsViewController: DashboardUI {
    var displaySyncingError: () -> Void {
        get {
            return {}
        }
        set {}
    }

    func remindStatsUpgradeLater() {}
    @MainActor
    func reloadData(forced: Bool) async {}
}

// MARK: Constants
private extension DeprecatedDashboardStatsViewController {
    struct Constants {
        static let title = NSLocalizedString("We can’t display your store’s analytics",
                                      comment: "Title when we can't show stats because user is on a deprecated WC Version")
        static let details = NSLocalizedString(
            "Make sure you are running the latest version of WooCommerce on your site and that you have WooCommerce Admin activated.",
            comment: "Text that explains how to update VC to get the latest stats"
        )
        static let buttonTitle = NSLocalizedString("Still need help? Contact us",
                                                   comment: "Button title to contact support to get help with deprecated stats")
    }
}
