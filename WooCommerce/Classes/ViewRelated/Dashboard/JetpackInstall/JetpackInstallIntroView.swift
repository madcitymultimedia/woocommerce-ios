import SwiftUI

/// Displays the intro view for the Jetpack install flow.
///
struct JetpackInstallIntroView: View {
    // Closure invoked when Close button is tapped
    private let dismissAction: () -> Void

    // Closure invoked when Get Started button is tapped
    private let startAction: () -> Void

    // URL of the site to install Jetpack to
    private let siteURL: String

    init(siteURL: String, dismissAction: @escaping () -> Void, startAction: @escaping () -> Void) {
        self.siteURL = siteURL
        self.dismissAction = dismissAction
        self.startAction = startAction
    }

    private var descriptionAttributedString: NSAttributedString {
        let font: UIFont = .body
        let boldFont: UIFont = font.bold
        let siteName = siteURL.trimHTTPScheme()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributedString = NSMutableAttributedString(
            string: String(format: Localization.installDescription, siteName),
            attributes: [.font: font,
                         .foregroundColor: UIColor.text.withAlphaComponent(0.8),
                         .paragraphStyle: paragraphStyle,
                        ]
        )
        let boldSiteAddress = NSAttributedString(string: siteName, attributes: [.font: boldFont, .foregroundColor: UIColor.text])
        attributedString.replaceFirstOccurrence(of: siteName, with: boldSiteAddress)
        return attributedString
    }

    @ScaledMetric private var scale: CGFloat = 1.0

    var body: some View {
        VStack {
            HStack {
                Button(Localization.closeButton, action: dismissAction)
                .buttonStyle(LinkButtonStyle())
                .fixedSize(horizontal: true, vertical: true)
                .padding(.top, Constants.cancelButtonTopMargin)
                Spacer()
            }

            Spacer()

            // Install Jetpack description
            VStack(spacing: Constants.contentSpacing) {
                Image(uiImage: .jetpackGreenLogoImage)
                    .resizable()
                    .frame(width: Constants.jetpackLogoSize * scale, height: Constants.jetpackLogoSize * scale)
                    .padding(.bottom, Constants.jetpackLogoBottomMargin)

                Text(Localization.installTitle)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.primary)

                AttributedText(descriptionAttributedString)
            }
            .padding(.horizontal, Constants.contentHorizontalMargin)
            .scrollVerticallyIfNeeded()

            Spacer()

            // Primary Button to install Jetpack
            Button(Localization.installAction, action: startAction)
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Constants.actionButtonMargin)
                .padding(.bottom, Constants.actionButtonMargin)
        }
    }
}

private extension JetpackInstallIntroView {
    enum Constants {
        static let cancelButtonTopMargin: CGFloat = 8
        static let jetpackLogoSize: CGFloat = 120
        static let jetpackLogoBottomMargin: CGFloat = 24
        static let actionButtonMargin: CGFloat = 16
        static let contentHorizontalMargin: CGFloat = 40
        static let contentSpacing: CGFloat = 8
    }

    enum Localization {
        static let closeButton = NSLocalizedString("Close", comment: "Title of the Close action on the Jetpack Install view")
        static let installAction = NSLocalizedString("Get Started", comment: "Title of install action in the Jetpack Install view.")
        static let installTitle = NSLocalizedString("Install Jetpack", comment: "Title of the Install Jetpack intro view")
        static let installDescription = NSLocalizedString("Install the free Jetpack plugin to %1$@ and experience the best mobile experience.",
                                                          comment: "Description of the Jetpack Install flow for the specified site. " +
                                                          "The %1$@ is the site address.")
    }
}

struct JetpackInstallIntroView_Previews: PreviewProvider {
    static var previews: some View {
        JetpackInstallIntroView(siteURL: "automattic.com", dismissAction: {}, startAction: {})
            .preferredColorScheme(.light)
            .previewLayout(.fixed(width: 414, height: 780))

        JetpackInstallIntroView(siteURL: "automattic.com", dismissAction: {}, startAction: {})
            .preferredColorScheme(.dark)
            .previewLayout(.fixed(width: 800, height: 400))
    }
}
