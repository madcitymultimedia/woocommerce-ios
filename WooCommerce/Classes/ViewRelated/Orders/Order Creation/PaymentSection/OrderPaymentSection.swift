import SwiftUI
import Yosemite

/// Represents the Payment section in an order
///
struct OrderPaymentSection: View {
    /// View model to drive the view content
    let viewModel: NewOrderViewModel.PaymentDataViewModel

    /// Indicates if the shipping line details screen should be shown or not.
    ///
    @State private var shouldShowShippingLineDetails: Bool = false

    /// Indicates if the fee line details screen should be shown or not.
    ///
    @State private var shouldShowFeeLineDetails: Bool = false

    ///   Environment safe areas
    ///
    @Environment(\.safeAreaInsets) var safeAreaInsets: EdgeInsets

    var body: some View {
        Divider()

        VStack(alignment: .leading, spacing: .zero) {
            HStack {
                Text(Localization.payment)
                    .accessibilityAddTraits(.isHeader)
                    .headlineStyle()

                Spacer()

                ProgressView()
                    .renderedIf(viewModel.isLoading)
            }
            .padding(.horizontal, insets: safeAreaInsets)
            .padding()

            TitleAndValueRow(title: Localization.productsTotal, value: .content(viewModel.itemsTotal), selectionStyle: .none) {}
                .padding(.horizontal, insets: safeAreaInsets)

            shippingRow
                .sheet(isPresented: $shouldShowShippingLineDetails) {
                    ShippingLineDetails(viewModel: viewModel.shippingLineViewModel)
                }
            feesRow
                .sheet(isPresented: $shouldShowFeeLineDetails) {
                    FeeLineDetails(viewModel: viewModel.feeLineViewModel)
                }

            if viewModel.shouldShowTaxes {
                TitleAndValueRow(title: Localization.taxesTotal, value: .content(viewModel.taxesTotal))
                    .padding(.horizontal, insets: safeAreaInsets)
            }

            TitleAndValueRow(title: Localization.orderTotal, value: .content(viewModel.orderTotal), bold: true, selectionStyle: .none) {}
                .padding(.horizontal, insets: safeAreaInsets)
        }
        .background(Color(.listForeground))

        Divider()
    }

    @ViewBuilder private var shippingRow: some View {
        if viewModel.shouldShowShippingTotal {
            TitleAndValueRow(title: Localization.shippingTotal, value: .content(viewModel.shippingTotal), selectionStyle: .highlight) {
                shouldShowShippingLineDetails = true
            }
            .buttonStyle(BaseButtonRowStyle())
        } else {
            Button(Localization.addShipping) {
                shouldShowShippingLineDetails = true
            }
            .buttonStyle(PlusButtonRowStyle())
        }
    }

    @ViewBuilder private var feesRow: some View {
        if viewModel.shouldShowFees {
            TitleAndValueRow(title: Localization.feesTotal, value: .content(viewModel.feesTotal), selectionStyle: .highlight) {
                shouldShowFeeLineDetails = true
            }
            .buttonStyle(BaseButtonRowStyle())
        } else {
            Button(Localization.addFee) {
                shouldShowFeeLineDetails = true
            }
            .buttonStyle(PlusButtonRowStyle())
        }
    }
}

// MARK: Constants
private extension OrderPaymentSection {
    enum Localization {
        static let payment = NSLocalizedString("Payment", comment: "Title text of the section that shows Payment details when creating a new order")
        static let productsTotal = NSLocalizedString("Products Total", comment: "Label for the row showing the total cost of products in the order")
        static let orderTotal = NSLocalizedString("Order Total", comment: "Label for the the row showing the total cost of the order")
        static let addShipping = NSLocalizedString("Add Shipping", comment: "Title text of the button that adds shipping line when creating a new order")
        static let shippingTotal = NSLocalizedString("Shipping", comment: "Label for the row showing the cost of shipping in the order")
        static let addFee = NSLocalizedString("Add Fee", comment: "Title text of the button that adds a fee when creating a new order")
        static let feesTotal = NSLocalizedString("Fees", comment: "Label for the row showing the cost of fees in the order")
        static let taxesTotal = NSLocalizedString("Taxes", comment: "Label for the row showing the taxes in the order")
    }
}

struct OrderPaymentSection_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = NewOrderViewModel.PaymentDataViewModel(itemsTotal: "20.00", orderTotal: "20.00")

        OrderPaymentSection(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
    }
}
