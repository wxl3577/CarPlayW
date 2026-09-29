import XCTest
@testable import CarPlayW

final class AppIdentityTests: XCTestCase {
    func testPublishedAppIdentity() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "CarPlayW")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "1.2")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, "20")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "CarPlayW")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String, "CarPlayW")
        // Keep the original bundle ID so TrollStore can replace existing installations.
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.carplaycanvas.app")
    }

    func testGuideIsFourOrderedSteps() {
        XCTAssertEqual(UsageGuide.steps.count, 4)
        XCTAssertTrue(UsageGuide.steps[0].contains("生成缓存"))
        XCTAssertTrue(UsageGuide.steps[0].contains("点击「设置」"))
        XCTAssertTrue(UsageGuide.steps[1].contains("断开"))
        XCTAssertTrue(UsageGuide.steps[2].contains("写入"))
        XCTAssertTrue(UsageGuide.steps[2].contains("与缓存相同尺寸"))
        XCTAssertTrue(UsageGuide.steps[3].contains("重新连接"))
        XCTAssertTrue(UsageGuide.steps[3].contains("重启手机"))
        XCTAssertTrue(UsageGuide.writeSuccessMessage.contains("推荐重启手机"))
        XCTAssertEqual(UsageGuide.projectURL.absoluteString, "https://lxjc.com/index.php/archives/416/")
    }

    func testDeviceExampleAndCompatibilityCopy() {
        XCTAssertTrue(UsageGuide.testedDeviceMessage.contains("其它机型与系统请自行测试"))
        XCTAssertFalse(UsageGuide.testedDeviceMessage.contains("不保证"))
        XCTAssertTrue(UsageGuide.imageExample.contains("2048 × 2048"))
        XCTAssertTrue(UsageGuide.imageExample.contains("140 DPI"))
        XCTAssertTrue(UsageGuide.imageExample.contains("缓存原图尺寸为准"))
        XCTAssertTrue(UsageGuide.imageExample.contains("DPI 仅供参考"))
    }
}
