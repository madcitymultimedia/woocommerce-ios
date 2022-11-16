import Foundation

/// Mapper: `Coupon` List
///
struct CouponListMapper: Mapper {
    /// Site we're parsing `Coupon`s for
    /// We're injecting this field by copying it in after parsing responses, because `siteID` is not returned in any of the Coupon endpoints.
    ///
    let siteID: Int64

    /// (Attempts) to convert a dictionary into `[Coupon]`.
    ///
    func map(response: Data) throws -> [Coupon] {
        let coupons: [Coupon]

        do {
            coupons = try Coupon.decoder.decode(CouponListEnvelope.self, from: response).coupons
        } catch {
            coupons = try Coupon.decoder.decode([Coupon].self, from: response)
        }
        return coupons.map { $0.copy(siteID: siteID) }
    }
}


/// CouponListEnvelope Disposable Entity:
/// Load All Coupons endpoint returns the coupons in the `data` key.
/// This entity allows us to parse all the things with JSONDecoder.
///
private struct CouponListEnvelope: Decodable {
    let coupons: [Coupon]

    private enum CodingKeys: String, CodingKey {
        case coupons = "data"
    }
}
