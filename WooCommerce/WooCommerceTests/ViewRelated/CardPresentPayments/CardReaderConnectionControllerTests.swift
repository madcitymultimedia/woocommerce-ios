import XCTest
import Fakes
import Storage
import Yosemite
@testable import WooCommerce

final class CardReaderConnectionControllerTests: XCTestCase {
    /// Dummy Site ID
    ///
    private let sampleSiteID: Int64 = 1234

    private let sampleGatewayID: String = "MOCKGATEWAY"

    private var storageManager: StorageManagerType!
    private var analyticsProvider: MockAnalyticsProvider!
    private var analytics: WooAnalytics!

    override func setUp() {
        super.setUp()
        storageManager = MockStorageManager()
        analyticsProvider = MockAnalyticsProvider()
        analytics = WooAnalytics(analyticsProvider: analyticsProvider)
        ServiceLocator.setAnalytics(analytics)
    }

    override func tearDown() {
        super.tearDown()
        storageManager = nil
        analytics = nil
        analyticsProvider = nil
    }

    func test_cancelling_search_calls_completion_with_success_false() throws {
        // Given
        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelScanning)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                XCTAssertTrue(result.isSuccess)
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }

    func test_finding_an_unknown_reader_prompts_user_before_completing_with_success_true() {
        // Given
        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [MockCardReader.bbposChipper2XBT()],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .connectFoundReader)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .connected)

        XCTAssert(analyticsProvider.receivedEvents.contains(WooAnalyticsStat.cardReaderConnectionSuccess.rawValue))
        XCTAssertEqual(
            analyticsProvider.receivedProperties.first?[WooAnalyticsEvent.InPersonPayments.Keys.gatewayID] as? String,
            sampleGatewayID
        )
    }

    func test_finding_an_known_reader_automatically_connects_and_completes_with_success_true() {
        // Given
        let knownReader = MockCardReader.bbposChipper2XBT()

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [knownReader],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: knownReader.id)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .connectFoundReader)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .connected)
    }

    func test_searching_error_presents_error_to_user_and_completes_with_failure() {
        // Given
        let expectation = self.expectation(description: #function)

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager,
            failDiscovery: true
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .closeScanFailure)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        controller.searchAndConnect(from: mockPresentingViewController) { result in
            XCTAssertTrue(result.isFailure)
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: Constants.expectationTimeout)
        XCTAssert(analyticsProvider.receivedEvents.contains(WooAnalyticsStat.cardReaderDiscoveryFailed.rawValue))
        XCTAssertEqual(
            analyticsProvider.receivedProperties.first?[WooAnalyticsEvent.InPersonPayments.Keys.gatewayID] as? String,
            sampleGatewayID
        )
    }

    func test_finding_multiple_readers_presents_list_to_user_and_cancelling_list_calls_completion_with_success_false() {
        // Given
        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [MockCardReader.bbposChipper2XBT(), MockCardReader.bbposChipper2XBT()],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelFoundSeveral)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }

    func test_user_can_cancel_search_after_connection_error() {
        // Given
        let discoveredReaders = [MockCardReader.bbposChipper2XBT()]

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: discoveredReaders,
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager,
            failConnection: true
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelSearchingAfterConnectionFailure)

        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)

        XCTAssert(analyticsProvider.receivedEvents.contains(WooAnalyticsStat.cardReaderConnectionFailed.rawValue))
        XCTAssertEqual(
            analyticsProvider.receivedProperties.first?[WooAnalyticsEvent.InPersonPayments.Keys.gatewayID] as? String,
            sampleGatewayID
        )
    }

    func test_user_can_cancel_search_after_connection_error_due_to_low_battery() {
        // Given
        let discoveredReaders = [MockCardReader.bbposChipper2XBTWithCriticallyLowBattery()]

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: discoveredReaders,
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelSearchingAfterConnectionFailure)

        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }

    func test_finding_multiple_readers_presents_list_to_user_and_choosing_one_calls_completion_with_success_true() {
        // Given
        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [MockCardReader.bbposChipper2XBT(), MockCardReader.bbposChipper2XBT()],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
	)
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .connectFirstFound)

        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .connected)
    }

    func test_user_can_continue_search_after_connection_error() {
        // Given
        let discoveredReaders = [MockCardReader.bbposChipper2XBT()]

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: discoveredReaders,
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager,
            failConnection: true
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .continueSearchingAfterConnectionFailure)

        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }

    func test_user_can_continue_search_after_update_error() {
        // Given
        let discoveredReaders = [MockCardReader.bbposChipper2XBT()]

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: discoveredReaders,
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager,
            failUpdate: true
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .continueSearchingAfterConnectionFailure)

        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }

    func test_cancelling_connection_calls_completion_with_success_and_canceled() throws {
        // Given
        let unknownReader = MockCardReader.bbposChipper2XBT()

        let mockStoresManager = MockCardPresentPaymentsStoresManager(
            connectedReaders: [],
            discoveredReaders: [unknownReader],
            sessionManager: SessionManager.testingInstance,
            storageManager: storageManager
        )
        ServiceLocator.setStores(mockStoresManager)
        let mockPresentingViewController = UIViewController()
        let mockKnownReaderProvider = MockKnownReaderProvider(knownReader: nil)
        let mockAlerts = MockCardReaderSettingsAlerts(mode: .cancelFoundReader)
        let controller = CardReaderConnectionController(
            forSiteID: sampleSiteID,
            storageManager: storageManager,
            knownReaderProvider: mockKnownReaderProvider,
            alertsProvider: mockAlerts,
            configuration: Mocks.configuration,
            analyticsTracker: .init(configuration: Mocks.configuration,
                                    stores: mockStoresManager)
        )

        // When
        let connectionResult: CardReaderConnectionController.ConnectionResult = waitFor { promise in
            controller.searchAndConnect(from: mockPresentingViewController) { result in
                if case .success(let connectionResult) = result {
                    promise(connectionResult)
                }
            }
        }

        // Then
        XCTAssertEqual(connectionResult, .canceled)
    }
}

private extension CardReaderConnectionControllerTests {
    enum Mocks {
        static let configuration = CardPresentPaymentsConfiguration(country: "US")
    }
}
