import SwiftUI

/// Hosting controller wrapper for `JetpackInstallIntroView`
///
final class JetpackInstallHostingController: UIHostingController<JetpackInstallView> {
    init(siteID: Int64, siteURL: String, siteAdminURL: String) {
        super.init(rootView: JetpackInstallView(siteID: siteID, siteURL: siteURL, siteAdminURL: siteAdminURL))
        rootView.supportAction = { [unowned self] in
            if ServiceLocator.featureFlagService.isFeatureFlagEnabled(.supportRequests) {
                let supportForm = SupportFormHostingController(viewModel: .init())
                supportForm.show(from: self)
            } else {
                ZendeskProvider.shared.showNewRequestIfPossible(from: self)
            }
        }

        // Set presenting view controller to show the notice presenter here
        rootView.noticePresenter.presentingViewController = self
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setDismissAction(_ dismissAction: @escaping () -> Void) {
        rootView.dismissAction = dismissAction
    }
}

/// Displays Jetpack Install flow.
///
struct JetpackInstallView: View {
    /// The presenter to display notice when an error occurs.
    /// It is kept internal so that the hosting controller can update its presenting controller to itself.
    let noticePresenter: DefaultNoticePresenter = .init()

    // Closure invoked when Contact Support button is tapped
    var supportAction: () -> Void = {}

    // Closure invoked when Close button is tapped
    var dismissAction: () -> Void = {}

    // URL of the site to install Jetpack to
    private let siteURL: String

    // URL of the site's admin page
    private let siteAdminURL: String

    // View model for `JetpackInstallStepsView`
    private let installStepsViewModel: JetpackInstallStepsViewModel

    @State private var hasStarted = false

    init(siteID: Int64, siteURL: String, siteAdminURL: String) {
        self.siteURL = siteURL
        self.siteAdminURL = siteAdminURL
        self.installStepsViewModel = JetpackInstallStepsViewModel(siteID: siteID, siteURL: siteURL, siteAdminURL: siteAdminURL)
    }

    var body: some View {
        if hasStarted {
            JetpackInstallStepsView(viewModel: installStepsViewModel,
                                    noticePresenter: noticePresenter,
                                    supportAction: supportAction,
                                    dismissAction: dismissAction)
        } else {
            JetpackInstallIntroView(siteURL: siteURL, dismissAction: dismissAction) {
                hasStarted = true
                ServiceLocator.analytics.track(.jetpackInstallGetStartedButtonTapped)
            }
        }
    }
}

struct JetpackInstallView_Previews: PreviewProvider {
    static var previews: some View {
        JetpackInstallView(siteID: 123, siteURL: "automattic.com", siteAdminURL: "")
            .preferredColorScheme(.light)
            .previewLayout(.fixed(width: 414, height: 780))
    }
}
