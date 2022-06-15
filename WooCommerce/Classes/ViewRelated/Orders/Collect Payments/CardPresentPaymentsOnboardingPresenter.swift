import UIKit
import Yosemite
import Combine

protocol CardPresentPaymentsOnboardingPresenting {
    func showOnboardingIfRequired(from: UIViewController,
                                  readyToCollectPayment: @escaping (CardPresentPaymentsPlugin) -> Void)

    func refresh()
}

final class CardPresentPaymentsOnboardingPresenter: CardPresentPaymentsOnboardingPresenting {

    private let stores: StoresManager

    private let onboardingUseCase: CardPresentPaymentsOnboardingUseCase

    private let readinessUseCase: CardPresentPaymentsReadinessUseCase

    private let onboardingViewModel: InPersonPaymentsViewModel

    private var readinessSubscription: AnyCancellable?

    init(stores: StoresManager = ServiceLocator.stores) {
        self.stores = stores
        onboardingUseCase = CardPresentPaymentsOnboardingUseCase(stores: stores)
        readinessUseCase = CardPresentPaymentsReadinessUseCase(onboardingUseCase: onboardingUseCase, stores: stores)
        onboardingViewModel = InPersonPaymentsViewModel(useCase: onboardingUseCase, showMenuOnCompletion: false)
    }

    func showOnboardingIfRequired(from viewController: UIViewController,
                                  readyToCollectPayment completion: @escaping (CardPresentPaymentsPlugin) -> Void) {
        guard case let .ready(plugin) = readinessUseCase.readiness else {
            return showOnboarding(from: viewController, readyToCollectPayment: completion)
        }
        completion(plugin)
    }

    private func showOnboarding(from viewController: UIViewController,
                                readyToCollectPayment completion: @escaping (CardPresentPaymentsPlugin) -> Void) {
        let onboardingViewController = InPersonPaymentsViewController(viewModel: onboardingViewModel,
                                                                      onWillDisappear: { [weak self] in
            self?.readinessSubscription?.cancel()
        })
        viewController.show(onboardingViewController, sender: viewController)

        readinessSubscription = readinessUseCase.$readiness
            .sink(receiveValue: { readiness in
                guard case let .ready(plugin) = readiness else {
                    return
                }

                if let navigationController = viewController as? UINavigationController {
                    navigationController.popViewController(animated: true)
                } else {
                    viewController.navigationController?.popViewController(animated: true)
                }

                completion(plugin)
            })
    }

    func refresh() {
        onboardingUseCase.forceRefresh()
    }
}
