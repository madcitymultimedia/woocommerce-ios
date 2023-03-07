import SwiftUI
import Kingfisher

/// Hosting controller for `WPComPasswordLoginView`
final class WPComPasswordLoginHostingController: UIHostingController<WPComPasswordLoginView> {

    init(siteURL: String,
         email: String,
         requiresConnectionOnly: Bool,
         onSubmit: @escaping (String) async -> Void,
         onMagicLinkRequest: @escaping (String) async -> Void) {
        let viewModel = WPComPasswordLoginViewModel(siteURL: siteURL,
                                                    email: email,
                                                    requiresConnectionOnly: requiresConnectionOnly)
        super.init(rootView: WPComPasswordLoginView(viewModel: viewModel,
                                                    onSubmit: onSubmit,
                                                    onMagicLinkRequest: onMagicLinkRequest))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTransparentNavigationBar()
    }
}

/// Screen for entering the password for a WPCom account during the Jetpack setup flow
/// This is presented for users authenticated with WPOrg credentials.
struct WPComPasswordLoginView: View {
    @State private var isPrimaryButtonLoading = false
    @State private var isSecondaryButtonLoading = false
    @FocusState private var isPasswordFieldFocused: Bool
    @ObservedObject private var viewModel: WPComPasswordLoginViewModel

    private let onSubmit: (String) async -> Void
    private let onMagicLinkRequest: (String) async -> Void

    init(viewModel: WPComPasswordLoginViewModel,
         onSubmit: @escaping (String) async -> Void,
         onMagicLinkRequest: @escaping (String) async -> Void) {
        self.viewModel = viewModel
        self.onSubmit = onSubmit
        self.onMagicLinkRequest = onMagicLinkRequest
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.blockVerticalPadding) {
                JetpackInstallHeaderView()

                // Title
                Text(viewModel.titleString)
                    .largeTitleStyle()

                // Avatar and email
                HStack(spacing: Constants.contentPadding) {
                    viewModel.avatarURL.map { url in
                        KFImage(url)
                            .resizable()
                            .clipShape(Circle())
                            .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                    }
                    Text(viewModel.email)
                    Spacer()
                }
                .padding(Constants.avatarPadding)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.gray, lineWidth: 1)
                )

                // Password field
                AccountCreationFormFieldView(viewModel: .init(
                    header: Localization.passwordLabel,
                    placeholder: Localization.passwordPlaceholder,
                    keyboardType: .default,
                    text: $viewModel.password,
                    isSecure: true,
                    errorMessage: nil,
                    isFocused: isPasswordFieldFocused
                ))
                .focused($isPasswordFieldFocused)

                // Reset password button
                Button {
                    viewModel.resetPassword()
                } label: {
                    Text(Localization.resetPassword)
                        .linkStyle()
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(Constants.contentPadding)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                // Primary CTA
                Button(Localization.primaryAction) {
                    Task { @MainActor in
                        isPrimaryButtonLoading = true
                        await onSubmit(viewModel.password)
                        isPrimaryButtonLoading = false
                    }
                }
                .buttonStyle(PrimaryLoadingButtonStyle(isLoading: isPrimaryButtonLoading))
                .disabled(viewModel.password.isEmpty)

                // Secondary CTA
                Button(Localization.secondaryAction) {
                    Task { @MainActor in
                        isSecondaryButtonLoading = true
                        await onMagicLinkRequest(viewModel.email)
                        isSecondaryButtonLoading = false
                    }
                }
                .buttonStyle(SecondaryLoadingButtonStyle(isLoading: isSecondaryButtonLoading))
            }
            .padding(Constants.contentPadding)
            .background(Color(uiColor: .systemBackground))
        }
    }
}

private extension WPComPasswordLoginView {
    enum Constants {
        static let blockVerticalPadding: CGFloat = 32
        static let contentVerticalSpacing: CGFloat = 8
        static let contentPadding: CGFloat = 16
        static let avatarSize: CGFloat = 32
        static let avatarPadding: EdgeInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)
    }

    enum Localization {
        static let passwordLabel = NSLocalizedString(
            "Enter your WordPress.com password",
            comment: "Label for the password field on the WPCom password login screen of the Jetpack setup flow."
        )
        static let passwordPlaceholder = NSLocalizedString(
            "Enter password",
            comment: "Placeholder text for the password field on the WPCom password login screen of the Jetpack setup flow."
        )
        static let resetPassword = NSLocalizedString(
            "Reset your password",
            comment: "Button to reset password on the WPCom password login screen of the Jetpack setup flow."
        )
        static let primaryAction = NSLocalizedString(
            "Continue",
            comment: "Button to submit password on the WPCom password login screen of the Jetpack setup flow."
        )
        static let secondaryAction = NSLocalizedString(
            "Or Continue using Magic Link",
            comment: "Button to switch to magic link on the WPCom password login screen of the Jetpack setup flow."
        )
    }
}

struct WPComPasswordLoginView_Previews: PreviewProvider {
    static var previews: some View {
        WPComPasswordLoginView(viewModel: .init(siteURL: "https://example.com",
                                                email: "test@example.com",
                                                requiresConnectionOnly: true),
                               onSubmit: { _ in },
                               onMagicLinkRequest: { _ in })
    }
}
