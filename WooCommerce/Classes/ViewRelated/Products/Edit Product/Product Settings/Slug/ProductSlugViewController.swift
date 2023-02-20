import UIKit
import Yosemite

final class ProductSlugViewController: UIViewController {

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
        let footerText = NSLocalizedString("This is the URL-friendly version of the product title",
        comment: "Footer text in Product Slug screen")
        sections = [Section(footer: footerText, rows: [.slug])]
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
        onCompletion(productSettings)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureTextFieldFirstResponder()
    }
}

// MARK: - View Configuration
//
private extension ProductSlugViewController {

    func configureNavigationBar() {
        title = NSLocalizedString("Slug", comment: "Product Slug navigation title")
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
    }

    /// Since there is only a text field in this view, the text field become the first responder immediately when the view did appear
    ///
    func configureTextFieldFirstResponder() {
        if let indexPath = sections.indexPathForRow(.slug) {
            let cell = tableView.cellForRow(at: indexPath) as? TextFieldTableViewCell
            cell?.becomeFirstResponder()
        }
    }
}

// MARK: - UITableViewDataSource Conformance
//
extension ProductSlugViewController: UITableViewDataSource {

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
extension ProductSlugViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }
}

// MARK: - Support for UITableViewDataSource
//
private extension ProductSlugViewController {
    /// Configure cellForRowAtIndexPath:
    ///
   func configure(_ cell: UITableViewCell, for row: Row, at indexPath: IndexPath) {
        switch cell {
        case let cell as TextFieldTableViewCell:
            configureSlug(cell: cell)
        default:
            fatalError("Unidentified product slug row type")
        }
    }

    func configureSlug(cell: TextFieldTableViewCell) {
        cell.accessoryType = .none

        let placeholder = NSLocalizedString("Slug", comment: "Placeholder in the Product Slug row on Edit Product Slug screen.")

        let viewModel = TextFieldTableViewCell.ViewModel(text: productSettings.slug, placeholder: placeholder, onTextChange: { [weak self] newName in
            if let newName = newName {
                self?.productSettings.slug = newName
            }
            }, onTextDidBeginEditing: {
                //TODO: Add analytics track
        }, onTextDidReturn: nil, inputFormatter: nil, keyboardType: .default)
        cell.configure(viewModel: viewModel)
        cell.applyStyle(style: .body)
    }
}

// MARK: - Constants
//
private extension ProductSlugViewController {

    /// Table Rows
    ///
    enum Row {
        /// Listed in the order they appear on screen
        case slug

        var reuseIdentifier: String {
            switch self {
            case .slug:
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
