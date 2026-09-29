import CryptoKit
import UIKit
import XCTest
@testable import CarPlayW

enum WallpaperTestImage {
    static func load() -> UIImage? {
        guard let url = Bundle(for: BuiltInWallpaperTests.self).url(forResource: "AlpineReflection", withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

final class BuiltInWallpaperTests: XCTestCase {
    private let endpoint = RemoteWallpaperClient.catalogURL

    private func parse(_ json: String) throws -> [BuiltInWallpaper] {
        try JSONDecoder().decode(WallpaperCatalog.self, from: Data(json.utf8)).resolved(relativeTo: endpoint)
    }

    func testCatalogControlsCountOrderNamesAndRelativeURLs() throws {
        let wallpapers = try parse(#"{"version":1,"wallpapers":[{"id":"9","name":"新增图片","name_en":"New picture","url":"9.png"},{"id":"2","name":"第二张","url":"https://example.com/2.png"}]}"#)
        XCTAssertEqual(wallpapers.map(\.id), ["9", "2"])
        XCTAssertEqual(wallpapers[0].url.absoluteString, "https://480.pp.ua/web_share/carplay/yc/9.png")
        XCTAssertEqual(wallpapers[0].title(in: .english), "New picture")
        XCTAssertEqual(wallpapers[1].title(in: .english), "第二张")
        XCTAssertEqual(try parse(#"{"version":1,"wallpapers":[]}"#), [])
    }

    func testRejectsInvalidCatalogs() {
        for json in [
            "<html>Not found</html>",
            #"{"version":2,"wallpapers":[]}"#,
            #"{"version":1,"wallpapers":[{"id":"1","name":"A","url":"1.png"},{"id":"1","name":"B","url":"2.png"}]}"#,
            #"{"version":1,"wallpapers":[{"id":"1","name":" ","url":"1.png"}]}"#,
            #"{"version":1,"wallpapers":[{"id":"1","name":"A","url":"http://example.com/1.png"}]}"#,
            #"{"version":1,"wallpapers":[{"id":"1","name":"A","url":"file:///tmp/1.png"}]}"#,
            #"{"version":1,"wallpapers":[{"id":"1","name":"A","url":""}]}"#
        ] { XCTAssertThrowsError(try parse(json)) }
    }

    func testImagesAreAbsentFromApplicationBundle() {
        for name in ["AlpineReflection", "SeasideJoy", "TwilightLighthouse", "BlueSkyBird", "PalmSunset"] {
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "png"))
        }
    }

    func testDecodePreservesFullResolutionAndRejectsHTML() throws {
        let original = try XCTUnwrap(WallpaperTestImage.load()?.pngData())
        let image = try RemoteWallpaperClient.decodeImage(original)
        XCTAssertEqual(image.cgImage?.width, 2048)
        XCTAssertEqual(image.cgImage?.height, 2048)
        XCTAssertThrowsError(try RemoteWallpaperClient.decodeImage(Data("<html>error</html>".utf8)))
    }

    private func client(data: Data, status: Int = 200, file: URL) -> RemoteWallpaperClient {
        RemoteWallpaperClient(cache: WallpaperImageCache(directory: file.appendingPathExtension("cache"))) { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
            try data.write(to: file)
            return (file, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    func testClientLoadsFreshManifestAndDeletesTemporaryDownload() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = Data(#"{"version":1,"wallpapers":[{"id":"1","name":"One","url":"1.png"}]}"#.utf8)
        let result = try await client(data: data, file: file).catalog()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].url.lastPathComponent, "1.png")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testHTTPFailureMalformedJSONAndOversizedCatalogAreRejected() async {
        for (data, status) in [(Data("missing".utf8), 404), (Data("bad json".utf8), 200), (Data(count: 1_048_577), 200)] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                _ = try await client(data: data, status: status, file: file).catalog()
                XCTFail("Invalid server response must fail")
            } catch { }
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }

    func testClientRejectsInvalidImageResponse() async throws {
        let wallpaper = BuiltInWallpaper(id: "1", name: "A", englishName: nil, url: endpoint.appendingPathComponent("1.png"))
        for (data, status) in [(Data("<html>not an image</html>".utf8), 200), (Data(), 404)] {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                _ = try await client(data: data, status: status, file: file).image(for: wallpaper)
                XCTFail("Invalid image response must fail")
            } catch { }
            XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        }
    }

    @MainActor
    func testPhotoReplacementAndClearResetWallpaperName() throws {
        let model = AppModel()
        let image = try XCTUnwrap(WallpaperTestImage.load())
        model.setSelectedImage(image, name: "雪山映湖")
        XCTAssertEqual(model.selectedImageName, "雪山映湖")
        model.setSelectedImage(image)
        XCTAssertNil(model.selectedImageName)
        model.setSelectedImage(image, name: "雪山映湖")
        model.clearSelectedImage()
        XCTAssertNil(model.selectedImage)
        XCTAssertNil(model.selectedImageName)
    }
}
