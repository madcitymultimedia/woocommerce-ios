import XCTest
import TestKit
@testable import Networking

final class PaymentRemoteTests: XCTestCase {
    /// Mock network wrapper.
    private var network: MockNetwork!

    override func setUp() {
        super.setUp()
        network = MockNetwork()
    }

    override func tearDown() {
        network = nil
        super.tearDown()
    }

    // MARK: - `loadPlan`

    func test_loadPlan_returns_plan_on_success() async throws {
        // Given
        let remote = PaymentRemote(network: network)
        network.simulateResponse(requestUrlSuffix: "plans", filename: "load-plan-success")

        // When
        let plan = try await remote.loadPlan(thatMatchesID: Constants.planProductID)

        // Then
        XCTAssertEqual(plan, .init(productID: Constants.planProductID,
                                   name: "WordPress.com eCommerce",
                                   formattedPrice: "NT$2,230"))
    }

    func test_loadPlan_throws_noMatchingPlan_error_when_response_does_not_include_plan_with_given_id() async throws {
        // Given
        let remote = PaymentRemote(network: network)
        network.simulateResponse(requestUrlSuffix: "plans", filename: "load-plan-success")

        // When
        await assertThrowsError {
            _ = try await remote.loadPlan(thatMatchesID: 9)
        } errorAssert: { error in
            // Then
            (error as? LoadPlanError) == .noMatchingPlan
        }
    }

    func test_loadPlan_throws_notFound_error_when_no_response() async throws {
        // Given
        let remote = PaymentRemote(network: network)

        // When
        await assertThrowsError {
            _ = try await remote.loadPlan(thatMatchesID: 9)
        } errorAssert: { error in
            // Then
            (error as? NetworkError) == .notFound
        }
    }

    // MARK: - `createCart`

    func test_createCart_returns_on_success() async throws {
        // Given
        let siteID: Int64 = 606
        let remote = PaymentRemote(network: network)
        network.simulateResponse(requestUrlSuffix: "me/shopping-cart/\(siteID)", filename: "create-cart-success")

        // When
        do {
            try await remote.createCart(siteID: siteID, productID: Constants.planProductID)
        } catch {
            // Then
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_createCart_throws_productNotInCart_error_when_response_does_not_include_plan_with_given_id() async throws {
        // Given
        let siteID: Int64 = 606
        let remote = PaymentRemote(network: network)
        network.simulateResponse(requestUrlSuffix: "me/shopping-cart/\(siteID)", filename: "create-cart-success")

        // When
        await assertThrowsError {
            _ = try await remote.createCart(siteID: siteID, productID: 685)
        } errorAssert: { error in
            // Then
            (error as? CreateCartError) == .productNotInCart
        }
    }

    func test_createCart_throws_notFound_error_when_no_response() async throws {
        // Given
        let remote = PaymentRemote(network: network)

        // When
        await assertThrowsError {
            _ = try await remote.createCart(siteID: 606, productID: 685)
        } errorAssert: { error in
            // Then
            (error as? NetworkError) == .notFound
        }
    }
}

private extension PaymentRemoteTests {
    enum Constants {
        static let planProductID: Int64 = 1021
    }
}
