import WordPressUI

/// Style for ghosting that will not show calls with a white background.
///
extension GhostStyle {
    static var wooDefaultGhostStyle: Self {
        return GhostStyle(beatDuration: Defaults.beatDuration,
                          beatStartColor: .listForeground(modal: false),
                          beatEndColor: .ghostCellAnimationEndColor)
    }
}
