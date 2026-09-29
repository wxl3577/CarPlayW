import UIKit
import XCTest
@testable import CarPlayW

@MainActor
final class WallpaperPickerModelTests: XCTestCase {
    private final class ControlledClient: WallpaperLoading {
        let entries = (1...3).map {
            BuiltInWallpaper(id: String($0), name: "Image \($0)", englishName: nil,
                             url: URL(string: "https://example.com/\($0).png")!)
        }
        var requests: [String: CheckedContinuation<UIImage, Error>] = [:]
        var empty = false
        func catalog() async throws -> [BuiltInWallpaper] { empty ? [] : entries }
        func image(for wallpaper: BuiltInWallpaper) async throws -> UIImage {
            try await withCheckedThrowingContinuation { requests[wallpaper.id] = $0 }
        }
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for model")
    }

    func testRapidSelectionDiscardsLateImageAndClearsPreviousSelection() async throws {
        let client = ControlledClient()
        let model = WallpaperPickerModel(client: client)
        let first = try XCTUnwrap(WallpaperTestImage.load())
        let second = UIImage()
        model.reload()
        await waitFor { client.requests["1"] != nil }
        model.select(at: 1)
        XCTAssertNil(model.image)
        await waitFor { client.requests["2"] != nil }
        client.requests.removeValue(forKey: "2")?.resume(returning: second)
        await waitFor { model.image != nil }
        client.requests.removeValue(forKey: "1")?.resume(returning: first)
        await Task.yield()
        XCTAssertTrue(model.image === second)
        XCTAssertEqual(model.wallpaper?.id, "2")
        model.select(at: 2)
        XCTAssertNil(model.image)
        await waitFor { client.requests["3"] != nil }
        model.cancel()
        client.requests.removeValue(forKey: "3")?.resume(returning: first)
        await Task.yield()
        XCTAssertNil(model.image)
    }

    func testFailedImageCanRetryAndEmptyCatalogIsSafe() async throws {
        let client = ControlledClient()
        let model = WallpaperPickerModel(client: client)
        model.reload()
        await waitFor { client.requests["1"] != nil }
        client.requests.removeValue(forKey: "1")?.resume(throwing: URLError(.notConnectedToInternet))
        await waitFor { model.errorKey != nil }
        XCTAssertNil(model.image)
        model.retry()
        await waitFor { client.requests["1"] != nil }
        client.requests.removeValue(forKey: "1")?.resume(returning: try XCTUnwrap(WallpaperTestImage.load()))
        await waitFor { model.image != nil }
        XCTAssertNil(model.errorKey)
        client.empty = true
        model.reload()
        await waitFor { !model.isLoading }
        XCTAssertTrue(model.wallpapers.isEmpty)
        XCTAssertNil(model.wallpaper)
        XCTAssertNil(model.image)
        model.select(at: 0)
        XCTAssertNil(model.image)
    }
}
