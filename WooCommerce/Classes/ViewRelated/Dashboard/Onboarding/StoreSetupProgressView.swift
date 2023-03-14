import SwiftUI

struct StoreSetupProgressView: View {
    let isExpanded: Bool

    let totalNumberOfTasks: Int

    let numberOfTasksCompleted: Int

    let shareFeedbackAction: (() -> Void)?

    @State private var showingActionSheet = false

    let isRedacted: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: isExpanded ? .center : .leading, spacing: Layout.verticalSpacing) {
                // Title label
                Text(Localization.title)
                    .fontWeight(.semibold)
                    .if(isExpanded) { $0.titleStyle() }
                    .if(!isExpanded) { $0.headlineStyle() }
                    .multilineTextAlignment(isExpanded ? .center : .leading)
                    .unredacted()

                // Progress view
                ProgressView(value: Double(numberOfTasksCompleted), total: Double(totalNumberOfTasks))
                    .tint(.init(uiColor: .accent))
                    .frame(width: isExpanded ? Layout.ProgressView.widthExpanded : Layout.ProgressView.widthCollapsed, height: Layout.ProgressView.height)
                    .renderedIf(!isRedacted)

                // Subtitle label
                Text(String(format: isExpanded ? Localization.TasksCompleted.expanded : Localization.TasksCompleted.collapsed,
                            numberOfTasksCompleted,
                            totalNumberOfTasks))
                    .footnoteStyle()
                    .multilineTextAlignment(isExpanded ? .center : .leading)
                    .redacted(reason: isRedacted ? .placeholder : [])
            }

            Spacer()
                .renderedIf(!isExpanded)

            // More button
            Button {
                showingActionSheet = true
            } label: {
                Image(uiImage: .ellipsisImage)
                    .flipsForRightToLeftLayoutDirection(true)
                    .foregroundColor(Color(.textTertiary))
            }
            .renderedIf(!isExpanded)
        }
        .confirmationDialog(Localization.title, isPresented: $showingActionSheet) {
            Button(Localization.shareFeedbackButton) {
                shareFeedbackAction?()
            }
        }
    }
}

private extension StoreSetupProgressView {
    enum Layout {
        static let horizontalSpacing: CGFloat = 16
        static let verticalSpacing: CGFloat = 8

        enum ProgressView {
            static let height: CGFloat = 6
            static let widthCollapsed: CGFloat = 152.5
            static let widthExpanded: CGFloat = 205.8
        }
    }

    enum Localization {
        static let title = NSLocalizedString(
            "Store setup",
            comment: "Title of the store setup progress view."
        )

        enum TasksCompleted {
            static let collapsed = NSLocalizedString(
                "%1$d/%2$d completed",
                comment: "Shows how many tasks are completed in the store setup process." +
                "%1$d represents the tasks completed. %2$d represents the total number of tasks." +
                "This text is displayed when the store setup task list is presented in collapsed mode in the dashboard screen."
            )

            static let expanded = NSLocalizedString(
                "%1$d of %2$d tasks completed",
                comment: "Shows how many tasks are completed in the store setup process." +
                "%1$d represents the tasks completed. %2$d represents the total number of tasks." +
                "This text is displayed when the store setup task list is presented in full-screen/expanded mode."
            )
        }

        static let shareFeedbackButton = NSLocalizedString(
            "Share feedback",
            comment: "Title of the feedback button in the action sheet."
        )
    }
}


struct StoreSetupProgressView_Previews: PreviewProvider {
    static var previews: some View {
        StoreSetupProgressView(isExpanded: false, totalNumberOfTasks: 5, numberOfTasksCompleted: 1, shareFeedbackAction: nil, isRedacted: false)

        StoreSetupProgressView(isExpanded: true, totalNumberOfTasks: 5, numberOfTasksCompleted: 1, shareFeedbackAction: nil, isRedacted: false)
    }
}
