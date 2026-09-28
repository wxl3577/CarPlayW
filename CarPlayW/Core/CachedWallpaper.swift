import UIKit

/// A decoded snapshot of the actual file, never the photo selected for writing.
struct CachedWallpaper: Identifiable {
    let variant: WallpaperVariant
    let fileName: String
    let image: UIImage
    let byteCount: Int

    var id: String { variant.rawValue + fileName }
    var pixelWidth: Int { image.cgImage?.width ?? 0 }
    var pixelHeight: Int { image.cgImage?.height ?? 0 }
    var dimensions: String { "\(pixelWidth) × \(pixelHeight)" }
    var fileSize: String { ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file) }

    static func recommendation(for images: [WallpaperVariant: CachedWallpaper], language: AppLanguage = .chinese) -> String {
        let ordered = WallpaperVariant.allCases.compactMap { images[$0] }
        guard let first = ordered.first else { return language.text("建议使用缓存原图尺寸，如 2048 × 2048 像素；请先到「缓存」查看。") }
        if ordered.allSatisfy({ $0.dimensions == first.dimensions }) {
            return language.format("建议图片尺寸：%@ 像素，与当前缓存原图一致。", first.dimensions)
        }
        return language.format("缓存原图：%@ 像素。亮暗尺寸不同，将分别完整留边适配。", ordered.map { "\(language.text($0.variant.title)) \($0.dimensions)" }.joined(separator: "; "))
    }
}
