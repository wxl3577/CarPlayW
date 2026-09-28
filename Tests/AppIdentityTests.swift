import XCTest
@testable import CarPlayW

final class AppIdentityTests: XCTestCase {
    func testPublishedAppIdentity() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "CarPlayW")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.0")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "16")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "CarPlayW")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String, "CarPlayW")
        // Keep the original bundle ID so TrollStore can replace existing installations.
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.carplaycanvas.app")
    }

    func testGuideIsFourOrderedSteps() {
        XCTAssertEqual(UsageGuide.steps.count, 4)
        XCTAssertTrue(UsageGuide.steps[0].contains("生成缓存"))
        XCTAssertTrue(UsageGuide.steps[1].contains("断开"))
        XCTAssertTrue(UsageGuide.steps[2].contains("写入"))
        XCTAssertTrue(UsageGuide.steps[3].contains("重新连接"))
        XCTAssertTrue(UsageGuide.steps[3].contains("重启手机"))
        XCTAssertTrue(UsageGuide.writeSuccessMessage.contains("推荐重启手机"))
        XCTAssertEqual(UsageGuide.projectURL.absoluteString, "https://lxjc.com/index.php/archives/416/")
    }
}
