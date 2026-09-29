#if DEBUG
import UIKit

/// Deterministic network substitutes used only by UI tests; no wallpaper assets in Release.
final class UITestWallpaperClient: WallpaperLoading {
    private var catalogAttempts = 0
    private var imageAttempts = 0
    private let mode = ProcessInfo.processInfo.environment["CPW_WALLPAPER_SCENARIO"] ?? "success"

    func catalog() async throws -> [BuiltInWallpaper] {
        catalogAttempts += 1
        try await Task.sleep(nanoseconds: 150_000_000)
        if mode == "catalog-retry", catalogAttempts == 1 { throw URLError(.notConnectedToInternet) }
        if mode == "empty" { return [] }
        let names = ["雪山映湖", "海边童趣", "暮色灯塔", "晴空小鸟", "棕影晚霞"]
        return names.enumerated().map { index, name in
            BuiltInWallpaper(id: String(index + 1), name: name,
                             englishName: AppLanguage.english.text(name),
                             url: RemoteWallpaperClient.catalogURL.deletingLastPathComponent().appendingPathComponent("\(index + 1).png"))
        }
    }

    func image(for wallpaper: BuiltInWallpaper) async throws -> UIImage {
        imageAttempts += 1
        try await Task.sleep(nanoseconds: mode == "slow" ? 3_000_000_000 : 150_000_000)
        if mode == "image-retry", imageAttempts == 1 { throw RemoteWallpaperError.response(404) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 2048, height: 2048), format: format).image { context in
            UIColor(hue: CGFloat(Int(wallpaper.id) ?? 1) / 6, saturation: 0.5, brightness: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2048, height: 2048))
            UIColor.white.setFill()
            context.fill(CGRect(x: 200, y: 300, width: 600, height: 800))
        }
    }
}
#endif
