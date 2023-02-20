import Foundation


// MARK: - Array Helpers
//
extension Array {
    /// Removes and returns the first element in the array. If any!
    ///
    mutating func popFirst() -> Element? {
        guard isEmpty == false else {
            return nil
        }

        return removeFirst()
    }

    /// A Boolean value indicating whether a collection is not empty.
    var isNotEmpty: Bool {
        return !isEmpty
    }

    /// A Bool indicating if the collection has at least two elements
    var containsMoreThanOne: Bool {
        return count > 1
    }
}

// MARK: - Sequence Helpers
//
extension Sequence {
    /// Get the keypaths for a elemtents in a sequence.
    ///
    func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        return map { $0[keyPath: keyPath] }
    }

    /// Sum a sequence of elements by keypath.
    func sum<T: Numeric>(_ keyPath: KeyPath<Element, T>) -> T {
        return map(keyPath).sum()
    }
}

extension Sequence where Element: Numeric {
    /// Returns the sum of all elements in the collection.
    func sum() -> Element { return reduce(0, +) }
}

extension Sequence where Element: Equatable {
    /// Returns the sequence with any duplicate elements after the first one removed.
    func removingDuplicates() -> [Element] {
        var result = [Element]()
        for value in self {
            if result.contains(value) == false {
                result.append(value)
            }
        }
        return result
    }
}
