#if DEBUG
import UIKit

/// Simulator UI tests only. Never included in the Release IPA and never uses system containers.
enum UITestFixtures {
    static func make() throws -> (service: WallpaperService, image: UIImage) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CPW-UITests-" + UUID().uuidString)
        let cache = root.appendingPathComponent("container/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        var data = Data()
        for _ in 0..<(32 * 32) { data.append(contentsOf: [220, 140, 30, 255]) }
        for value: UInt32 in [0, 32, 32, 1, 1, 0] {
            data.append(contentsOf: (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
        }
        for family in CarPlayCacheLocator.families {
            for variant in WallpaperVariant.allCases {
                try data.write(to: cache.appendingPathComponent("\(family)-\(variant.fileSuffix).cpbitmap"))
            }
        }
        return (WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: root)), try CPBitmapCodec.decode(data))
    }
}
#endif
