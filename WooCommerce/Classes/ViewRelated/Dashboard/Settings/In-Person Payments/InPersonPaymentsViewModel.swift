import Combine
import Yosemite

final class InPersonPaymentsViewModel: ObservableObject {
    @Published var state: CardPresentPaymentOnboardingState
    var userIsAdministrator: Bool
    var learnMoreURL: URL? = nil
    private let useCase = CardPresentPaymentsOnboardingUseCase()
    let stores: StoresManager

    /// Initializes the view model for a specific site
    ///
    init(stores: StoresManager = ServiceLocator.stores) {
        self.stores = stores
        state = useCase.state
        userIsAdministrator = ServiceLocator.stores.sessionManager.defaultRoles.contains(.administrator)

        useCase.$state
            // Debounce values to prevent the loading screen flashing when there is no connection
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] result in
                self?.updateLearnMoreURL(state: result)
            })
            .handleEvents(receiveOutput: trackState(_:))
            .assign(to: &$state)
        refresh()
    }

    /// Initializes the view model with a fixed state that never changes.
    /// This is useful for SwiftUI previews or testing, but shouldn't be used in production
    ///
    init(
        fixedState: CardPresentPaymentOnboardingState,
        fixedUserIsAdministrator: Bool = false,
        stores: StoresManager = ServiceLocator.stores) {
            self.stores = stores
            state = fixedState
            userIsAdministrator = fixedUserIsAdministrator
            updateLearnMoreURL(state: fixedState)
        }

    /// Synchronizes the required data from the server and recalculates the state
    ///
    func refresh() {
        useCase.refresh()
    }

    private func updateLearnMoreURL(state: CardPresentPaymentOnboardingState) {
        let preferredPlugin: CardPresentPaymentsPlugin
        switch state {
        case .pluginUnsupportedVersion(let plugin),
                .pluginNotActivated(let plugin),
                .pluginInTestModeWithLiveStripeAccount(let plugin),
                .pluginSetupNotCompleted(let plugin),
                .countryNotSupportedStripe(let plugin, _),
                .stripeAccountUnderReview(let plugin),
                .stripeAccountPendingRequirement(let plugin, _),
                .stripeAccountOverdueRequirement(let plugin),
                .stripeAccountRejected(let plugin):
            preferredPlugin = plugin
        default:
            preferredPlugin = .wcPay
        }

        learnMoreURL = { () -> URL in
            switch preferredPlugin {
            case .wcPay:
                return WooConstants.URLs.inPersonPaymentsLearnMoreWCPay.asURL()
            case .stripe:
                return WooConstants.URLs.inPersonPaymentsLearnMoreStripe.asURL()
            }
        }()
    }
}

private extension InPersonPaymentsViewModel {
    func trackState(_ state: CardPresentPaymentOnboardingState) {
        guard let reason = state.reasonForAnalytics else {
            return
        }
        ServiceLocator.analytics
            .track(event: .InPersonPayments
                    .cardPresentOnboardingNotCompleted(reason: reason,
                                                       countryCode: useCase.configurationLoader.configuration.countryCode))
    }
}
