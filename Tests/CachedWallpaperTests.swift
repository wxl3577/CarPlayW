import XCTest
import UIKit
@testable import CarPlayW

final class CachedWallpaperTests: XCTestCase {
    func testRecommendationUsesPixelsNotDisplayPoints() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 16), format: format).image { _ in }
        let cached = CachedWallpaper(variant: .dark, fileName: "sample", image: image, byteCount: 100)
        XCTAssertEqual(cached.dimensions, "64 × 32")
        XCTAssertTrue(CachedWallpaper.recommendation(for: [.dark: cached]).contains("64 × 32"))
    }

    func testDifferentAppearanceSizesAreNotReportedAsOneSize() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        func sample(_ variant: WallpaperVariant, _ width: Int) -> CachedWallpaper {
            let image = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width), height: 16), format: format).image { _ in }
            return CachedWallpaper(variant: variant, fileName: "sample", image: image, byteCount: 100)
        }
        let result = CachedWallpaper.recommendation(for: [.light: sample(.light, 32), .dark: sample(.dark, 64)])
        XCTAssertTrue(result.contains("浅色 32 × 16"))
        XCTAssertTrue(result.contains("深色 64 × 16"))
        XCTAssertTrue(result.contains("尺寸不同"))
    }
}
