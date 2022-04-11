import XCTest
@testable import WooCommerce
import Yosemite

final class NewOrderViewModelTests: XCTestCase {

    let sampleSiteID: Int64 = 123
    let sampleProductID: Int64 = 5

    func test_view_model_inits_with_expected_values() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)

        // When
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // Then
        XCTAssertEqual(viewModel.navigationTrailingItem, .create)
        XCTAssertEqual(viewModel.statusBadgeViewModel.title, "pending")
        XCTAssertEqual(viewModel.productRows.count, 0)
    }

    func test_loading_indicator_is_enabled_during_network_request() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        let navigationItem: NewOrderViewModel.NavigationItem = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createOrder:
                    promise(viewModel.navigationTrailingItem)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            viewModel.createOrder()
        }

        // Then
        XCTAssertEqual(navigationItem, .loading)
    }

    func test_view_is_disabled_during_network_request() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        let isViewDisabled: Bool = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createOrder:
                    promise(viewModel.disabled)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            viewModel.createOrder()
        }

        // Then
        XCTAssertTrue(isViewDisabled)
    }

    func test_create_button_is_enabled_after_the_network_operation_completes() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        viewModel.updateOrderStatus(newStatus: .processing)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .createOrder(_, order, onCompletion):
                onCompletion(.success(order))
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }
        viewModel.createOrder()

        // Then
        XCTAssertEqual(viewModel.navigationTrailingItem, .create)
    }

    func test_view_model_fires_error_notice_when_order_creation_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .createOrder(_, _, onCompletion):
                onCompletion(.failure(NSError(domain: "Error", code: 0)))
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }
        viewModel.createOrder()

        // Then
        XCTAssertEqual(viewModel.notice, NewOrderViewModel.NoticeFactory.createOrderErrorNotice())
    }

    func test_view_model_fires_error_notice_when_order_sync_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let synchronizer = RemoteOrderSynchronizer(siteID: sampleSiteID, stores: stores)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        waitForExpectation { expectation in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .createOrder(_, _, onCompletion):
                    onCompletion(.failure(NSError(domain: "Error", code: 0)))
                    expectation.fulfill()
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }

            // When remote sync is triggered
            viewModel.saveShippingLine(ShippingLine.fake())
        }

        // Then
        XCTAssertEqual(viewModel.notice, NewOrderViewModel.NoticeFactory.syncOrderErrorNotice(with: synchronizer))
    }

    func test_view_model_clears_error_notice_when_order_is_syncing() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)
        viewModel.notice = NewOrderViewModel.NoticeFactory.createOrderErrorNotice()

        // When
        let notice: Notice? = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createOrder:
                    promise(viewModel.notice)
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            // Remote sync is triggered
            viewModel.saveShippingLine(ShippingLine.fake())
        }

        // Then
        XCTAssertNil(notice)
    }

    func test_view_model_loads_synced_pending_order_status() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let storageManager = MockStorageManager()
        storageManager.insertOrderStatus(.init(name: "Pending payment", siteID: sampleSiteID, slug: "pending", total: 0))

        // When
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores, storageManager: storageManager)

        // Then
        XCTAssertEqual(viewModel.statusBadgeViewModel.title, "Pending payment")
    }

    func test_view_model_is_updated_when_order_status_updated() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let storageManager = MockStorageManager()
        storageManager.insertOrderStatus(.init(name: "Pending payment", siteID: sampleSiteID, slug: "pending", total: 0))
        storageManager.insertOrderStatus(.init(name: "Processing", siteID: sampleSiteID, slug: "processing", total: 0))

        // When
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores, storageManager: storageManager)

        // Then
        XCTAssertEqual(viewModel.statusBadgeViewModel.title, "Pending payment")

        // When
        viewModel.updateOrderStatus(newStatus: .processing)

        // Then
        XCTAssertEqual(viewModel.statusBadgeViewModel.title, "Processing")
    }

    func test_view_model_is_updated_when_product_is_added_to_order() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)

        // Then
        XCTAssertTrue(viewModel.productRows.contains(where: { $0.productOrVariationID == sampleProductID }), "Product rows do not contain expected product")
    }

    func test_order_details_are_updated_when_product_quantity_changes() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)
        viewModel.productRows[0].incrementQuantity()

        // And when another product is added to the order (to confirm the first product's quantity change is retained)
        viewModel.addProductViewModel.selectProduct(product.productID)

        // Then
        XCTAssertEqual(viewModel.productRows[safe: 0]?.quantity, 2)
        XCTAssertEqual(viewModel.productRows[safe: 1]?.quantity, 1)
    }

    func test_product_is_selected_when_quantity_is_decremented_below_1() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // Product quantity is 1
        viewModel.addProductViewModel.selectProduct(product.productID)
        XCTAssertEqual(viewModel.productRows[0].quantity, 1)

        // When
        viewModel.productRows[0].decrementQuantity()

        // Then
        XCTAssertNotNil(viewModel.selectedProductViewModel)
    }

    func test_selectOrderItem_selects_expected_order_item() throws {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)
        viewModel.addProductViewModel.selectProduct(product.productID)

        // When
        let expectedRow = viewModel.productRows[0]
        viewModel.selectOrderItem(expectedRow.id)

        // Then
        XCTAssertNotNil(viewModel.selectedProductViewModel)
        XCTAssertEqual(viewModel.selectedProductViewModel?.productRowViewModel.id, expectedRow.id)
    }

    func test_view_model_is_updated_when_product_is_removed_from_order() {
        // Given
        let product0 = Product.fake().copy(siteID: sampleSiteID, productID: 0, purchasable: true)
        let product1 = Product.fake().copy(siteID: sampleSiteID, productID: 1, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertProducts([product0, product1])
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // Given products are added to order
        viewModel.addProductViewModel.selectProduct(product0.productID)
        viewModel.addProductViewModel.selectProduct(product1.productID)

        // When
        let expectedRemainingRow = viewModel.productRows[1]
        let itemToRemove = OrderItem.fake().copy(itemID: viewModel.productRows[0].id)
        viewModel.removeItemFromOrder(itemToRemove)

        // Then
        XCTAssertFalse(viewModel.productRows.contains(where: { $0.productOrVariationID == product0.productID }))
        XCTAssertEqual(viewModel.productRows.map { $0.id }, [expectedRemainingRow].map { $0.id })
    }

    func test_createProductRowViewModel_creates_expected_row_for_product() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        let orderItem = OrderItem.fake().copy(name: product.name, productID: product.productID, quantity: 1)
        let productRow = viewModel.createProductRowViewModel(for: orderItem, canChangeQuantity: true)

        // Then
        let expectedProductRow = ProductRowViewModel(product: product, canChangeQuantity: true)
        XCTAssertEqual(productRow?.name, expectedProductRow.name)
        XCTAssertEqual(productRow?.quantity, expectedProductRow.quantity)
        XCTAssertEqual(productRow?.canChangeQuantity, expectedProductRow.canChangeQuantity)
    }

    func test_createProductRowViewModel_creates_expected_row_for_product_variation() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, productTypeKey: "variable", variations: [33])
        let productVariation = ProductVariation.fake().copy(siteID: sampleSiteID,
                                                            productID: sampleProductID,
                                                            productVariationID: 33,
                                                            sku: "product-variation")
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        storageManager.insertSampleProductVariation(readOnlyProductVariation: productVariation, on: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        let orderItem = OrderItem.fake().copy(name: product.name,
                                              productID: product.productID,
                                              variationID: productVariation.productVariationID,
                                              quantity: 2)
        let productRow = viewModel.createProductRowViewModel(for: orderItem, canChangeQuantity: false)

        // Then
        let expectedProductRow = ProductRowViewModel(productVariation: productVariation,
                                                     name: product.name,
                                                     quantity: 2,
                                                     canChangeQuantity: false,
                                                     displayMode: .stock)
        XCTAssertEqual(productRow?.name, expectedProductRow.name)
        XCTAssertEqual(productRow?.skuLabel, expectedProductRow.skuLabel)
        XCTAssertEqual(productRow?.quantity, expectedProductRow.quantity)
        XCTAssertEqual(productRow?.canChangeQuantity, expectedProductRow.canChangeQuantity)
    }

    func test_view_model_is_updated_when_address_updated() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)
        XCTAssertFalse(viewModel.customerDataViewModel.isDataAvailable)

        // When
        viewModel.addressFormViewModel.fields.firstName = sampleAddress1().firstName
        viewModel.addressFormViewModel.fields.lastName = sampleAddress1().lastName
        viewModel.addressFormViewModel.saveAddress(onFinish: { _ in })

        // Then
        XCTAssertTrue(viewModel.customerDataViewModel.isDataAvailable)
        XCTAssertEqual(viewModel.customerDataViewModel.fullName, sampleAddress1().fullName)
    }

    func test_customer_data_view_model_is_initialized_correctly_from_addresses() {
        // Given
        let sampleAddressWithoutNameAndEmail = sampleAddress2()

        // When
        let customerDataViewModel = NewOrderViewModel.CustomerDataViewModel(billingAddress: sampleAddressWithoutNameAndEmail,
                                                                            shippingAddress: nil)

        // Then
        XCTAssertTrue(customerDataViewModel.isDataAvailable)
        XCTAssertNil(customerDataViewModel.fullName)
        XCTAssertNotNil(customerDataViewModel.billingAddressFormatted)
        XCTAssertNil(customerDataViewModel.shippingAddressFormatted)
    }

    func test_customer_data_view_model_is_initialized_correctly_from_empty_input() {
        // Given
        let customerDataViewModel = NewOrderViewModel.CustomerDataViewModel(billingAddress: Address.empty, shippingAddress: Address.empty)

        // Then
        XCTAssertFalse(customerDataViewModel.isDataAvailable)
        XCTAssertNil(customerDataViewModel.fullName)
        XCTAssertEqual(customerDataViewModel.billingAddressFormatted, "")
        XCTAssertEqual(customerDataViewModel.shippingAddressFormatted, "")
    }

    func test_customer_data_view_model_is_initialized_correctly_with_only_phone() {
        // Given
        let addressWithOnlyPhone = Address.fake().copy(phone: "123-456-7890")

        // When
        let customerDataViewModel = NewOrderViewModel.CustomerDataViewModel(billingAddress: addressWithOnlyPhone, shippingAddress: Address.empty)

        // Then
        XCTAssertTrue(customerDataViewModel.isDataAvailable)
        XCTAssertNil(customerDataViewModel.fullName)
        XCTAssertEqual(customerDataViewModel.billingAddressFormatted, "")
        XCTAssertEqual(customerDataViewModel.shippingAddressFormatted, "")
    }

    func test_payment_data_view_model_is_initialized_with_expected_values() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)

        // When
        let paymentDataViewModel = NewOrderViewModel.PaymentDataViewModel(itemsTotal: "20.00",
                                                                          shippingTotal: "3.00",
                                                                          feesTotal: "2.00",
                                                                          taxesTotal: "5.00",
                                                                          orderTotal: "30.00",
                                                                          currencyFormatter: CurrencyFormatter(currencySettings: currencySettings))

        // Then
        XCTAssertEqual(paymentDataViewModel.itemsTotal, "£20.00")
        XCTAssertEqual(paymentDataViewModel.shippingTotal, "£3.00")
        XCTAssertEqual(paymentDataViewModel.feesTotal, "£2.00")
        XCTAssertEqual(paymentDataViewModel.taxesTotal, "£5.00")
        XCTAssertEqual(paymentDataViewModel.orderTotal, "£30.00")
    }

    // MARK: - Payment Section Tests

    func test_payment_section_is_updated_when_products_update() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When & Then
        viewModel.addProductViewModel.selectProduct(product.productID)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£8.50")

        // When & Then
        viewModel.productRows[0].incrementQuantity()
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£17.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£17.00")
    }

    func test_payment_section_is_updated_when_shipping_line_updated() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)
        let testShippingLine = ShippingLine(shippingID: 0,
                                            methodTitle: "Flat Rate",
                                            methodID: "other",
                                            total: "10",
                                            totalTax: "",
                                            taxes: [])
        viewModel.saveShippingLine(testShippingLine)

        // Then
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "£10.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£18.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 18.50)

        // When
        viewModel.saveShippingLine(nil)

        // Then
        XCTAssertFalse(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "£0.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)
    }

    func test_payment_section_is_updated_when_fee_line_updated() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)
        let testFeeLine = OrderFeeLine(feeID: 0,
                                       name: "Fee",
                                       taxClass: "",
                                       taxStatus: .none,
                                       total: "10",
                                       totalTax: "",
                                       taxes: [],
                                       attributes: [])
        viewModel.saveFeeLine(testFeeLine)

        // Then
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowFees)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "£10.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£18.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)

        // When
        viewModel.saveFeeLine(nil)

        // Then
        XCTAssertFalse(viewModel.paymentDataViewModel.shouldShowFees)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "£0.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)
    }

    func test_payment_section_values_correct_when_shipping_line_is_negative() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)
        let testShippingLine = ShippingLine(shippingID: 0,
                                            methodTitle: "Flat Rate",
                                            methodID: "other",
                                            total: "-5",
                                            totalTax: "",
                                            taxes: [])
        viewModel.saveShippingLine(testShippingLine)

        // Then
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "-£5.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£3.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 3.50)

        // When
        viewModel.saveShippingLine(nil)

        // Then
        XCTAssertFalse(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "£0.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)
    }

    func test_payment_section_values_correct_when_fee_line_is_negative() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)
        let testFeeLine = OrderFeeLine(feeID: 0,
                                       name: "Fee",
                                       taxClass: "",
                                       taxStatus: .none,
                                       total: "-5",
                                       totalTax: "",
                                       taxes: [],
                                       attributes: [])
        viewModel.saveFeeLine(testFeeLine)

        // Then
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowFees)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "-£5.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£3.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)

        // When
        viewModel.saveFeeLine(nil)

        // Then
        XCTAssertFalse(viewModel.paymentDataViewModel.shouldShowFees)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "£0.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)
    }

    func test_payment_section_is_correct_when_shipping_line_and_fee_line_are_added() {
        // Given
        let currencySettings = CurrencySettings(currencyCode: .GBP, currencyPosition: .left, thousandSeparator: "", decimalSeparator: ".", numberOfDecimals: 2)
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, price: "8.50", purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager, currencySettings: currencySettings)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)

        let testShippingLine = ShippingLine(shippingID: 0,
                                            methodTitle: "Flat Rate",
                                            methodID: "other",
                                            total: "-5",
                                            totalTax: "",
                                            taxes: [])
        viewModel.saveShippingLine(testShippingLine)

        let testFeeLine = OrderFeeLine(feeID: 0,
                                       name: "Fee",
                                       taxClass: "",
                                       taxStatus: .none,
                                       total: "10",
                                       totalTax: "",
                                       taxes: [],
                                       attributes: [])
        viewModel.saveFeeLine(testFeeLine)

        // Then
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "-£5.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£13.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "£10.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 3.50)

        // When
        viewModel.saveShippingLine(nil)

        // Then
        XCTAssertFalse(viewModel.paymentDataViewModel.shouldShowShippingTotal)
        XCTAssertEqual(viewModel.paymentDataViewModel.itemsTotal, "£8.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.shippingTotal, "£0.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.orderTotal, "£18.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesTotal, "£10.00")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 8.50)
    }

    func test_payment_section_loading_indicator_is_enabled_while_order_syncs() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // When
        let isLoadingDuringSync: Bool = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case let .createOrder(_, _, onCompletion):
                    promise(viewModel.paymentDataViewModel.isLoading)
                    onCompletion(.success(.fake()))
                default:
                    XCTFail("Received unsupported action: \(action)")
                }
            }
            // Trigger remote sync
            viewModel.saveShippingLine(ShippingLine.fake())
        }

        // Then
        XCTAssertTrue(isLoadingDuringSync)
        XCTAssertFalse(viewModel.paymentDataViewModel.isLoading) // Disabled after sync ends
    }

    func test_payment_section_is_updated_when_order_has_taxes() {
        // Given
        let expectation = expectation(description: "Order with taxes is synced")
        let currencySettings = CurrencySettings()
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores, currencySettings: currencySettings)

        // When
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            switch action {
            case let .createOrder(_, _, onCompletion):
                let order = Order.fake().copy(siteID: self.sampleSiteID, totalTax: "2.50")
                onCompletion(.success(order))
                expectation.fulfill()
            default:
                XCTFail("Received unsupported action: \(action)")
            }
        }
        // Trigger remote sync
        viewModel.saveShippingLine(ShippingLine.fake())

        // Then
        waitForExpectations(timeout: Constants.expectationTimeout, handler: nil)
        XCTAssertTrue(viewModel.paymentDataViewModel.shouldShowTaxes)
        XCTAssertEqual(viewModel.paymentDataViewModel.taxesTotal, "$2.50")
        XCTAssertEqual(viewModel.paymentDataViewModel.feesBaseAmountForPercentage, 2.50)

    }

    // MARK: - hasChanges Tests

    func test_hasChanges_returns_false_initially() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)

        // When
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // Then
        XCTAssertFalse(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_product_quantity_changes() {
        // Given
        let product = Product.fake().copy(siteID: sampleSiteID, productID: sampleProductID, purchasable: true)
        let storageManager = MockStorageManager()
        storageManager.insertSampleProduct(readOnlyProduct: product)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.addProductViewModel.selectProduct(product.productID)

        // Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_order_status_is_updated() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.updateOrderStatus(newStatus: .completed)

        // Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_customer_information_is_updated() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        // When
        viewModel.addressFormViewModel.fields.firstName = sampleAddress1().firstName
        viewModel.addressFormViewModel.fields.lastName = sampleAddress1().lastName
        viewModel.addressFormViewModel.saveAddress(onFinish: { _ in })

        // Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_customer_note_is_updated() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)

        //When
        viewModel.noteViewModel.newNote = "Test"
        viewModel.updateCustomerNote()

        //Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_shipping_line_is_updated() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)
        let shippingLine = ShippingLine.fake()

        // When
        viewModel.saveShippingLine(shippingLine)

        // Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    func test_hasChanges_returns_true_when_fee_line_is_updated() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)
        let feeLine = OrderFeeLine.fake()

        // When
        viewModel.saveFeeLine(feeLine)

        // Then
        XCTAssertTrue(viewModel.hasChanges)
    }

    // MARK: - Tracking Tests

    func test_shipping_method_tracked_when_added() throws {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))
        let shippingLine = ShippingLine.fake()

        // When
        viewModel.saveShippingLine(shippingLine)

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderShippingMethodAdd.rawValue])

        let properties = try XCTUnwrap(analytics.receivedProperties.first?["flow"] as? String)
        XCTAssertEqual(properties, "creation")
    }

    func test_shipping_method_not_tracked_when_removed() {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.saveShippingLine(nil)

        // Then
        XCTAssertTrue(analytics.receivedEvents.isEmpty)
    }

    func test_fee_line_tracked_when_added() throws {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))
        let feeLine = OrderFeeLine.fake()

        // When
        viewModel.saveFeeLine(feeLine)

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderFeeAdd.rawValue])

        let properties = try XCTUnwrap(analytics.receivedProperties.first?["flow"] as? String)
        XCTAssertEqual(properties, "creation")
    }

    func test_fee_line_not_tracked_when_removed() {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.saveFeeLine(nil)

        // Then
        XCTAssertTrue(analytics.receivedEvents.isEmpty)
    }

    func test_customer_details_tracked_when_added() throws {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.addressFormViewModel.fields.address1 = sampleAddress1().address1
        viewModel.addressFormViewModel.showDifferentAddressForm = true
        viewModel.addressFormViewModel.saveAddress(onFinish: { _ in })

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderCustomerAdd.rawValue])

        let flowProperty = try XCTUnwrap(analytics.receivedProperties.first?["flow"] as? String)
        let hasDifferentShippingDetailsProperty = try XCTUnwrap(analytics.receivedProperties.first?["has_different_shipping_details"] as? Bool)
        XCTAssertEqual(flowProperty, "creation")
        XCTAssertTrue(hasDifferentShippingDetailsProperty)
    }

    func test_customer_details_not_tracked_when_removed() {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.addressFormViewModel.fields.address1 = ""
        viewModel.addressFormViewModel.saveAddress(onFinish: { _ in })

        // Then
        XCTAssertTrue(analytics.receivedEvents.isEmpty)
    }

    func test_customer_note_tracked_when_added() throws {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.noteViewModel.newNote = "Test"
        viewModel.updateCustomerNote()

        // Then
        XCTAssertEqual(analytics.receivedEvents, [WooAnalyticsStat.orderNoteAdd.rawValue])

        let properties = try XCTUnwrap(analytics.receivedProperties.first?["flow"] as? String)
        XCTAssertEqual(properties, "creation")
    }

    func test_customer_note_not_tracked_when_removed() {
        // Given
        let analytics = MockAnalyticsProvider()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, analytics: WooAnalytics(analyticsProvider: analytics))

        // When
        viewModel.noteViewModel.newNote = ""
        viewModel.updateCustomerNote()

        // Then
        XCTAssertTrue(analytics.receivedEvents.isEmpty)
    }

    // MARK: -

    func test_customer_note_section_is_updated_when_note_is_added_to_order() {
        // Given
        let storageManager = MockStorageManager()
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, storageManager: storageManager)
        let expectedCustomerNote = "Test"

        //When
        viewModel.noteViewModel.newNote = expectedCustomerNote
        viewModel.updateCustomerNote()

        //Then
        XCTAssertEqual(viewModel.customerNoteDataViewModel.customerNote, expectedCustomerNote)
    }

    func test_discard_order_deletes_order_if_order_exists_remotely() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)
        waitForExpectation { expectation in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .createOrder(_, let order, let completion):
                    completion(.success(order.copy(orderID: 12)))
                    expectation.fulfill()
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }
            // Trigger remote sync
            viewModel.saveShippingLine(ShippingLine.fake())
        }

        // When
        let orderDeleted: Bool = waitFor { promise in
            stores.whenReceivingAction(ofType: OrderAction.self) { action in
                switch action {
                case .deleteOrder:
                    promise(true)
                default:
                    XCTFail("Unexpected action: \(action)")
                }
            }
            viewModel.discardOrder()
        }

        // Then
        XCTAssertTrue(orderDeleted)
    }

    func test_discard_order_skips_remote_deletion_for_local_order() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)
        stores.whenReceivingAction(ofType: OrderAction.self) { action in
            XCTFail("Unexpected action: \(action)")
        }

        // When
        viewModel.discardOrder()
    }

    func test_resetAddressForm_discards_pending_address_field_changes() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = NewOrderViewModel(siteID: sampleSiteID, stores: stores)

        // Given there is a saved change and a pending change
        viewModel.addressFormViewModel.fields.firstName = sampleAddress1().firstName
        viewModel.addressFormViewModel.saveAddress(onFinish: { _ in })
        viewModel.addressFormViewModel.fields.lastName = sampleAddress1().lastName

        // When
        viewModel.resetAddressForm()

        // Then
        XCTAssertEqual(viewModel.addressFormViewModel.fields.firstName, sampleAddress1().firstName,
                       "Saved change was unexpectedly discarded when address form was reset")
        XCTAssertEqual(viewModel.addressFormViewModel.fields.lastName, "",
                       "Pending change was not discarded when address form was reset")
    }
}

private extension MockStorageManager {

    func insertOrderStatus(_ readOnlyOrderStatus: OrderStatus) {
        let orderStatus = viewStorage.insertNewObject(ofType: StorageOrderStatus.self)
        orderStatus.update(with: readOnlyOrderStatus)
        viewStorage.saveIfNeeded()
    }

    func insertProducts(_ readOnlyProducts: [Product]) {
        for readOnlyProduct in readOnlyProducts {
            let product = viewStorage.insertNewObject(ofType: StorageProduct.self)
            product.update(with: readOnlyProduct)
            viewStorage.saveIfNeeded()
        }
    }
}

private extension NewOrderViewModelTests {
    func sampleAddress1() -> Address {
        return Address(firstName: "Johnny",
                       lastName: "Appleseed",
                       company: nil,
                       address1: "234 70th Street",
                       address2: nil,
                       city: "Niagara Falls",
                       state: "NY",
                       postcode: "14304",
                       country: "US",
                       phone: "333-333-3333",
                       email: "scrambled@scrambled.com")
    }

    func sampleAddress2() -> Address {
        return Address(firstName: "",
                       lastName: "",
                       company: "Automattic",
                       address1: "234 70th Street",
                       address2: nil,
                       city: "Niagara Falls",
                       state: "NY",
                       postcode: "14304",
                       country: "US",
                       phone: "333-333-3333",
                       email: "")
    }
}
