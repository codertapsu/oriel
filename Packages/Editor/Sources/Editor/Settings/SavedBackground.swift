import CoreGraphics
import Foundation

/// A background the user saved as a preset (Settings key `editor.savedBackgrounds`): the whole style and the padding.
/// A picture is not kept in the settings: a chosen image is copied to a file of the library's own, and the desktop
/// picture is read again when the preset is applied, so it follows the desktop.
nonisolated struct SavedBackground: Codable, Sendable, Identifiable, Equatable {
    /// Where the preset's picture comes from.
    enum Picture: Codable, Sendable, Equatable {
        case desktopPicture(blur: CGFloat)
        /// A PNG in the library's folder.
        case file(name: String, blur: CGFloat)
    }

    var id: UUID
    var name: String
    /// The style without its picture.
    var style: BackgroundStyle
    var padding: CGFloat
    var picture: Picture?

    init(id: UUID = UUID(), name: String, style: BackgroundStyle, padding: CGFloat, picture: Picture? = nil) {
        self.id = id
        self.name = name
        var style = style
        style.image = nil
        self.style = style
        self.padding = padding
        self.picture = picture
    }
}
