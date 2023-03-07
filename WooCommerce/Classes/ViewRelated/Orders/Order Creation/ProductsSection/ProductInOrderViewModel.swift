import Yosemite

/// View model for `ProductInOrder`.
///
final class ProductInOrderViewModel: Identifiable {
    /// The product being edited.
    ///
    let productRowViewModel: ProductRowViewModel

    /// Closure invoked when the product is removed.
    ///
    let onRemoveProduct: () -> Void

    init(productRowViewModel: ProductRowViewModel,
         onRemoveProduct: @escaping () -> Void) {
        self.productRowViewModel = productRowViewModel
        self.onRemoveProduct = onRemoveProduct
    }
}
