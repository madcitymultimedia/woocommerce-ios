import SwiftUI
import struct Yosemite.StoreOnboardingTask

/// Shows a tappable onboarding task to set up the store. If the task is complete, a checkmark is shown.
struct StoreOnboardingTaskView: View {
    private let viewModel: StoreOnboardingTaskViewModel
    private let showDivider: Bool
    private let isRedacted: Bool
    private let onTap: (StoreOnboardingTask) -> Void

    init(viewModel: StoreOnboardingTaskViewModel,
         showDivider: Bool,
         isRedacted: Bool,
         onTap: @escaping (StoreOnboardingTask) -> Void) {
        self.viewModel = viewModel
        self.showDivider = showDivider
        self.isRedacted = isRedacted
        self.onTap = onTap
    }

    /// Scale of the view based on accessibility changes.
    @ScaledMetric private var scale: CGFloat = 1.0

    var body: some View {
        Button {
            onTap(viewModel.task)
        } label: {
            HStack(alignment: .center, spacing: Layout.horizontalSpacing) {
                // Check icon or task icon.
                Image(uiImage: viewModel.isComplete ? .checkCircleImage : viewModel.icon)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundColor(.init(uiColor: viewModel.isComplete ? .accent : .text))
                    .frame(width: scale * Layout.imageDimension,
                           height: scale * Layout.imageDimension)
                    .redacted(reason: isRedacted ? .placeholder : [])

                VStack(alignment: .leading, spacing: Layout.verticalSpacing) {
                    HStack {
                        // Task labels
                        VStack(alignment: .leading, spacing: Layout.verticalSpacing) {
                            Spacer().frame(height: Layout.spacerHeight)
                            // Task title.
                            Text(viewModel.title)
                                .headlineStyle()
                                .multilineTextAlignment(.leading)
                                .redacted(reason: isRedacted ? .placeholder : [])

                            // Task subtitle.
                            Text(viewModel.subtitle)
                                .subheadlineStyle()
                                .multilineTextAlignment(.leading)
                                .redacted(reason: isRedacted ? .placeholder : [])
                        }
                        Spacer()
                        // Chevron icon
                        Image(uiImage: .chevronImage)
                            .flipsForRightToLeftLayoutDirection(true)
                            .foregroundColor(Color(.textTertiary))
                            .renderedIf(!isRedacted)
                    }

                    Spacer().frame(height: Layout.spacerHeight)
                    Divider().dividerStyle().renderedIf(showDivider)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private extension StoreOnboardingTaskView {
    enum Layout {
        static let horizontalSpacing: CGFloat = 16
        static let verticalSpacing: CGFloat = 4
        static let spacerHeight: CGFloat = 12
        static let imageDimension: CGFloat = 24
    }
}

struct StoreOnboardingTaskView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Group {
                StoreOnboardingTaskView(viewModel: .init(task: .init(isComplete: false, type: .addFirstProduct)),
                                        showDivider: true,
                                        isRedacted: false,
                                        onTap: { _ in })

                StoreOnboardingTaskView(viewModel: .init(task: .init(isComplete: false, type: .launchStore)),
                                        showDivider: true,
                                        isRedacted: false,
                                        onTap: { _ in })

                StoreOnboardingTaskView(viewModel: .init(task: .init(isComplete: false, type: .customizeDomains)),
                                        showDivider: true,
                                        isRedacted: false,
                                        onTap: { _ in })

                StoreOnboardingTaskView(viewModel: .init(task: .init(isComplete: false, type: .payments)),
                                        showDivider: true,
                                        isRedacted: false,
                                        onTap: { _ in })

                StoreOnboardingTaskView(viewModel: .init(task: .init(isComplete: true, type: .payments)),
                                        showDivider: true,
                                        isRedacted: false,
                                        onTap: { _ in })
            }
            .previewDisplayName("Customize your domains")
        }
    }
}
