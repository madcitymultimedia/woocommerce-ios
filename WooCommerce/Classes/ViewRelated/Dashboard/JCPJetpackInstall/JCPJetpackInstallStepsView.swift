import SwiftUI

/// View to show steps of the Jetpack Install flow for JCP sites.
///
struct JCPJetpackInstallStepsView: View {
    /// The presenter to display notice when an error occurs.
    private let noticePresenter: DefaultNoticePresenter

    // Closure invoked when Contact Support button is tapped
    private let supportAction: () -> Void

    // Closure invoked when Done button is tapped
    private let dismissAction: () -> Void

    /// Whether the WPAdmin webview is being shown.
    @State private var showingWPAdminWebview: Bool = false

    // View model to handle the installation
    @ObservedObject private var viewModel: JCPJetpackInstallStepsViewModel

    /// Scale of the view based on accessibility changes
    @ScaledMetric private var scale: CGFloat = 1.0

    /// Attributed string for the description text
    private var descriptionAttributedString: NSAttributedString {
        let font: UIFont = .body
        let boldFont: UIFont = font.bold
        let siteName = viewModel.siteURL.trimHTTPScheme()

        let attributedString = NSMutableAttributedString(
            string: String(format: Localization.installDescription, siteName),
            attributes: [.font: font,
                         .foregroundColor: UIColor.text.withAlphaComponent(0.8)
                        ]
        )
        let boldSiteAddress = NSAttributedString(string: siteName, attributes: [.font: boldFont, .foregroundColor: UIColor.text])
        attributedString.replaceFirstOccurrence(of: siteName, with: boldSiteAddress)
        return attributedString
    }

    init(viewModel: JCPJetpackInstallStepsViewModel,
         noticePresenter: DefaultNoticePresenter,
         supportAction: @escaping () -> Void,
         dismissAction: @escaping () -> Void) {
        self.viewModel = viewModel
        self.noticePresenter = noticePresenter
        self.supportAction = supportAction
        self.dismissAction = dismissAction
        viewModel.startInstallation()
    }

    var body: some View {
        VStack {
            HStack {
                Button(Localization.closeButton, action: dismissAction)
                .buttonStyle(LinkButtonStyle())
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, Constants.cancelButtonTopMargin)
                Spacer()
            }
            // Main content
            VStack(alignment: .leading, spacing: Constants.contentSpacing) {
                // Header
                JetpackInstallHeaderView()
                    .padding(.top, Constants.contentTopMargin)

                // Title and description
                VStack(alignment: .leading, spacing: Constants.textSpacing) {
                    Text(viewModel.installFailed ? Localization.errorTitle :  Localization.installTitle)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Color(.text))
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.installFailed {
                        viewModel.currentStep?.errorMessage.map(Text.init)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        AttributedText(descriptionAttributedString)
                    }
                }

                // Loading indicator for when checking plugin details
                HStack {
                    Spacer()
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                    Spacer()
                }
                .renderedIf(viewModel.currentStep == nil)

                // Install steps
                VStack(alignment: .leading, spacing: Constants.stepItemsVerticalSpacing) {
                    viewModel.currentStep.map { currentStep in
                        ForEach(JetpackInstallStep.allCases) { step in
                            HStack(spacing: Constants.stepItemHorizontalSpacing) {
                                if step == currentStep, step != .done {
                                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                                } else if step > currentStep {
                                    Image(uiImage: .checkEmptyCircleImage)
                                        .resizable()
                                        .frame(width: Constants.stepImageSize * scale, height: Constants.stepImageSize * scale)
                                } else {
                                    Image(uiImage: .checkCircleImage)
                                        .resizable()
                                        .frame(width: Constants.stepImageSize * scale, height: Constants.stepImageSize * scale)
                                }

                                Text(step.title)
                                    .font(.body)
                                    .if(step <= currentStep) {
                                        $0.bold()
                                    }
                                    .foregroundColor(Color(.text))
                                    .opacity(step <= currentStep ? 1 : 0.5)
                            }
                        }
                    }
                }
                .renderedIf(!viewModel.installFailed)
            }
            .padding(.horizontal, Constants.contentHorizontalMargin)
            .scrollVerticallyIfNeeded()

            Spacer()

            // Done Button to dismiss Install Jetpack
            Button(Localization.doneButton, action: dismissAction)
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize(horizontal: false, vertical: true)
                .padding(Constants.actionButtonMargin)
                .renderedIf(viewModel.currentStep == .done)

            // Error state action buttons
            if viewModel.installFailed {
                VStack(spacing: Constants.actionButtonMargin) {
                    viewModel.currentStep?.errorActionTitle.map { title in
                        Button(title) {
                            if viewModel.currentStep == .connection {
                                viewModel.checkSiteConnection()
                            } else {
                                ServiceLocator.analytics.track(.jetpackInstallInWPAdminButtonTapped)
                                if viewModel.wpAdminURL == nil {
                                    let notice = Notice(title: Localization.errorOpeningWPAdmin, feedbackType: .error)
                                    noticePresenter.enqueue(notice: notice)
                                } else {
                                    showingWPAdminWebview = true
                                }
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(Localization.supportAction) {
                        supportAction()
                        ServiceLocator.analytics.track(.jetpackInstallContactSupportButtonTapped)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Constants.actionButtonMargin)
            }
        }
        .if(viewModel.wpAdminURL != nil) { view in
            view.safariSheet(isPresented: $showingWPAdminWebview, url: viewModel.wpAdminURL, onDismiss: {
                showingWPAdminWebview = false
                viewModel.checkJetpackPluginDetails()
            })
        }
    }
}

private extension JCPJetpackInstallStepsView {
    enum Constants {
        static let cancelButtonTopMargin: CGFloat = 8
        static let contentTopMargin: CGFloat = 32
        static let contentHorizontalMargin: CGFloat = 40
        static let contentSpacing: CGFloat = 32
        static let textSpacing: CGFloat = 12
        static let actionButtonMargin: CGFloat = 16
        static let stepItemHorizontalSpacing: CGFloat = 24
        static let stepItemsVerticalSpacing: CGFloat = 20
        static let stepImageSize: CGFloat = 24
    }

    enum Localization {
        static let closeButton = NSLocalizedString("Close", comment: "Title of the Close action on the Jetpack Install view")
        static let installTitle = NSLocalizedString("Install Jetpack", comment: "Title of the Install Jetpack view")
        static let installDescription = NSLocalizedString("Please wait while we connect your site %1$@ with Jetpack.",
                                                          comment: "Message on the Jetpack Install Progress screen. The %1$@ is the site address.")
        static let doneButton = NSLocalizedString("Done", comment: "Done button on the Jetpack Install Progress screen.")
        static let errorTitle = NSLocalizedString("Sorry, something went wrong during install", comment: "Error title when Jetpack install fails")
        static let supportAction = NSLocalizedString("Contact Support", comment: "Action button to contact support when Jetpack install fails")
        static let errorOpeningWPAdmin = NSLocalizedString(
            "Cannot find information about your site's WP-Admin. Please try again.",
            comment: "Error message when no URL to WP-Admin page is found during Jetpack install flow"
        )
    }
}

struct JCPJetpackInstallStepsView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = JCPJetpackInstallStepsViewModel(siteID: 123, siteURL: "automattic.com", siteAdminURL: "")
        JCPJetpackInstallStepsView(viewModel: viewModel, noticePresenter: .init(), supportAction: {}, dismissAction: {})
            .preferredColorScheme(.light)
            .previewLayout(.fixed(width: 414, height: 780))

        JCPJetpackInstallStepsView(viewModel: viewModel, noticePresenter: .init(), supportAction: {}, dismissAction: {})
            .preferredColorScheme(.dark)
            .previewLayout(.fixed(width: 414, height: 780))
    }
}
