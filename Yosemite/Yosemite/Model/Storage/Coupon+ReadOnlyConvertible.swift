import Foundation
import Storage


// MARK: - Storage.Coupon: ReadOnlyConvertible
//
extension Storage.Coupon: ReadOnlyConvertible {

    /// Updates the `Storage.Coupon` from the ReadOnly representation (`Networking.Coupon`)
    ///
    public func update(with coupon: Yosemite.Coupon) {
        siteID = coupon.siteID
        couponID = coupon.couponID
        code = coupon.code
        amount = coupon.amount
        dateCreated = coupon.dateCreated
        dateModified = coupon.dateModified
        discountType = coupon.discountType.rawValue
        fullDescription = coupon.description
        dateExpires = coupon.dateExpires
        usageCount = coupon.usageCount
        individualUse = coupon.individualUse
        products = coupon.productIds
        excludedProducts = coupon.excludedProductIds
        usageLimit = coupon.usageLimit != nil ? NSNumber(value: coupon.usageLimit!) : nil
        usageLimitPerUser = coupon.usageLimitPerUser != nil ? NSNumber(value: coupon.usageLimitPerUser!) : nil
        limitUsageToXItems = coupon.limitUsageToXItems != nil ? NSNumber(value: coupon.limitUsageToXItems!) : nil
        freeShipping = coupon.freeShipping
        productCategories = coupon.productCategories
        excludedProductCategories = coupon.excludedProductCategories
        excludeSaleItems = coupon.excludeSaleItems
        minimumAmount = coupon.minimumAmount
        maximumAmount = coupon.maximumAmount
        emailRestrictions = coupon.emailRestrictions
        usedBy = coupon.usedBy
    }

    /// Returns a ReadOnly (`Networking.Coupon`) version of the `Storage.Coupon`
    ///
    public func toReadOnly() -> Coupon {
        return Coupon(siteID: siteID,
                      couponID: couponID,
                      code: code ?? "",
                      amount: amount ?? "",
                      dateCreated: dateCreated ?? Date(),
                      dateModified: dateModified ?? Date(),
                      discountType: Coupon.DiscountType(rawValue: discountType ?? "") ?? Coupon.DiscountType.fixedCart,
                      description: fullDescription ?? "",
                      dateExpires: dateExpires,
                      usageCount: usageCount,
                      individualUse: individualUse,
                      productIds: products ?? [],
                      excludedProductIds: excludedProducts ?? [],
                      usageLimit: usageLimit?.int64Value,
                      usageLimitPerUser: usageLimitPerUser?.int64Value,
                      limitUsageToXItems: limitUsageToXItems?.int64Value,
                      freeShipping: freeShipping,
                      productCategories: productCategories ?? [],
                      excludedProductCategories: excludedProductCategories ?? [],
                      excludeSaleItems: excludeSaleItems,
                      minimumAmount: minimumAmount ?? "",
                      maximumAmount: maximumAmount ?? "",
                      emailRestrictions: emailRestrictions ?? [],
                      usedBy: usedBy ?? [])
    }
}
