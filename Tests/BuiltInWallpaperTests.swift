import CryptoKit
import UIKit
import XCTest
@testable import CarPlayW

final class BuiltInWallpaperTests: XCTestCase {
    func testBundledOriginalDecodesAtFullResolution() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: BuiltInWallpaper.resourceName, withExtension: "png"))
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, "c2ae38128140defad4ae42cdacf512e142fe8bb38c852f8583389973e8c90ee9")
        let image = try XCTUnwrap(BuiltInWallpaper.load())
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(pixels.width, 2048)
        XCTAssertEqual(pixels.height, 2048)
        XCTAssertEqual(AppLanguage.english.text(BuiltInWallpaper.name), "Alpine Reflection")
    }

    @MainActor
    func testPhotoReplacementAndClearResetBuiltInName() throws {
        let model = AppModel()
        let image = try XCTUnwrap(BuiltInWallpaper.load())
        model.setSelectedImage(image, name: BuiltInWallpaper.name)
        XCTAssertEqual(model.selectedImageName, BuiltInWallpaper.name)
        XCTAssertNotNil(model.selectedImage)
        model.setSelectedImage(image)
        XCTAssertNil(model.selectedImageName)
        model.setSelectedImage(image, name: BuiltInWallpaper.name)
        model.clearSelectedImage()
        XCTAssertNil(model.selectedImage)
        XCTAssertNil(model.selectedImageName)
    }
}
