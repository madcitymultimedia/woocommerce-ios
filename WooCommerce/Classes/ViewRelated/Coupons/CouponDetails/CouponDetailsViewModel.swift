import Foundation
import Yosemite

/// View model for `CouponDetails` view
///
final class CouponDetailsViewModel: ObservableObject {
    /// Code of the coupon
    ///
    @Published private(set) var couponCode: String = ""

    /// Description of the coupon
    ///
    @Published private(set) var description: String = ""

    /// Amount of the coupon
    ///
    @Published private(set) var amount: String = ""

    /// Product limit for the coupon to be applied to
    ///
    @Published private(set) var productsAppliedTo: String = ""

    /// Expiry date of the coupon
    ///
    @Published private(set) var expiryDate: String = ""

    /// The message to be shared about the coupon
    ///
    var shareMessage: String {
        if coupon.productIds.isNotEmpty ||
            coupon.productCategories.isNotEmpty ||
            coupon.excludedProductIds.isNotEmpty ||
            coupon.excludedProductCategories.isNotEmpty {
            return String.localizedStringWithFormat(Localization.shareMessageSomeProducts, amount, couponCode)
        }
        return String.localizedStringWithFormat(Localization.shareMessageAllProducts, amount, couponCode)
    }

    /// Total number of orders that applied the coupon
    ///
    @Published private(set) var discountedOrdersCount: String = "0"

    /// Total amount deducted from orders that applied the coupon
    ///
    @Published private(set) var discountedAmount: String?

    /// The current coupon
    ///
    @Published private(set) var coupon: Coupon {
        didSet {
            populateDetails()
        }
    }

    private let stores: StoresManager
    private let currencySettings: CurrencySettings

    init(coupon: Coupon,
         stores: StoresManager = ServiceLocator.stores,
         currencySettings: CurrencySettings = ServiceLocator.currencySettings) {
        self.coupon = coupon
        self.stores = stores
        self.currencySettings = currencySettings
        populateDetails()
    }

    func syncCoupon() {
        let action = CouponAction.retrieveCoupon(siteID: coupon.siteID, couponID: coupon.couponID) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let coupon):
                self.coupon = coupon
            case .failure(let error):
                DDLogError("⛔️ Error synchronizing coupon detail: \(error)")
            }
        }
        stores.dispatch(action)
    }

    func loadCouponReport() {
        // Get "ancient" date to fetch all possible reports
        let startDate = Date(timeIntervalSince1970: 1)
        let action = CouponAction.loadCouponReport(siteID: coupon.siteID, couponID: coupon.couponID, startDate: startDate) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let report):
                self.discountedOrdersCount = "\(report.ordersCount)"
                self.discountedAmount = self.formatStringAmount("\(report.amount)")
            case .failure(let error):
                DDLogError("⛔️ Error loading coupon report: \(error)")
            }
        }
        stores.dispatch(action)
    }
}

// MARK: - Private helpers
//
private extension CouponDetailsViewModel {

    func populateDetails() {
        couponCode = coupon.code
        description = coupon.description
        discountedOrdersCount = "\(coupon.usageCount)"
        if coupon.usageCount == 0 {
            discountedAmount = formatStringAmount("0")
        }

        switch coupon.discountType {
        case .percent:
            let percentFormatter = NumberFormatter()
            percentFormatter.numberStyle = .percent
            if let amountDouble = Double(coupon.amount) {
                let amountNumber = NSNumber(value: amountDouble / 100)
                amount = percentFormatter.string(from: amountNumber) ?? ""
            }
        case .fixedCart, .fixedProduct:
            amount = formatStringAmount(coupon.amount)
        case .other:
            amount = coupon.amount
        }

        productsAppliedTo = localizeApplyRules(productsCount: coupon.productIds.count,
                                               excludedProductsCount: coupon.excludedProductIds.count,
                                               categoriesCount: coupon.productCategories.count,
                                               excludedCategoriesCount: coupon.excludedProductCategories.count)

        expiryDate = coupon.dateExpires?.toString(dateStyle: .long, timeStyle: .none) ?? ""
    }

    func formatStringAmount(_ amount: String) -> String {
        let currencyFormatter = CurrencyFormatter(currencySettings: currencySettings)
        return currencyFormatter.formatAmount(amount) ?? ""
    }

    /// Localize content for the "Apply to" field. This takes into consideration different cases of apply rules:
    ///    - When only specific products or categories are defined: Display "x Products" or "x Categories"
    ///    - When specific products/categories and exceptions are defined: Display "x Products excl. y Categories" etc.
    ///    - When both specific products and categories are defined: Display "x Products and y Categories"
    ///    - When only exceptions are defined: Display "All excl. x Products" or "All excl. y Categories"
    ///
    func localizeApplyRules(productsCount: Int, excludedProductsCount: Int, categoriesCount: Int, excludedCategoriesCount: Int) -> String {
        let productText = String.pluralize(productsCount, singular: Localization.singleProduct, plural: Localization.multipleProducts)
        let productExceptionText = String.pluralize(excludedProductsCount, singular: Localization.singleProduct, plural: Localization.multipleProducts)
        let categoryText = String.pluralize(categoriesCount, singular: Localization.singleCategory, plural: Localization.multipleCategories)
        let categoryExceptionText = String.pluralize(excludedCategoriesCount, singular: Localization.singleCategory, plural: Localization.multipleCategories)

        switch (productsCount, excludedProductsCount, categoriesCount, excludedCategoriesCount) {
        case let (products, _, categories, _) where products > 0 && categories > 0:
            return String.localizedStringWithFormat(Localization.combinedRules, productText, categoryText)
        case let (products, excludedProducts, _, _) where products > 0 && excludedProducts > 0:
            return String.localizedStringWithFormat(Localization.ruleWithException, productText, productExceptionText)
        case let (products, _, _, excludedCategories) where products > 0 && excludedCategories > 0:
            return String.localizedStringWithFormat(Localization.ruleWithException, productText, categoryExceptionText)
        case let (products, _, _, _) where products > 0:
            return productText
        case let (_, excludedProducts, categories, _) where excludedProducts > 0 && categories > 0:
            return String.localizedStringWithFormat(Localization.ruleWithException, categoryText, productExceptionText)
        case let (_, _, categories, excludedCategories) where categories > 0 && excludedCategories > 0:
            return String.localizedStringWithFormat(Localization.ruleWithException, categoryText, categoryExceptionText)
        case let (_, _, categories, _) where categories > 0:
            return categoryText
        case let (_, excludedProducts, _, _) where excludedProducts > 0:
            return String.localizedStringWithFormat(Localization.allWithException, productExceptionText)
        case let (_, _, _, excludedCategories) where excludedCategories > 0:
            return String.localizedStringWithFormat(Localization.allWithException, categoryExceptionText)
        default:
            return Localization.allProducts
        }
    }
}

// MARK: - Subtypes
//
private extension CouponDetailsViewModel {
    enum Localization {
        static let shareMessageAllProducts = NSLocalizedString(
            "Apply %1$@ off to all products with the promo code “%2$@”.",
            comment: "Message to share the coupon code if it is applicable to all products. " +
            "Reads like: Apply 10% off to all products with the promo code “20OFF”.")
        static let shareMessageSomeProducts = NSLocalizedString(
            "Apply %1$@ off to some products with the promo code “%2$@”.",
            comment: "Message to share the coupon code if it is applicable to some products. " +
            "Reads like: Apply 10% off to some products with the promo code “20OFF”.")
        static let allProducts = NSLocalizedString("All Products", comment: "The text to be displayed in when the coupon is not limit to any specific product")
        static let singleProduct = NSLocalizedString(
            "%1$d Product",
            comment: "The number of products allowed for a coupon in singular form. Reads like: 1 Product"
        )
        static let multipleProducts = NSLocalizedString(
            "%1$d Products",
            comment: "The number of products allowed for a coupon in plural form. " +
            "Reads like: 10 Products"
        )
        static let singleCategory = NSLocalizedString(
            "%1$d Category",
            comment: "The number of category allowed for a coupon in singular form. Reads like: 1 Category"
        )
        static let multipleCategories = NSLocalizedString(
            "%1$d Categories",
            comment: "The number of category allowed for a coupon in plural form. " +
            "Reads like: 10 Categories"
        )
        static let allWithException = NSLocalizedString("All excl. %1$@", comment: "Exception rule for a coupon. Reads like: All excl. 2 Products")
        static let ruleWithException = NSLocalizedString("%1$@ excl. %2$@", comment: "Exception rule for a coupon. Reads like: 3 Products excl. 1 Category")
        static let combinedRules = NSLocalizedString("%1$@ and %2$@", comment: "Combined rule for a coupon. Reads like: 2 Products and 1 Category")
    }
}
