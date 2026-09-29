import UIKit

enum BuiltInWallpaper {
    static let name = "雪山映湖"
    static let resourceName = "AlpineReflection"

    static func load(from bundle: Bundle = .main) -> UIImage? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
