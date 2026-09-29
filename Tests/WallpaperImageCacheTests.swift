import UIKit
import XCTest
@testable import CarPlayW

final class WallpaperImageCacheTests: XCTestCase {
    private var directory: URL!
    private let wallpaper = BuiltInWallpaper(id: "../1", name: "One", englishName: nil,
                                             url: URL(string: "https://example.com/1.png")!)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func original() throws -> Data {
        try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }.pngData())
    }

    private func client(cache: WallpaperImageCache, data: Data, status: Int = 200,
                        requested: (() -> Void)? = nil) -> RemoteWallpaperClient {
        RemoteWallpaperClient(cache: cache) { request in
            requested?()
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: file)
            return (file, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    func testRepeatSelectionAndNewClientReuseOriginalWithoutNetwork() async throws {
        let bytes = try original()
        let cache = WallpaperImageCache(directory: directory)
        var downloads = 0
        let first = client(cache: cache, data: bytes) { downloads += 1 }
        _ = try await first.image(for: wallpaper)
        _ = try await first.image(for: wallpaper)
        XCTAssertEqual(downloads, 1)
        // A new cache instance simulates a fresh process, with no in-memory state.
        let reopened = client(cache: WallpaperImageCache(directory: directory), data: Data(), status: 404) {
            XCTFail("Saved original must be read without a download")
        }
        let image = try await reopened.image(for: wallpaper)
        XCTAssertEqual(image.cgImage?.width, 16)
        let saved = await cache.read(wallpaper)
        XCTAssertEqual(saved, bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    func testValidCatalogDeletesRemovedFilesButKeepsRenamedEntries() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let bytes = try original()
        _ = try await client(cache: cache, data: bytes).image(for: wallpaper)
        let renamed = Data(#"{"version":1,"wallpapers":[{"id":"../1","name":"Renamed","url":"https://example.com/1.png"}]}"#.utf8)
        _ = try await client(cache: cache, data: renamed).catalog()
        let retained = await cache.read(wallpaper)
        XCTAssertEqual(retained, bytes)
        _ = try await client(cache: cache, data: Data(#"{"version":1,"wallpapers":[]}"#.utf8)).catalog()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testChangedURLRemovesOldOriginalAndDownloadsNewOne() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let bytes = try original()
        _ = try await client(cache: cache, data: bytes).image(for: wallpaper)
        let json = Data(#"{"version":1,"wallpapers":[{"id":"../1","name":"One","url":"https://example.com/1.png?v=2"}]}"#.utf8)
        let items = try await client(cache: cache, data: json).catalog()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
        var downloads = 0
        _ = try await client(cache: cache, data: bytes) { downloads += 1 }.image(for: items[0])
        XCTAssertEqual(downloads, 1)
        let saved = await cache.read(items[0])
        XCTAssertEqual(saved, bytes)
    }

    func testFailedOrInvalidCatalogNeverDeletesSavedImages() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let bytes = try original()
        _ = try await client(cache: cache, data: bytes).image(for: wallpaper)
        for (data, status) in [(Data("missing".utf8), 404), (Data("invalid".utf8), 200),
                               (Data(#"{"version":2,"wallpapers":[]}"#.utf8), 200)] {
            do {
                _ = try await client(cache: cache, data: data, status: status).catalog()
                XCTFail("Catalog should fail")
            } catch { }
            let saved = await cache.read(wallpaper)
            XCTAssertEqual(saved, bytes)
        }
    }

    func testCorruptCacheDownloadsAndReplacesOriginal() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let ticket = await cache.ticket()
        try await cache.save(Data("broken".utf8), for: wallpaper, ticket: ticket)
        var downloads = 0
        let bytes = try original()
        _ = try await client(cache: cache, data: bytes) { downloads += 1 }.image(for: wallpaper)
        XCTAssertEqual(downloads, 1)
        let saved = await cache.read(wallpaper)
        XCTAssertEqual(saved, bytes)
    }

    func testFailedDownloadsAreNotSaved() async throws {
        let cache = WallpaperImageCache(directory: directory)
        for (data, status) in [(Data("invalid image".utf8), 200), (try original(), 404)] {
            do {
                _ = try await client(cache: cache, data: data, status: status).image(for: wallpaper)
                XCTFail("Download should fail")
            } catch { }
            let saved = await cache.read(wallpaper)
            XCTAssertNil(saved)
        }
    }

    func testLateDownloadCannotRestoreRemovedImage() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let ticket = await cache.ticket()
        try await cache.reconcile([])
        try await cache.save(try original(), for: wallpaper, ticket: ticket)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testCancelledReconciliationPreservesSavedImages() async throws {
        let cache = WallpaperImageCache(directory: directory)
        let bytes = try original()
        _ = try await client(cache: cache, data: bytes).image(for: wallpaper)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await cache.reconcile([])
        }
        do { try await task.value; XCTFail("Cancelled reconciliation must stop") } catch is CancellationError { }
        let saved = await cache.read(wallpaper)
        XCTAssertEqual(saved, bytes)
    }
}
