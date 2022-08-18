import SwiftUI

/// A view to be displayed on Card Reader Manuals screen
///
struct CardReaderManualsView: View {

    let viewModel = CardReaderManualsViewModel()
    var manuals: [Manual] {
        viewModel.manuals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(manuals, id: \.name) { manual in
                    Divider()
                    CardReaderManualRowView(manual: manual)
                        .background(Color(UIColor.listForeground))
                }
                Divider()
            }
        }
        .navigationBarTitle(Localization.navigationTitle, displayMode: .inline)
        .background(Color(UIColor.listBackground))
    }
}

struct CardReadersView_Previews: PreviewProvider {
    static var previews: some View {
        CardReaderManualsView()
    }
}

private extension CardReaderManualsView {
    enum Localization {
        static let navigationTitle = NSLocalizedString( "Card reader manuals",
                                                        comment: "Navigation title at the top of the Card reader manuals screen")
    }
}
