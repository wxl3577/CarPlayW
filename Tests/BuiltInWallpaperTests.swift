import CryptoKit
import UIKit
import XCTest
@testable import CarPlayW

final class BuiltInWallpaperTests: XCTestCase {
    func testAllFiveOriginalResourcesAndTranslations() throws {
        let expected = [
            ("AlpineReflection", "c2ae38128140defad4ae42cdacf512e142fe8bb38c852f8583389973e8c90ee9", "Alpine Reflection"),
            ("SeasideJoy", "62930a292eb1e1ec4f9f65009f9d0d50705f611eff1c0c2a91b3d1c72f60669a", "Seaside Joy"),
            ("TwilightLighthouse", "4ec65d23ae7ca088a9a9b371a0885f89d305cf7d0698dcfa16aed0dddcbb3922", "Twilight Lighthouse"),
            ("BlueSkyBird", "a35be5208bd24886e4ffb60a2c502f9e07aa66cdff01757c8078c520ddb9c307", "Blue Sky Bird"),
            ("PalmSunset", "9e9f8b57011314c596a8e2b4f40431012a1f12ea74b7dec40036da4e41100676", "Palm Sunset")
        ]
        XCTAssertEqual(BuiltInWallpaper.all.count, expected.count)
        XCTAssertEqual(Set(BuiltInWallpaper.all.map(\.id)).count, expected.count)
        for (wallpaper, (resource, digest, englishName)) in zip(BuiltInWallpaper.all, expected) {
            XCTAssertEqual(wallpaper.resourceName, resource)
            let url = try XCTUnwrap(Bundle.main.url(forResource: resource, withExtension: "png"))
            let data = try Data(contentsOf: url)
            XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), digest)
            let pixels = try XCTUnwrap(wallpaper.load()?.cgImage)
            XCTAssertEqual(pixels.width, 2048)
            XCTAssertEqual(pixels.height, 2048)
            XCTAssertEqual(AppLanguage.english.text(wallpaper.name), englishName)
        }
    }

    func testBundledOriginalDecodesAtFullResolution() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: BuiltInWallpaper.alpineReflection.resourceName, withExtension: "png"))
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, "c2ae38128140defad4ae42cdacf512e142fe8bb38c852f8583389973e8c90ee9")
        let image = try XCTUnwrap(BuiltInWallpaper.alpineReflection.load())
        let pixels = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(pixels.width, 2048)
        XCTAssertEqual(pixels.height, 2048)
        XCTAssertEqual(AppLanguage.english.text(BuiltInWallpaper.alpineReflection.name), "Alpine Reflection")
    }

    @MainActor
    func testPhotoReplacementAndClearResetBuiltInName() throws {
        let model = AppModel()
        let image = try XCTUnwrap(BuiltInWallpaper.alpineReflection.load())
        model.setSelectedImage(image, name: BuiltInWallpaper.alpineReflection.name)
        XCTAssertEqual(model.selectedImageName, BuiltInWallpaper.alpineReflection.name)
        XCTAssertNotNil(model.selectedImage)
        model.setSelectedImage(image)
        XCTAssertNil(model.selectedImageName)
        model.setSelectedImage(image, name: BuiltInWallpaper.alpineReflection.name)
        model.clearSelectedImage()
        XCTAssertNil(model.selectedImage)
        XCTAssertNil(model.selectedImageName)
    }
}
