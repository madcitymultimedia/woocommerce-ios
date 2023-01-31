import UIKit

extension UIView {
    /// Creates a border view with the given height, and color.
    /// - Parameter height: height of the border. Default to be 0.5px.
    /// - Parameter color: background color of the border. Default to be the divider color.
    ///
    static func createBorderView(height: CGFloat = 0.5,
                                 color: UIColor = .systemColor(.separator)) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = color
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height)
            ])
        return view
    }

    /// Creates an empty view with the given height, width, and color
    /// - Parameter height: height of the separator. Default to be 0.5px.
    /// - Parameter width: width of the separator. Default to be 0.5px.
    /// - Parameter color: background color of the separator. Default to be `.clear`
    /// 
    static func createSeparatorView(height: CGFloat = 0.5,
                                width: CGFloat = 0.5,
                                color: UIColor = .clear) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = color
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: height),
            view.widthAnchor.constraint(equalToConstant: width)
        ])
        return view
    }
}
