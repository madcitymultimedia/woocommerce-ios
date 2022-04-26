import Foundation

public enum FeedbackType: String, Codable {
    /// Identifier for the general inApp feedback survey
    ///
    case general

    /// Identifier for the Products Variations.
    ///
    case productsVariations

    /// identifier for the shipping labels m3 feedback survey
    ///
    case shippingLabelsRelease3

    /// Identifier for the coupon management feedback survey
    ///
    case couponManagement

    /// Identifier for the orders creation feedback survey
    ///
    case ordersCreation
}
