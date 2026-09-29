import UIKit

struct BuiltInWallpaper: Identifiable, Hashable {
    let name: String
    let resourceName: String
    var id: String { resourceName }

    static let alpineReflection = BuiltInWallpaper(name: "雪山映湖", resourceName: "AlpineReflection")
    static let all: [BuiltInWallpaper] = [
        alpineReflection,
        BuiltInWallpaper(name: "海边童趣", resourceName: "SeasideJoy"),
        BuiltInWallpaper(name: "暮色灯塔", resourceName: "TwilightLighthouse"),
        BuiltInWallpaper(name: "晴空小鸟", resourceName: "BlueSkyBird"),
        BuiltInWallpaper(name: "棕影晚霞", resourceName: "PalmSunset")
    ]

    func load(from bundle: Bundle = .main) -> UIImage? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
