import XCTest
import UIKit
@testable import CarPlayW

final class WallpaperServiceTests: XCTestCase {
    func testBuiltInWallpaperUsesTheSameValidatedPairWriter() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        let image = try XCTUnwrap(WallpaperTestImage.load())
        _ = try service.apply(image: image, layout: .fit)
        let (_, snapshots) = try service.scanCache()
        for variant in WallpaperVariant.allCases {
            let saved = try XCTUnwrap(snapshots[variant])
            XCTAssertEqual(saved.dimensions, "32 × 16", "Keep actual cache dimensions, not the built-in source dimensions")
            XCTAssertNotEqual(try Data(contentsOf: fixture.location.files[variant]!), fixture.original)
        }
        XCTAssertEqual(snapshots[.light]?.image.pngData(), snapshots[.dark]?.image.pngData())
    }

    func testCacheViewerReadsRealBytesAndRefreshesAfterWrite() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        let (_, before) = try service.scanCache()
        let light = try XCTUnwrap(before[.light])
        XCTAssertEqual(light.dimensions, "32 × 16")
        XCTAssertEqual(light.byteCount, fixture.original.count)
        XCTAssertEqual(light.fileName, fixture.location.files[.light]!.lastPathComponent)
        XCTAssertTrue(CachedWallpaper.recommendation(for: before).contains("32 × 16"))
        _ = try service.apply(image: redImage(), layout: .fit)
        let (_, after) = try service.scanCache()
        for variant in WallpaperVariant.allCases {
            let cached = try XCTUnwrap(after[variant])
            XCTAssertNotEqual(cached.image.pngData(), before[variant]?.image.pngData())
            let actual = try Data(contentsOf: fixture.location.files[variant]!)
            XCTAssertEqual(cached.byteCount, actual.count)
            XCTAssertEqual(cached.image.pngData(), try CPBitmapCodec.decode(actual).pngData())
        }
    }

    func testCacheViewerShowsOnlyReadableExistingAppearances() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        try FileManager.default.removeItem(at: fixture.location.files[.light]!)
        let (_, missingLight) = try service.scanCache()
        XCTAssertNil(missingLight[.light])
        XCTAssertNotNil(missingLight[.dark])
        XCTAssertTrue(CachedWallpaper.recommendation(for: missingLight).contains("32 × 16"))
        try Data([1, 2, 3]).write(to: fixture.location.files[.dark]!)
        let (_, brokenDark) = try service.scanCache()
        XCTAssertTrue(brokenDark.isEmpty)
        XCTAssertTrue(CachedWallpaper.recommendation(for: brokenDark).contains("如 2048"))
    }

    func testBrokenCurrentTemplateStopsBothWrites() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let bad = Data([1, 2, 3])
        try bad.write(to: fixture.location.files[.light]!)
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        XCTAssertThrowsError(try service.apply(image: redImage(), layout: .fill))
        XCTAssertEqual(try Data(contentsOf: fixture.location.files[.light]!), bad)
        XCTAssertEqual(try Data(contentsOf: fixture.location.files[.dark]!), fixture.original)
    }

    func testDecodeFailureRollsBackBytesAndPermissions() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService()
        let target = fixture.location.files[.light]!
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
        XCTAssertThrowsError(try service.writeTransaction(
            [target: Data([0, 1, 2])], expectedImages: [target: redImage()]
        ))
        XCTAssertEqual(try Data(contentsOf: target), fixture.original)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int, 0o640)
    }


    func testMissingPartnerIsCreatedWithoutPersistentBackup() throws {
        for missing in WallpaperVariant.allCases {
            let fixture = try fixture()
            defer { try? FileManager.default.removeItem(at: fixture.root) }
            try FileManager.default.removeItem(at: fixture.location.files[missing]!)
            let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
            let (_, previews) = try service.scan()
            XCTAssertNil(previews[missing])
            _ = try service.apply(image: redImage(), layout: .fill)
            _ = try service.apply(image: redImage(), layout: .fit)
            for url in fixture.location.files.values {
                try CPBitmapCodec.validate(Data(contentsOf: url), against: redImage())
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("backups").path))
        }
    }

    func testNewFileIsRemovedIfWriteValidationFails() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let target = fixture.location.files[.light]!
        try FileManager.default.removeItem(at: target)
        let service = WallpaperService()
        XCTAssertThrowsError(try service.writeTransaction([target: Data([1])], expectedImages: [target: redImage()]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testSelectedFamilyOnlyIsModified() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let red = fixture.location.directory.appendingPathComponent("CARWallpaperRedDynamic-Dark.cpbitmap")
        try fixture.original.write(to: red)
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        let locations = try service.availableLocations()
        _ = try service.scan(at: XCTUnwrap(locations.first { $0.family == "CARWallpaperRedDynamic" }))
        _ = try service.apply(image: redImage(), layout: .fill)
        for url in fixture.location.files.values { XCTAssertEqual(try Data(contentsOf: url), fixture.original) }
        XCTAssertNotEqual(try Data(contentsOf: red), fixture.original)
    }

    func testBothFilesRemovedAfterScanCannotBeRecreated() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        _ = try service.scan()
        for url in fixture.location.files.values { try FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try service.apply(image: redImage(), layout: .fill))
    }

    func testDeletionIsRolledBackWhenLaterWriteFails() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService()
        let dark = fixture.location.files[.dark]!
        let light = fixture.location.files[.light]!
        // Dark sorts first: delete it, then force Light's decode to fail.
        XCTAssertThrowsError(try service.writeTransaction([light: Data([1])],
            expectedImages: [light: redImage()], deletions: [dark]))
        for url in fixture.location.files.values { XCTAssertEqual(try Data(contentsOf: url), fixture.original) }
    }



    func testClearAllFamiliesAndImageExtensionsButKeepsOtherFiles() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let cache = fixture.location.directory
        for name in ["CARWallpaperOther-Dark.bitmap", "wallpaper.PNG", "other.atx"] {
            try Data([1]).write(to: cache.appendingPathComponent(name))
        }
        let settings = cache.appendingPathComponent("settings.plist")
        try Data([2]).write(to: settings)
        let nested = cache.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data([3]).write(to: nested.appendingPathComponent("keep.png"))
        let outside = fixture.root.appendingPathComponent("outside.png")
        try Data([4]).write(to: outside)
        try FileManager.default.createSymbolicLink(at: cache.appendingPathComponent("link.png"), withDestinationURL: outside)
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        let plan = try service.prepareCacheClear()
        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(try service.clearCache(plan), 5)
        XCTAssertEqual(try Data(contentsOf: settings), Data([2]))
        XCTAssertEqual(try Data(contentsOf: nested.appendingPathComponent("keep.png")), Data([3]))
        XCTAssertEqual(try Data(contentsOf: outside), Data([4]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertEqual(try service.prepareCacheClear().count, 0)
    }

    func testClearWorksWithoutSupportedWallpaperFamily() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        for url in fixture.location.files.values { try FileManager.default.removeItem(at: url) }
        let unsupported = fixture.location.directory.appendingPathComponent("Unknown.bitmap")
        try Data([4]).write(to: unsupported)
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        XCTAssertThrowsError(try service.availableLocations())
        XCTAssertEqual(try service.clearCache(service.prepareCacheClear()), 1)
    }

    func testClearRejectsChangedOrAddedImagesAfterConfirmation() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        let plan = try service.prepareCacheClear()
        let target = fixture.location.files[.light]!
        try Data([9]).write(to: target)
        XCTAssertThrowsError(try service.clearCache(plan))
        XCTAssertEqual(try Data(contentsOf: target), Data([9]))
        XCTAssertEqual(try Data(contentsOf: fixture.location.files[.dark]!), fixture.original)
        let secondPlan = try service.prepareCacheClear()
        let added = fixture.location.directory.appendingPathComponent("new.png")
        try Data([8]).write(to: added)
        XCTAssertThrowsError(try service.clearCache(secondPlan))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: added.path))
    }

    func testClearRejectsAmbiguousContainers() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let second = fixture.root.appendingPathComponent("second/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        XCTAssertThrowsError(try service.prepareCacheClear())
        for url in fixture.location.files.values { XCTAssertEqual(try Data(contentsOf: url), fixture.original) }
    }

    func testClearNeverFollowsContainerSymlink() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let scanRoot = fixture.root.appendingPathComponent("scan")
        try FileManager.default.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: scanRoot.appendingPathComponent("link"),
            withDestinationURL: fixture.root.appendingPathComponent("container"))
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: scanRoot))
        XCTAssertThrowsError(try service.prepareCacheClear())
        for url in fixture.location.files.values { XCTAssertEqual(try Data(contentsOf: url), fixture.original) }
    }

    func testClearInvalidatesScannedPairAndCannotRecreateIt() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let service = WallpaperService(locator: CarPlayCacheLocator(applicationContainerRoot: fixture.root))
        _ = try service.scan()
        _ = try service.clearCache(service.prepareCacheClear())
        XCTAssertThrowsError(try service.apply(image: redImage(), layout: .fill))
        XCTAssertEqual(try service.prepareCacheClear().count, 0)
    }

    func testChangedTemplateBeforeTransactionStopsWithoutWrites() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let target = fixture.location.files[.light]!
        try Data([5]).write(to: target)
        XCTAssertThrowsError(try WallpaperService().writeTransaction([target: Data([6])],
            expectedOriginals: [target: fixture.original]))
        XCTAssertEqual(try Data(contentsOf: target), Data([5]))
    }

    private func redImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 16)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
        }
    }

    private func fixture() throws -> (root: URL, location: CarPlayCacheLocation, original: Data) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = root.appendingPathComponent("container/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        var data = Data(repeating: 0, count: 32 * 16 * 4)
        for value: UInt32 in [0, 32, 16, 1, 1, 0] {
            data.append(contentsOf: (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
        }
        var files: [WallpaperVariant: URL] = [:]
        for variant in WallpaperVariant.allCases {
            let suffix = variant == .light ? "Light" : "Dark"
            let url = cache.appendingPathComponent("CARWallpaperBlueGreenDynamic-\(suffix).cpbitmap")
            try data.write(to: url)
            files[variant] = url
        }
        return (root, CarPlayCacheLocation(directory: cache, files: files), data)
    }
}
