import XCTest
@testable import CarPlayW

final class AppLanguageTests: XCTestCase {
    func testLanguagePersistsAndInvalidValueFallsBackSafely() throws {
        let suite = "CPW-LanguageTest-" + UUID().uuidString
        let first = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { first.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AppLanguage.load(from: first), .chinese)
        AppLanguage.english.save(to: first)
        XCTAssertEqual(AppLanguage.load(from: try XCTUnwrap(UserDefaults(suiteName: suite))), .english)
        AppLanguage.chinese.save(to: first)
        XCTAssertEqual(AppLanguage.load(from: first), .chinese)
        first.set("invalid", forKey: AppLanguage.storageKey)
        XCTAssertEqual(AppLanguage.load(from: first), .chinese)
    }

    func testEnglishGuideAndOperationMessagesAreTranslated() {
        for key in UsageGuide.steps + [UsageGuide.writeSuccessMessage, UsageGuide.imageExample, UsageGuide.testedDeviceMessage, "选择 / 切换系列", "亮暗壁纸写入成功", "清除全部缓存图像"] {
            XCTAssertNotEqual(AppLanguage.english.text(key), key)
        }
        for value in AppLanguage.englishText.values {
            // The bilingual Language selector deliberately keeps its Chinese label.
            if value == "Language / 语言" { continue }
            XCTAssertNil(value.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression))
        }
        XCTAssertEqual(AppLanguage.english.format("清除全部 %d 个缓存图像？", 3), "Clear all 3 cached images?")
        XCTAssertTrue(AppLanguage.english.errorMessage(CarPlayWError.invalidBitmap("错误")).contains("validated"))
    }
}
