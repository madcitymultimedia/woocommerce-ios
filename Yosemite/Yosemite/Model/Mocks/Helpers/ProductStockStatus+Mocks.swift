import Foundation

extension ProductStockStatus {
    public static func from(quantity: Decimal) -> ProductStockStatus {
        switch quantity {
            case ..<0:
                return .onBackOrder
            case 0:
                return .outOfStock
            case 1...:
                return .inStock
            default:
                preconditionFailure("Unable to parse quantity")
        }
    }
}
