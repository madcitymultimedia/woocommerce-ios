import Yosemite

extension Product {
    /// Returns the short description without the HTML tags and leading/trailing white spaces and new lines.
    var trimmedShortDescription: String? {
        guard let description = shortDescription else {
            return nil
        }
        return description.removedHTMLTags.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns a comma separated string with each category names.
    /// Returns `nil` if the product doesn't have any associated category
    /// iOS 13+ set a specific locale on to properly format the list with the `ListFormatter` class
    func categoriesDescription(using locale: Locale = .autoupdatingCurrent) -> String? {
        guard categories.isNotEmpty else {
            return nil
        }

        let categoriesNames = categories.map { $0.name.strippedHTML }
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: categoriesNames)
    }

    /// Returns a comma separated string with each tags names.
    /// Returns `nil` if the product doesn't have any associated tag
    /// iOS 13+ set a specific locale on to properly format the list with the `ListFormatter` class
    func tagsDescription(using locale: Locale = .autoupdatingCurrent) -> String? {
        guard tags.isNotEmpty else {
            return nil
        }

        let tagsNames = tags.map { $0.name }
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: tagsNames)
    }
}
