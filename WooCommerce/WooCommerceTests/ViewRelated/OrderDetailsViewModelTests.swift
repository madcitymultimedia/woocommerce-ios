import XCTest
import Yosemite

@testable import WooCommerce

final class OrderDetailsViewModelTests: XCTestCase {
    private var order: Order!
    private var viewModel: OrderDetailsViewModel!

    private var storesManager: MockStoresManager!

    override func setUp() {
        storesManager = MockStoresManager(sessionManager: SessionManager.makeForTesting())

        order = MockOrders().sampleOrder()

        viewModel = OrderDetailsViewModel(order: order, stores: storesManager)

        let analytics = WooAnalytics(analyticsProvider: MockAnalyticsProvider())
        ServiceLocator.setAnalytics(analytics)
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        viewModel = nil
        order = nil
        storesManager = nil
    }

    func test_deleteTracking_fires_orderTrackingDelete_Tracks_event() {
        // Given
        let mockShipmentTracking = ShipmentTracking(siteID: 1111,
                                                    orderID: 1111,
                                                    trackingID: "1111",
                                                    trackingNumber: "1111",
                                                    trackingProvider: nil,
                                                    trackingURL: nil,
                                                    dateShipped: nil)

        // When
        viewModel.deleteTracking(mockShipmentTracking) { _ in }

        // Then
        let analytics = ServiceLocator.analytics.analyticsProvider as! MockAnalyticsProvider
        let receivedEvents = analytics.receivedEvents

        XCTAssert(receivedEvents.contains(WooAnalyticsStat.orderTrackingDelete.rawValue))
    }

    func test_markComplete_dispatches_updateOrder_action() throws {
        // Given
        storesManager.reset()
        XCTAssertEqual(storesManager.receivedActions.count, 0)

        // When
        _ = viewModel.markCompleted()

        // Then
        XCTAssertEqual(storesManager.receivedActions.count, 1)

        let action = try XCTUnwrap(storesManager.receivedActions.first as? OrderAction)
        guard case let .updateOrderStatus(siteID: siteID, orderID: orderID, status: status, onCompletion: _) = action else {
            XCTFail("Expected \(action) to be \(OrderAction.self)")
            return
        }

        XCTAssertEqual(siteID, order.siteID)
        XCTAssertEqual(orderID, order.orderID)
        XCTAssertEqual(status, .completed)
    }

    func test_checkShippingLabelCreationEligibility_dispatches_correctly() throws {
        // Given
        storesManager.reset()
        XCTAssertEqual(storesManager.receivedActions.count, 0)

        // When
        viewModel.checkShippingLabelCreationEligibility()

        // Then
        XCTAssertEqual(storesManager.receivedActions.count, 1)

        let action = try XCTUnwrap(storesManager.receivedActions.first as? ShippingLabelAction)
        guard case let ShippingLabelAction.checkCreationEligibility(siteID: siteID,
                                                                    orderID: orderID,
                                                                    onCompletion: _) = action else {
            XCTFail("Expected \(action) to be \(ShippingLabelAction.self)")
            return
        }

        XCTAssertEqual(siteID, order.siteID)
        XCTAssertEqual(orderID, order.orderID)
    }

    func test_there_should_not_be_share_link_action_if_order_is_not_pending_payment() {
        // Given
        let order = Order.fake().copy(status: .processing, total: "10.0", paymentURL: nil)

        // When
        let viewModel = OrderDetailsViewModel(order: order)

        // Then
        let actionButtonIDs = viewModel.moreActionsButtons.map { $0.id }
        XCTAssertFalse(actionButtonIDs.contains(.sharePaymentLink))
    }

    func test_there_should_be_share_link_action_if_order_is_pending_payment() {
        // Given
        let paymentURL = URL(string: "http://www.automattic.com")
        let order = Order.fake().copy(status: .pending, total: "10.0", paymentURL: paymentURL)

        // When
        let viewModel = OrderDetailsViewModel(order: order)

        // Then
        let actionButtonIDs = viewModel.moreActionsButtons.map { $0.id }
        XCTAssertTrue(actionButtonIDs.contains(.sharePaymentLink))
    }

    func test_there_should_not_be_edit_order_action_if_order_is_not_synced() {
        // Given
        let order = Order.fake().copy(total: "10.0")

        // When
        let viewModel = OrderDetailsViewModel(order: order)

        // Then
        let actionButtonIDs = viewModel.moreActionsButtons.map { $0.id }
        XCTAssertFalse(actionButtonIDs.contains(.editOrder))
    }
}
