import XCTest
@testable import Yosemite
@testable import Networking
@testable import Storage


/// OrderNoteStore Unit Tests
///
class OrderNoteStoreTests: XCTestCase {

    /// Mock Dispatcher!
    ///
    private var dispatcher: Dispatcher!

    /// Mock Storage: InMemory
    ///
    private var storageManager: MockStorageManager!

    /// Mock Network: Allows us to inject predefined responses!
    ///
    private var network: MockNetwork!

    /// Convenience Property: Returns the StorageType associated with the main thread.
    ///
    private var viewStorage: StorageType {
        return storageManager.viewStorage
    }

    /// Dummy Site ID
    ///
    private let sampleSiteID: Int64 = 123

    /// Dummy Order ID
    ///
    private let sampleOrderID: Int64 = 963

    /// Dummy author string
    ///
    let sampleAuthor = "someuser"

    /// Dummy author string for an "admin"
    ///
    let sampleAdminAuthor = "someadmin"

    /// Dummy author string for the system
    ///
    let sampleSystemAuthor = "system"


    override func setUp() {
        super.setUp()
        dispatcher = Dispatcher()
        storageManager = MockStorageManager()
        network = MockNetwork()
    }

    /// Verifies that OrderNoteAction.retrieveOrderNotes returns the expected OrderNotes.
    ///
    func testRetrieveOrderNotesReturnsExpectedFields() {
        let expectation = self.expectation(description: "Retrieve order notes")
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)

        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes/", filename: "order-notes")
        let action = OrderNoteAction.retrieveOrderNotes(siteID: sampleSiteID, orderID: sampleOrderID) { (orderNotes, error) in
            XCTAssertNil(error)
            guard let orderNotes = orderNotes else {
                XCTFail()
                return
            }
            XCTAssertEqual(orderNotes.count, 19)
            XCTAssertEqual(orderNotes[0], self.sampleSellerNote())
            XCTAssertEqual(orderNotes[1], self.sampleCustomerNote())
            XCTAssertEqual(orderNotes[2], self.sampleSystemNote())
            expectation.fulfill()
        }

        orderNoteStore.onAction(action)
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `OrderNoteAction.retrieveOrderNotes` effectively persists any retrieved order notes.
    ///
    func testRetrieveOrderNotesEffectivelyPersistsRetrievedOrderNotes() {
        let expectation = self.expectation(description: "Persist order note list")
        let orderStore = OrderStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)

        orderStore.upsertStoredOrder(readOnlyOrder: sampleOrder(), in: viewStorage)
        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes/", filename: "order-notes")
        XCTAssertEqual(viewStorage.countObjects(ofType: Storage.OrderNote.self), 0)
        let action = OrderNoteAction.retrieveOrderNotes(siteID: sampleSiteID, orderID: sampleOrderID) { (orderNotes, error) in
            XCTAssertEqual(self.viewStorage.countObjects(ofType: Storage.OrderNote.self), 19)
            XCTAssertNotNil(orderNotes)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        orderNoteStore.onAction(action)
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `OrderNoteAction.retrieveOrderNotes` effectively persists all of the order note fields.
    ///
    func testRetrieveOrderNotesEffectivelyPersistsOrderNoteFields() {
        let expectation = self.expectation(description: "Persist order note list")
        let orderStore = OrderStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let remoteCustomerNote = sampleCustomerNote()
        let remoteSellerNote = sampleSellerNote()

        orderStore.upsertStoredOrder(readOnlyOrder: sampleOrder(), in: viewStorage)
        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes/", filename: "order-notes")
        XCTAssertEqual(viewStorage.countObjects(ofType: Storage.OrderNote.self), 0)
        let action = OrderNoteAction.retrieveOrderNotes(siteID: sampleSiteID, orderID: sampleOrderID) { (orderNotes, error) in
            XCTAssertNotNil(orderNotes)
            XCTAssertNil(error)

            let customerPredicate = NSPredicate(format: "noteID = %ld", remoteCustomerNote.noteID)
            let storedCustomerNote = self.viewStorage.firstObject(ofType: Storage.OrderNote.self, matching: customerPredicate)
            let readOnlyStoredCustomerNote = storedCustomerNote?.toReadOnly()
            XCTAssertNotNil(storedCustomerNote)
            XCTAssertNotNil(readOnlyStoredCustomerNote)
            XCTAssertEqual(readOnlyStoredCustomerNote, remoteCustomerNote)

            let sellerPredicate = NSPredicate(format: "noteID = %ld", remoteSellerNote.noteID)
            let storedSellerNote = self.viewStorage.firstObject(ofType: Storage.OrderNote.self, matching: sellerPredicate)
            let readOnlyStoredSellerNote = storedSellerNote?.toReadOnly()
            XCTAssertNotNil(storedSellerNote)
            XCTAssertNotNil(readOnlyStoredSellerNote)
            XCTAssertEqual(readOnlyStoredSellerNote, remoteSellerNote)

            expectation.fulfill()
        }

        orderNoteStore.onAction(action)
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `upsertStoredOrderNoteInBackground` does not produce duplicate entries.
    ///
    func testUpdateStoredOrderNoteInBackgroundEffectivelyUpdatesPreexistantOrderNote() {
        let orderStore = OrderStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        orderStore.upsertStoredOrder(readOnlyOrder: sampleOrder(), in: viewStorage)

        XCTAssertNil(viewStorage.firstObject(ofType: Storage.OrderNote.self, matching: nil))

        let group = DispatchGroup()

        group.enter()
        orderNoteStore.upsertStoredOrderNoteInBackground(readOnlyOrderNote: sampleCustomerNote(), orderID: sampleOrderID, siteID: sampleSiteID) {
            group.leave()
        }

        group.enter()
        orderNoteStore.upsertStoredOrderNoteInBackground(readOnlyOrderNote: sampleCustomerNoteMutated(), orderID: sampleOrderID, siteID: sampleSiteID) {
            group.leave()
        }

        let expectation = self.expectation(description: "Stored Order Note")
        group.notify(queue: .main) {
            let expectedOrderNote = self.sampleCustomerNoteMutated()
            let storageOrderNote = self.viewStorage.loadOrderNote(noteID: expectedOrderNote.noteID)
            XCTAssertEqual(storageOrderNote?.toReadOnly(), expectedOrderNote)
            XCTAssert(self.viewStorage.countObjects(ofType: Storage.OrderNote.self, matching: nil) == 1)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `upsertStoredOrderNoteInBackground` effectively inserts a new OrderNote, with the specified payload.
    ///
    func testUpdateStoredOrderNoteInBackgroundEffectivelyPersistsNewOrderNote() {
        let orderStore = OrderStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        orderStore.upsertStoredOrder(readOnlyOrder: sampleOrder(), in: viewStorage)

        let remoteOrderNote = sampleCustomerNote()
        XCTAssertNil(viewStorage.loadAccount(userID: remoteOrderNote.noteID))

        let expectation = self.expectation(description: "Stored Order Note")
        orderNoteStore.upsertStoredOrderNoteInBackground(readOnlyOrderNote: remoteOrderNote, orderID: sampleOrderID, siteID: sampleSiteID) {
            let storageOrderNote = self.viewStorage.loadOrderNote(noteID: remoteOrderNote.noteID)
            XCTAssertEqual(storageOrderNote?.toReadOnly(), remoteOrderNote)
            XCTAssertTrue(Thread.isMainThread)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that OrderNoteAction.retrieveOrderNotes returns an error whenever there is an error response from the backend.
    ///
    func testRetrieveOrderNotesReturnsErrorUponReponseError() {
        let expectation = self.expectation(description: "Retrieve order notes error response")
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)

        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes/", filename: "generic_error")
        let action = OrderNoteAction.retrieveOrderNotes(siteID: sampleSiteID, orderID: sampleOrderID) { (orderNotes, error) in
            XCTAssertNil(orderNotes)
            XCTAssertNotNil(error)
            guard let _ = error else {
                XCTFail()
                return
            }
            expectation.fulfill()
        }

        orderNoteStore.onAction(action)
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that OrderNoteAction.retrieveOrderNotes returns an error whenever there is no backend response.
    ///
    func testRetrieveOrderNotesReturnsErrorUponEmptyResponse() {
        let expectation = self.expectation(description: "Retrieve order notes empty response")
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)

        let action = OrderNoteAction.retrieveOrderNotes(siteID: sampleSiteID, orderID: sampleOrderID) { (orderNotes, error) in
            XCTAssertNotNil(error)
            XCTAssertNil(orderNotes)
            guard let _ = error else {
                XCTFail()
                return
            }
            expectation.fulfill()
        }

        orderNoteStore.onAction(action)
        wait(for: [expectation], timeout: Constants.expectationTimeout)
    }

    /// Verifies that `OrderNoteAction.addOrderNote` returns the expected OrderNote.
    ///
    func test_add_order_note_returns_expected_note() {
        // Given
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes", filename: "new-order-note")

        // When
        let (orderNote, error): (Networking.OrderNote?, Error?) = waitFor { promise in
            let action = OrderNoteAction.addOrderNote(siteID: self.sampleSiteID,
                                                      orderID: self.sampleOrderID,
                                                      isCustomerNote: true,
                                                      note: "This order would be so much better with ketchup.") { (orderNote, error) in
                promise((orderNote, error))
            }
            orderNoteStore.onAction(action)
        }

        // Then
        XCTAssertNotNil(orderNote)
        XCTAssertEqual(orderNote, self.sampleNewNote())
        XCTAssertNil(error)
    }

    /// Verifies that `OrderNoteAction.addOrderNote` effectively persists the new order note.
    ///
    func test_add_order_note_effectively_persists_new_order_note() {
        // Given
        let orderStore = OrderStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        orderStore.upsertStoredOrder(readOnlyOrder: sampleOrder(), in: viewStorage)
        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes", filename: "new-order-note")
        XCTAssertEqual(viewStorage.countObjects(ofType: Storage.OrderNote.self), 0)

        // When
        let (orderNote, error): (Networking.OrderNote?, Error?) = waitFor { promise in
            let action = OrderNoteAction.addOrderNote(siteID: self.sampleSiteID,
                                                      orderID: self.sampleOrderID,
                                                      isCustomerNote: true,
                                                      note: "") { (orderNote, error) in
                promise((orderNote, error))
            }
            orderNoteStore.onAction(action)
        }

        // Then
        XCTAssertNotNil(orderNote)
        XCTAssertEqual(self.viewStorage.countObjects(ofType: Storage.OrderNote.self), 1)
        XCTAssertNil(error)
    }

    /// Verifies that `OrderNoteAction.addOrderNote` returns an error whenever there is an error response from the backend.
    ///
    func test_add_order_note_returns_error_upon_response_error() {
        // Given
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)
        network.simulateResponse(requestUrlSuffix: "orders/\(sampleOrderID)/notes", filename: "generic_error")

        // When
        let (orderNote, error): (Networking.OrderNote?, Error?) = waitFor { promise in
            let action = OrderNoteAction.addOrderNote(siteID: self.sampleSiteID,
                                                      orderID: self.sampleOrderID,
                                                      isCustomerNote: true,
                                                      note: "") { (orderNote, error) in
                promise((orderNote, error))
            }
            orderNoteStore.onAction(action)
        }

        // Then
        XCTAssertNotNil(error)
        XCTAssertNil(orderNote)
    }

    /// Verifies that `OrderNoteAction.addOrderNote` returns an error whenever there is no backend response.
    ///
    func test_add_order_note_returns_error_upon_empty_response() {
        // Given
        let orderNoteStore = OrderNoteStore(dispatcher: dispatcher, storageManager: storageManager, network: network)

        // When
        let (orderNote, error): (Networking.OrderNote?, Error?) = waitFor { promise in
            let action = OrderNoteAction.addOrderNote(siteID: self.sampleSiteID,
                                                      orderID: self.sampleOrderID,
                                                      isCustomerNote: true,
                                                      note: "") { (orderNote, error) in
                promise((orderNote, error))
            }
            orderNoteStore.onAction(action)
        }

        // Then
        XCTAssertNotNil(error)
        XCTAssertNil(orderNote)
    }
}

// MARK: - Private Methods
//
private extension OrderNoteStoreTests {
    func sampleCustomerNote() -> Networking.OrderNote {
        return OrderNote(noteID: 2261,
                         dateCreated: DateFormatter.dateFromString(with: "2018-06-23T17:06:55"),
                         note: "I love your products!",
                         isCustomerNote: true,
                         author: sampleAuthor)
    }

    func sampleCustomerNoteMutated() -> Networking.OrderNote {
        return OrderNote(noteID: 2261,
                         dateCreated: DateFormatter.dateFromString(with: "2018-06-23T18:07:55"),
                         note: "I HATE your products!",
                         isCustomerNote: true,
                         author: sampleAuthor)
    }

    func sampleSellerNote() -> Networking.OrderNote {
        return OrderNote(noteID: 2260,
                         dateCreated: DateFormatter.dateFromString(with: "2018-06-23T16:05:55"),
                         note: "This order is going to be a problem.",
                         isCustomerNote: false,
                         author: sampleAdminAuthor)
    }

    func sampleSystemNote() -> Networking.OrderNote {
        return OrderNote(noteID: 2099,
                         dateCreated: DateFormatter.dateFromString(with: "2018-05-29T03:07:46"),
                         note: "Order status changed from Completed to Processing.",
                         isCustomerNote: false,
                         author: sampleSystemAuthor)
    }

    func sampleNewNote() -> Networking.OrderNote {
        return OrderNote(noteID: 2235,
                         dateCreated: DateFormatter.dateFromString(with: "2018-06-22T15:36:20"),
                         note: "This order would be so much better with ketchup.",
                         isCustomerNote: true,
                         author: sampleAdminAuthor)
    }

    func sampleOrder() -> Networking.Order {
        return Order.fake().copy(siteID: sampleSiteID,
                                 orderID: sampleOrderID,
                                 customerID: 11,
                                 orderKey: "acbd123",
                                 number: "963",
                                 status: .processing,
                                 currency: "USD",
                                 customerNote: "",
                                 dateCreated: DateFormatter.dateFromString(with: "2018-04-03T23:05:12"),
                                 dateModified: DateFormatter.dateFromString(with: "2018-04-03T23:05:14"),
                                 datePaid: DateFormatter.dateFromString(with: "2018-04-03T23:05:14"),
                                 discountTotal: "30.00",
                                 discountTax: "1.20",
                                 shippingTotal: "0.00",
                                 shippingTax: "0.00",
                                 total: "31.20",
                                 totalTax: "1.20",
                                 paymentMethodID: "stripe",
                                 paymentMethodTitle: "Credit Card (Stripe)",
                                 items: [],
                                 billingAddress: sampleAddress(),
                                 shippingAddress: sampleAddress(),
                                 shippingLines: sampleShippingLines())
    }

    func sampleShippingLines() -> [Networking.ShippingLine] {
        return [ShippingLine(shippingID: 123,
        methodTitle: "International Priority Mail Express Flat Rate",
        methodID: "usps",
        total: "133.00",
        totalTax: "0.00",
        taxes: []),
        ]
    }

    func sampleAddress() -> Networking.Address {
        return Address(firstName: "Johnny",
                       lastName: "Appleseed",
                       company: "",
                       address1: "234 70th Street",
                       address2: "",
                       city: "Niagara Falls",
                       state: "NY",
                       postcode: "14304",
                       country: "US",
                       phone: "333-333-3333",
                       email: "scrambled@scrambled.com")
    }

}
