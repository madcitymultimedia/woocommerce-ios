import UIKit
import Yosemite

final class ProductMenuOrderViewController: UIViewController {

    @IBOutlet weak private var tableView: UITableView!

    // Completion callback
    //
    typealias Completion = (_ productSettings: ProductSettings) -> Void
    private let onCompletion: Completion

    private let productSettings: ProductSettings

    private let sections: [Section]

    /// Init
    ///
    init(settings: ProductSettings, completion: @escaping Completion) {
        productSettings = settings
        let footerText = NSLocalizedString("Determines the products positioning in the catalog."
            + " The lower the value of the number, the higher the item will be on the product list. You can also use negative values",
                                           comment: "Footer text in Product Menu order screen")
        sections = [Section(footer: footerText, rows: [.menuOrder])]
        onCompletion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        configureMainView()
        configureTableView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            onCompletion(productSettings)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureFirstTextFieldAsFirstResponder()
    }
}

// MARK: - View Configuration
//
private extension ProductMenuOrderViewController {

    func configureNavigationBar() {
        title = NSLocalizedString("Menu Order", comment: "Product Menu Order navigation title")
    }

    func configureMainView() {
        view.backgroundColor = .listBackground
    }

    func configureTableView() {
        tableView.registerNib(for: TextFieldTableViewCell.self)

        tableView.dataSource = self
        tableView.delegate = self

        tableView.backgroundColor = .listBackground
        tableView.removeLastCellSeparator()

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.sectionFooterHeight = UITableView.automaticDimension

        tableView.allowsSelection = false
    }

    /// Since there is only a text field in this view, the text field become the first responder immediately when the view did appear
    ///
    func configureFirstTextFieldAsFirstResponder() {
        if let indexPath = sections.indexPathForRow(.menuOrder) {
            let cell = tableView.cellForRow(at: indexPath) as? TextFieldTableViewCell
            cell?.becomeFirstResponder()
        }
    }
}

// MARK: - UITableViewDataSource Conformance
//
extension ProductMenuOrderViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)
        configure(cell, for: row, at: indexPath)

        return cell
    }
}

// MARK: - UITableViewDelegate Conformance
//
extension ProductMenuOrderViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }
}

// MARK: - Support for UITableViewDataSource
//
private extension ProductMenuOrderViewController {
    /// Configure cellForRowAtIndexPath:
    ///
   func configure(_ cell: UITableViewCell, for row: Row, at indexPath: IndexPath) {
        switch cell {
        case let cell as TextFieldTableViewCell:
            configureMenuOrder(cell: cell)
        default:
            fatalError("Unidentified product menu order row type")
        }
    }

    func configureMenuOrder(cell: TextFieldTableViewCell) {
        cell.accessoryType = .none

        let placeholder = NSLocalizedString("Menu order", comment: "Placeholder in the Product Menu Order row on Edit Product Menu Order screen.")

        let viewModel = TextFieldTableViewCell.ViewModel(text: String(productSettings.menuOrder),
                                                         placeholder: placeholder,
                                                         onTextChange: { [weak self] menuOrder in
            if let newMenuOrder = Int(menuOrder ?? "0") {
                self?.productSettings.menuOrder = newMenuOrder
            }
            }, onTextDidBeginEditing: {
                //TODO: Add analytics track
        }, onTextDidReturn: nil, inputFormatter: IntegerInputFormatter(defaultValue: ""), keyboardType: .numbersAndPunctuation)
        cell.configure(viewModel: viewModel)
        cell.applyStyle(style: .body)
    }
}

// MARK: - Constants
//
private extension ProductMenuOrderViewController {

    /// Table Rows
    ///
    enum Row {
        /// Listed in the order they appear on screen
        case menuOrder

        var reuseIdentifier: String {
            switch self {
            case .menuOrder:
                return TextFieldTableViewCell.reuseIdentifier
            }
        }
    }

    /// Table Sections
    ///
    struct Section: RowIterable {
        let footer: String?
        let rows: [Row]

        init(footer: String? = nil, rows: [Row]) {
            self.footer = footer
            self.rows = rows
        }
    }
}
