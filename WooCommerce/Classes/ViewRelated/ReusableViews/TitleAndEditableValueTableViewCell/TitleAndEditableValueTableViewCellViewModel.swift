import Combine
import Foundation

/// Observable ViewModel for `TitleAndEditableValueTableViewCell`.
///
/// Represents a view that has a title label and an editable text field.
///
final class TitleAndEditableValueTableViewCellViewModel {

    /// The `String` used for the title label.
    let title: String?
    /// The placeholder for the editable text field.
    let placeholder: String?
    /// If `false`, the text field will be disabled. Defaults to `true`.
    let allowsEditing: Bool
    /// If `true`, the keyboard will be dismissed on tapping return. Defaults to `false`.
    let hidesKeyboardOnReturn: Bool

    /// Emits values whenever the text field changes.
    ///
    /// This is connected with the view's text field through the `update(value:)`.
    @Published private(set) var value: String?

    init(title: String?, placeholder: String? = nil, initialValue: String? = nil, allowsEditing: Bool = true, hidesKeyboardOnReturn: Bool = false) {
        self.title = title
        self.placeholder = placeholder
        self.allowsEditing = allowsEditing
        self.hidesKeyboardOnReturn = hidesKeyboardOnReturn

        value = initialValue
    }

    /// Updates the value of the `self.value` observable.
    ///
    /// This is generally used by the view represented by this `ViewModel`.
    func update(value: String?) {
        self.value = value
    }
}
