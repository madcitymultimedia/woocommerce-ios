import Foundation
import XCTest
import Combine
import Fakes

@testable import WooCommerce
@testable import Yosemite

private typealias Dependencies = SimplePaymentsMethodsViewModel.Dependencies

final class SimplePaymentsMethodsViewModelTests: XCTestCase {

    var subscriptions = Set<AnyCancellable>()

    func test_loading_is_enabled_while_marking_order_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let dependencies = Dependencies(stores: stores)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        let loadingStates: [Bool] = waitFor { promise in
            viewModel.$showLoadingIndicator
                .dropFirst() // Initial value
                .collect(2)  // Collect toggle
                .first()
                .sink { loadingStates in
                    promise(loadingStates)
                }
                .store(in: &self.subscriptions)
            viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})
        }

        // Then
        XCTAssertEqual(loadingStates, [true, false]) // Loading, then not loading.
    }

    func test_view_is_disabled_while_loading_is_enabled() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let dependencies = Dependencies(stores: stores)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        let loading: Bool = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .updateOrderStatus:
                    promise(viewModel.showLoadingIndicator)
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }

            viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})
        }

        // Then
        XCTAssertTrue(loading)
        XCTAssertTrue(viewModel.disableViewActions)
    }

    func test_onSuccess_is_invoked_after_order_is_marked_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let dependencies = Dependencies(stores: stores)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        // When
        let onSuccessInvoked: Bool = waitFor { promise in
            viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {
                promise(true)
            })
        }

        // Then
        XCTAssertTrue(onSuccessInvoked)
    }

    func test_view_model_attempts_completed_notice_presentation_when_marking_an_order_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let dependencies = Dependencies(presentNoticeSubject: noticeSubject, stores: stores)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        // When
        let receivedCompleted: Bool = waitFor { promise in
            noticeSubject.sink { intent in
                switch intent {
                case .error, .created:
                    promise(false)
                case .completed:
                    promise(true)
                }
            }
            .store(in: &self.subscriptions)
            viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})
        }

        // Then
        XCTAssertTrue(receivedCompleted)
    }

    func test_view_model_attempts_error_notice_presentation_when_failing_to_mark_order_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let dependencies = Dependencies(presentNoticeSubject: noticeSubject, stores: stores)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(NSError(domain: "Error", code: 0))
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }

        // When
        let receivedError: Bool = waitFor { promise in
            noticeSubject.sink { intent in
                switch intent {
                case .error:
                    promise(true)
                case .completed, .created:
                    promise(false)
                }
            }
            .store(in: &self.subscriptions)
            viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})
        }

        // Then
        XCTAssertTrue(receivedError)
    }

    func test_completed_event_is_tracked_after_marking_order_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let analytics = MockAnalyticsProvider()
        let dependencies = Dependencies(stores: stores,
                                        analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})

        // Then
        assertEqual(analytics.receivedEvents.first, WooAnalyticsStat.simplePaymentsFlowCompleted.rawValue)
        assertEqual(analytics.receivedProperties.first?["payment_method"] as? String, "cash")
        assertEqual(analytics.receivedProperties.first?["amount"] as? String, "$12.00")
    }

    func test_completed_event_is_tracked_after_collecting_payment_successfully() {
        // Given
        let storage = MockStorageManager()
        storage.insertSampleOrder(readOnlyOrder: .fake())
        storage.insertSamplePaymentGatewayAccount(readOnlyAccount: .fake())

        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let analytics = MockAnalyticsProvider()
        let useCase = MockCollectOrderPaymentUseCase(onCollectResult: .success(()))
        let onboardingPresenter = MockCardPresentPaymentsOnboardingPresenter()
        let dependencies = Dependencies(
            cardPresentPaymentsOnboardingPresenter: onboardingPresenter,
            stores: stores,
            storage: storage,
            analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.collectPayment(on: UIViewController(), useCase: useCase, onSuccess: {})

        // Then
        assertEqual(analytics.receivedEvents.last, WooAnalyticsStat.simplePaymentsFlowCompleted.rawValue)
        assertEqual(analytics.receivedProperties.last?["payment_method"] as? String, "card")
        assertEqual(analytics.receivedProperties.last?["amount"] as? String, "$12.00")
    }

    func test_completed_event_is_tracked_after_sharing_a_link() {
        // Given
        let analytics = MockAnalyticsProvider()
        let dependencies = Dependencies(analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.performLinkSharedTasks()

        // Then
        assertEqual(analytics.receivedEvents.first, WooAnalyticsStat.simplePaymentsFlowCompleted.rawValue)
        assertEqual(analytics.receivedProperties.first?["payment_method"] as? String, "payment_link")
        assertEqual(analytics.receivedProperties.first?["amount"] as? String, "$12.00")
    }

    func test_failed_event_is_tracked_after_failing_to_mark_order_as_paid() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(NSError(domain: "", code: 0, userInfo: nil))
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let analytics = MockAnalyticsProvider()
        let dependencies = Dependencies(stores: stores,
                                        analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.markOrderAsPaid(paymentMethod: .cash, onSuccess: {})

        // Then
        assertEqual(analytics.receivedEvents.first, WooAnalyticsStat.simplePaymentsFlowFailed.rawValue)
        assertEqual(analytics.receivedProperties.first?["source"] as? String, "payment_method")
    }

    func test_failed_event_is_tracked_after_failing_to_collect_payment() {
        // Given
        let storage = MockStorageManager()
        storage.insertSampleOrder(readOnlyOrder: .fake())
        storage.insertSamplePaymentGatewayAccount(readOnlyAccount: .fake())

        let analytics = MockAnalyticsProvider()
        let useCase = MockCollectOrderPaymentUseCase(onCollectResult: .failure(NSError(domain: "Error", code: 0, userInfo: nil)))
        let onboardingPresenter = MockCardPresentPaymentsOnboardingPresenter()
        let dependencies = Dependencies(
            cardPresentPaymentsOnboardingPresenter: onboardingPresenter,
            storage: storage,
            analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.collectPayment(on: UIViewController(), useCase: useCase, onSuccess: {})

        // Then
        assertEqual(analytics.receivedEvents.last, WooAnalyticsStat.simplePaymentsFlowFailed.rawValue)
        assertEqual(analytics.receivedProperties.last?["source"] as? String, "payment_method")
    }

    func test_collect_event_is_tracked_when_paying_by_cash() {
        // Given
        let analytics = MockAnalyticsProvider()
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let dependencies = Dependencies(stores: stores,
                                        analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.trackCollectByCash()

        // Then
        assertEqual(analytics.receivedEvents, [WooAnalyticsStat.simplePaymentsFlowCollect.rawValue])
        assertEqual(analytics.receivedProperties.first?["payment_method"] as? String, "cash")
    }

    func test_collect_event_is_tracked_when_sharing_payment_links() {
        // Given
        let analytics = MockAnalyticsProvider()
        let dependencies = Dependencies(analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.trackCollectByPaymentLink()

        // Then
        assertEqual(analytics.receivedEvents, [WooAnalyticsStat.simplePaymentsFlowCollect.rawValue])
        assertEqual(analytics.receivedProperties.first?["payment_method"] as? String, "payment_link")
    }

    func test_collect_event_is_tracked_when_collecting_payment() {
        // Given
        let analytics = MockAnalyticsProvider()
        let useCase = MockCollectOrderPaymentUseCase(onCollectResult: .success(()))
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let onboardingPresenter = MockCardPresentPaymentsOnboardingPresenter()
        let dependencies = Dependencies(
            cardPresentPaymentsOnboardingPresenter: onboardingPresenter,
            stores: stores,
            analytics: WooAnalytics(analyticsProvider: analytics))
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        viewModel.collectPayment(on: UIViewController(), useCase: useCase, onSuccess: {})

        // Then
        assertEqual(analytics.receivedEvents.last, WooAnalyticsStat.simplePaymentsFlowCollect.rawValue)
        assertEqual(analytics.receivedProperties.last?["payment_method"] as? String, "card")
    }

    func test_card_row_is_shown_for_cpp_store() {
        // Given
        let cppStateObserver = MockCardPresentPaymentsOnboardingUseCase(initial: .completed(plugin: .wcPay))
        let dependencies = Dependencies(cppStoreStateObserver: cppStateObserver)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // Then
        XCTAssertTrue(viewModel.showPayWithCardRow)
    }

    func test_card_row_is_not_shown_for_non_cpp_store() {
        // Given
        let cppStateObserver = MockCardPresentPaymentsOnboardingUseCase(initial: .pluginNotInstalled)
        let dependencies = Dependencies(cppStoreStateObserver: cppStateObserver)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // Then
        XCTAssertFalse(viewModel.showPayWithCardRow)
    }

    func test_card_row_state_changes_when_store_state_changes() {
        // Given
        let subject = PassthroughSubject<CardPresentPaymentOnboardingState, Never>()
        let cppStateObserver = MockCardPresentPaymentsOnboardingUseCase(initial: .pluginNotInstalled, publisher: subject.eraseToAnyPublisher())
        let dependencies = Dependencies(cppStoreStateObserver: cppStateObserver)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)
        XCTAssertFalse(viewModel.showPayWithCardRow)

        // When
        subject.send(.completed(plugin: .wcPay))

        // Then
        XCTAssertTrue(viewModel.showPayWithCardRow)
    }

    func test_paymentLinkRow_is_hidden_if_payment_link_is_not_available() {
        // Given
        let viewModel = SimplePaymentsMethodsViewModel(paymentLink: nil, formattedTotal: "$12.00")

        // Then
        XCTAssertFalse(viewModel.showPaymentLinkRow)
        XCTAssertNil(viewModel.paymentLink)
    }

    func test_paymentLinkRow_is_shown_if_payment_link_is_available() {
        // Given
        let paymentURL = URL(string: "http://www.automattic.com")
        let viewModel = SimplePaymentsMethodsViewModel(paymentLink: paymentURL, formattedTotal: "$12.00")

        // Then
        XCTAssertTrue(viewModel.showPaymentLinkRow)
        XCTAssertNotNil(viewModel.paymentLink)
    }

    func test_view_model_attempts_created_notice_after_sharing_link() {
        // Given
        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let dependencies = Dependencies(presentNoticeSubject: noticeSubject)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        let receivedCompleted: Bool = waitFor { promise in
            noticeSubject.sink { intent in
                switch intent {
                case .error, .completed:
                    promise(false)
                case .created:
                    promise(true)
                }
            }
            .store(in: &self.subscriptions)
            viewModel.performLinkSharedTasks()
        }

        // Then
        XCTAssertTrue(receivedCompleted)
    }

    func test_view_model_attempts_completed_notice_after_collecting_payment() {
        // Given
        let storage = MockStorageManager()
        storage.insertSampleOrder(readOnlyOrder: .fake())
        storage.insertSamplePaymentGatewayAccount(readOnlyAccount: .fake())

        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let noticeSubject = PassthroughSubject<SimplePaymentsNotice, Never>()
        let useCase = MockCollectOrderPaymentUseCase(onCollectResult: .success(()))
        let onboardingPresenter = MockCardPresentPaymentsOnboardingPresenter()
        let dependencies = Dependencies(presentNoticeSubject: noticeSubject,
                                        cardPresentPaymentsOnboardingPresenter: onboardingPresenter,
                                        stores: stores,
                                        storage: storage)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        let receivedCompleted: Bool = waitFor { promise in
            noticeSubject.sink { intent in
                switch intent {
                case .error, .created:
                    promise(false)
                case .completed:
                    promise(true)
                }
            }
            .store(in: &self.subscriptions)

            viewModel.collectPayment(on: UIViewController(), useCase: useCase, onSuccess: {})
        }

        // Then
        XCTAssertTrue(receivedCompleted)
    }

    func test_view_model_calls_onSuccess_after_collecting_payment() {
        // Given
        let storage = MockStorageManager()
        storage.insertSampleOrder(readOnlyOrder: .fake())
        storage.insertSamplePaymentGatewayAccount(readOnlyAccount: .fake())

        let stores = MockStoresManager(sessionManager: .testingInstance)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .updateOrderStatus(_, _, _, onCompletion):
                onCompletion(nil)
            default:
                XCTFail("Unexpected action: \(action)")
            }
        }

        let useCase = MockCollectOrderPaymentUseCase(onCollectResult: .success(()))
        let onboardingPresenter = MockCardPresentPaymentsOnboardingPresenter()
        let dependencies = Dependencies(cardPresentPaymentsOnboardingPresenter: onboardingPresenter,
                                        stores: stores,
                                        storage: storage)
        let viewModel = SimplePaymentsMethodsViewModel(formattedTotal: "$12.00",
                                                       dependencies: dependencies)

        // When
        let calledOnSuccess: Bool = waitFor { promise in
            viewModel.collectPayment(on: UIViewController(), useCase: useCase, onSuccess: {
                promise(true)
            })
        }

        // Then
        XCTAssertTrue(calledOnSuccess)
    }
}
