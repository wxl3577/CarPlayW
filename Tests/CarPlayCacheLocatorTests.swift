import Foundation
import XCTest
@testable import CarPlayW

final class CarPlayCacheLocatorTests: XCTestCase {
    func testThreeRequestedFamiliesIncludingIncompletePairs() throws {
        let fixture = try makeFixture(files: [
            "CARWallpaperBlueGreenDynamic-Light.cpbitmap", "CARWallpaperBlueGreenDynamic-Dark.cpbitmap",
            "CARWallpaperRedBlueDynamic-Dark.cpbitmap", "CARWallpaperRedDynamic-Dark.cpbitmap",
            "CARWallpaperWWDC-Light.cpbitmap", "CARWallpaperWWDC-Dark.cpbitmap"
        ])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let locations = try CarPlayCacheLocator(applicationContainerRoot: fixture.root).locateAll()
        XCTAssertEqual(locations.map(\.family), CarPlayCacheLocator.families.sorted())
        for location in locations { XCTAssertEqual(location.files.count, 2) }
        let red = try XCTUnwrap(locations.first { $0.family == "CARWallpaperRedDynamic" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: red.files[.light]!.path))
        XCTAssertEqual(red.files[.light]?.lastPathComponent, "CARWallpaperRedDynamic-Light.cpbitmap")
    }

    func testLightOnlyIsAvailableWithoutCreatingDark() throws {
        let fixture = try makeFixture(files: ["CARWallpaperRedDynamic-Light.cpbitmap"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let location = try CarPlayCacheLocator(applicationContainerRoot: fixture.root).locate()
        XCTAssertEqual(location.family, "CARWallpaperRedDynamic")
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.files[.dark]!.path))
    }

    func testOtherFamiliesDoNotAuthorizeCreation() throws {
        let fixture = try makeFixture(files: ["CARWallpaperBlue-Light-14.cpbitmap"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        XCTAssertThrowsError(try CarPlayCacheLocator(applicationContainerRoot: fixture.root).locate())
    }

    func testIgnoresDirectoryWithoutMappedImageCache() throws {
        let fixture = try makeFixture(files: [])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let wrong = fixture.cache.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: wrong, withIntermediateDirectories: true)
        try Data([1]).write(to: wrong.appendingPathComponent("CARWallpaperRedDynamic-Light.cpbitmap"))
        XCTAssertThrowsError(try CarPlayCacheLocator(applicationContainerRoot: fixture.root).locate())
    }

    func testAmbiguousContainersFailClosed() throws {
        let fixture = try makeFixture(files: ["CARWallpaperRedDynamic-Light.cpbitmap"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let other = fixture.root.appendingPathComponent("another-UUID/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try Data([1]).write(to: other.appendingPathComponent("CARWallpaperRedDynamic-Dark.cpbitmap"))
        XCTAssertThrowsError(try CarPlayCacheLocator(applicationContainerRoot: fixture.root).locate()) { error in
            guard case CarPlayWError.multipleCaches = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    private func makeFixture(files: [String]) throws -> (root: URL, cache: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = root.appendingPathComponent("\(UUID().uuidString)/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        for name in files { try Data([1]).write(to: cache.appendingPathComponent(name)) }
        return (root, cache)
    }
}
