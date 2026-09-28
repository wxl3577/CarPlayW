import XCTest

final class NavigationTests: XCTestCase {
    func testFourFixedTabsAndRestartGuide() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CPW_UI_FIXTURES"] = "1"
        app.launch()
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.segmentedControls["languageSelector"].buttons["简体中文"].tap()
        XCTAssertTrue(app.tabBars.buttons["壁纸"].waitForExistence(timeout: 15))
        for (index, title) in ["壁纸", "缓存", "说明", "关于"].enumerated() {
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.tabBars.buttons[title].isSelected)
            XCTAssertEqual(app.scrollViews.count, 0, "Pages must not require vertical scrolling")
            switch title {
            case "壁纸":
                XCTAssertTrue(app.navigationBars["CarPlayW"].exists)
                XCTAssertTrue(app.buttons["同时写入亮暗壁纸"].exists)
                XCTAssertFalse(app.segmentedControls["布局方式"].exists)
                XCTAssertTrue(app.buttons["familySelector"].isEnabled)
                let square = app.otherElements["selectedSquareImage"]
                if square.exists { XCTAssertEqual(square.frame.width, square.frame.height, accuracy: 1) }
            case "缓存":
                XCTAssertTrue(app.buttons["清除全部缓存图像"].exists)
            case "说明":
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "推荐重启手机")).firstMatch.exists)
            default:
                XCTAssertTrue(app.staticTexts["CarPlayW"].exists)
                XCTAssertTrue(app.staticTexts["鱼头"].exists)
                XCTAssertTrue(app.staticTexts["v1.0"].exists)
                XCTAssertTrue(app.buttons["项目主页"].exists || app.links["项目主页"].exists)
            }
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = title
            attachment.lifetime = .keepAlways
            add(attachment)
            try screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-\(index).png"))
        }
    }

    func testFamilySelectionAndEnglishSurviveRelaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CPW_UI_FIXTURES"] = "1"
        app.launch()
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.segmentedControls["languageSelector"].buttons["English"].tap()
        XCTAssertTrue(app.tabBars.buttons["Wallpaper"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Wallpaper"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["CarPlayW"].exists)
        XCTAssertTrue(app.buttons["familySelector"].waitForExistence(timeout: 10))
        app.buttons["familySelector"].tap()
        app.buttons["RedDynamic"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["RedDynamic"].waitForExistence(timeout: 10))
        for (index, title) in ["Wallpaper", "Cache", "Guide", "About"].enumerated() {
            app.tabBars.buttons[title].tap()
            XCTAssertEqual(app.scrollViews.count, 0)
            let screenshot = app.screenshot()
            try screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-en-\(index).png"))
        }
        app.tabBars.buttons["Cache"].tap()
        app.buttons["View Light cached image"].tap()
        XCTAssertTrue(app.staticTexts["32 × 32 pixels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Close"].exists)
        try app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-viewer.png"))
        app.buttons["Close"].tap()
    }
}
