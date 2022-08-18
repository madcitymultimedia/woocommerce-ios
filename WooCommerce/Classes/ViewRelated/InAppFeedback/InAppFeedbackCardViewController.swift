
import UIKit
import StoreKit

/// Defines methods for presenting the in-app app store review form.
///
protocol SKStoreReviewControllerProtocol {
    /// Displays the in app app store review alert.
    ///
    static func requestReview(in windowScene: UIWindowScene)
}

extension SKStoreReviewController: SKStoreReviewControllerProtocol { }

/// Displays a small view asking the user to provide a feedback for the app.
///
final class InAppFeedbackCardViewController: UIViewController {

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var didNotLikeButton: UIButton!
    @IBOutlet private var likeButton: UIButton!

    /// Closure invoked after the user has chosen what kind feedback to give.
    var onFeedbackGiven: (() -> Void)?

    /// The stackview containing the `titleLabel` and the horizontal view for the buttons.
    @IBOutlet private var verticalStackView: UIStackView!

    /// SKStoreReviewController type wrapper. Needed for testing
    private let storeReviewControllerType: SKStoreReviewControllerProtocol.Type

    private let analytics: Analytics

    init(storeReviewControllerType: SKStoreReviewControllerProtocol.Type = SKStoreReviewController.self,
         analytics: Analytics = ServiceLocator.analytics) {
        self.storeReviewControllerType = storeReviewControllerType
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureVerticalStackView()
        configureTitleLabel()
        configureDidNotLikeButton()
        configureLikeButton()

        view.backgroundColor = .listForeground
    }
}

// MARK: - Provisioning

private extension InAppFeedbackCardViewController {

    func configureVerticalStackView() {
        verticalStackView.isLayoutMarginsRelativeArrangement = true
        verticalStackView.layoutMargins = .init(top: 0, left: 16, bottom: 0, right: 16)
    }

    func configureTitleLabel() {
        titleLabel.applyBodyStyle()
        titleLabel.numberOfLines = 0
        titleLabel.text = Localization.enjoyingTheWooCommerceApp
    }

    func configureDidNotLikeButton() {
        didNotLikeButton.applySecondaryButtonStyle()
        didNotLikeButton.setTitle(Localization.couldBeBetter, for: .normal)
        didNotLikeButton.on(.touchUpInside) { [weak self] _ in
            guard let self = self else {
                return
            }

            let surveyNavigation = SurveyCoordinatingController(survey: .inAppFeedback)
            self.present(surveyNavigation, animated: true, completion: nil)
            self.onFeedbackGiven?()
            self.analytics.track(event: .appFeedbackPrompt(action: .didntLike))
        }
    }

    func configureLikeButton() {
        likeButton.applyPrimaryButtonStyle()
        likeButton.setTitle(Localization.iLikeIt, for: .normal)
        likeButton.on(.touchUpInside) { [weak self] _ in
            guard let self = self else {
                return
            }
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive}) as? UIWindowScene {
                self.storeReviewControllerType.requestReview(in: windowScene)
            }
            self.onFeedbackGiven?()
            self.analytics.track(event: .appFeedbackPrompt(action: .liked))
        }
    }
}

// MARK: - Constants

private extension InAppFeedbackCardViewController {
    enum Localization {
        static let enjoyingTheWooCommerceApp = NSLocalizedString("Enjoying the WooCommerce app?",
                                                                 comment: "The title used when asking the user for feedback for the app.")
        static let couldBeBetter = NSLocalizedString("Could Be Better",
                                                     comment: "The title of the button for giving a negative feedback for the app.")
        static let iLikeIt = NSLocalizedString("I Like It",
                                               comment: "The title of the button for giving a positive feedback for the app.")
    }
}

// MARK: - Previews

#if canImport(SwiftUI) && DEBUG

import SwiftUI

private struct InAppFeedbackCardViewControllerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let viewController = InAppFeedbackCardViewController()
        return viewController.view
    }

    func updateUIView(_ view: UIView, context: Context) {
        // noop
    }
}

struct InAppFeedbackCardViewController_Previews: PreviewProvider {

    private static func makeStack() -> some View {
        VStack {
            InAppFeedbackCardViewControllerRepresentable()
        }
    }

    static var previews: some View {
        Group {
            makeStack()
                .previewLayout(.fixed(width: 320, height: 148))
                .previewDisplayName("Light")

            makeStack()
                .previewLayout(.fixed(width: 375, height: 128))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark")

            makeStack()
                .previewLayout(.fixed(width: 414, height: 528))
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Large Font")

            makeStack()
                .previewLayout(.fixed(width: 896, height: 128))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Large Width - Dark")
        }
    }
}

#endif
