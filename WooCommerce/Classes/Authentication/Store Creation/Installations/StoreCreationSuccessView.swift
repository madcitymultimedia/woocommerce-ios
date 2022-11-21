import SwiftUI

/// Hosting controller that wraps the `StoreCreationSuccessView`.
final class StoreCreationSuccessHostingController: UIHostingController<StoreCreationSuccessView> {
    private let onContinue: () -> Void

    init(siteURL: URL,
         onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        super.init(rootView: StoreCreationSuccessView(siteURL: siteURL))

        rootView.onContinue = { [weak self] in
            self?.onContinue()
        }
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBarAppearance()
    }

    /// Shows a transparent navigation bar without a bottom border and with a close button to dismiss.
    func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .systemBackground

        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }
}

struct StoreCreationSuccessView: View {
    /// Set in the hosting controller.
    var onContinue: () -> Void = {}

    /// URL of the newly created site.
    let siteURL: URL

    // Tracks the scale of the view due to accessibility changes.
    @ScaledMetric private var scale: CGFloat = 1.0

    @State private var isPresentingWebview: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 33) {
                // Title label.
                Text(Localization.title)
                    .fontWeight(.bold)
                    .titleStyle()

                // Readonly webview for the new site.
                WebView(isPresented: .constant(true), url: siteURL)
                    .frame(height: 400 * scale)
                    .disabled(true)
                    .border(Color(.systemBackground), width: 8)
                    .cornerRadius(8)
                    .shadow(color: Color(.secondaryLabel), radius: 26)
                    .padding(.horizontal, insets: Layout.webviewHorizontalPadding)
            }
            .padding(Layout.contentPadding)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator))

                VStack(spacing: 16) {
                    // Continue button.
                    Button(Localization.continueButtonTitle) {
                        onContinue()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    // Preview button.
                    Button(Localization.previewButtonTitle) {
                        isPresentingWebview = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(insets: Layout.buttonContainerPadding)
            }
            .background(Color(.systemBackground))
        }
        .safariSheet(isPresented: $isPresentingWebview, url: siteURL)
    }
}

private extension StoreCreationSuccessView {
    enum Layout {
        static let contentPadding: EdgeInsets = .init(top: 38, leading: 16, bottom: 16, trailing: 16)
        static let buttonContainerPadding: EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
        static let webviewHorizontalPadding: EdgeInsets = .init(top: 0, leading: 44, bottom: 0, trailing: 44)
    }

    enum Localization {
        static let title = NSLocalizedString(
            "Your store has been created!",
            comment: "Title of the store creation success screen."
        )
        static let continueButtonTitle = NSLocalizedString(
            "Manage My Store",
            comment: "Title of the primary button on the store creation success screen to continue to the newly created store."
        )
        static let previewButtonTitle = NSLocalizedString(
            "Store Preview",
            comment: "Title of the secondary button on the store creation success screen to preview the newly created store."
        )
    }
}

struct StoreCreationSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        StoreCreationSuccessView(siteURL: URL(string: "https://woocommerce.com")!)
        StoreCreationSuccessView(siteURL: URL(string: "https://woocommerce.com")!)
            .preferredColorScheme(.dark)
    }
}
