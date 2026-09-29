import XCTest

final class NavigationTests: XCTestCase {
    func testBuiltInPreviewSelectionAndWrite() throws {
        // Only writes the temporary fixture containers, never real CarPlay caches.
        let app = XCUIApplication()
        app.launchEnvironment["CPW_UI_FIXTURES"] = "1"
        app.launch()
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.segmentedControls["languageSelector"].buttons["简体中文"].tap()
        app.tabBars.buttons["壁纸"].tap()
        XCTAssertTrue(app.staticTexts["找到图像缓存"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["choosePhoto"].exists)
        app.buttons["chooseBuiltInWallpaper"].tap()
        XCTAssertTrue(app.staticTexts["雪山映湖"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2048 × 2048 像素"].exists)
        XCTAssertTrue(app.buttons["useBuiltInWallpaper"].isEnabled)
        XCTAssertEqual(app.staticTexts["builtInWallpaperPosition"].label, "1 / 5")
        XCTAssertFalse(app.buttons["previousBuiltInWallpaper"].isEnabled)
        XCTAssertEqual(app.scrollViews.count, 0)
        try app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-built-in.png"))
        app.buttons["nextBuiltInWallpaper"].tap()
        XCTAssertEqual(app.staticTexts["builtInWallpaperName"].label, "海边童趣")
        app.buttons["关闭"].tap()
        XCTAssertFalse(app.staticTexts["selectedImageSource"].label.contains("雪山映湖"), "Preview cancellation must not change the selected image")
        app.buttons["chooseBuiltInWallpaper"].tap()
        app.buttons["useBuiltInWallpaper"].tap()
        XCTAssertTrue(app.staticTexts["selectedImageSource"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["selectedImageSource"].label.contains("雪山映湖"))
        for (offset, title) in ["海边童趣", "暮色灯塔", "晴空小鸟", "棕影晚霞"].enumerated() {
            app.buttons["chooseBuiltInWallpaper"].tap()
            for _ in 0...offset { app.buttons["nextBuiltInWallpaper"].tap() }
            XCTAssertEqual(app.staticTexts["builtInWallpaperName"].label, title)
            XCTAssertEqual(app.staticTexts["builtInWallpaperPosition"].label, "\(offset + 2) / 5")
            XCTAssertTrue(app.staticTexts["2048 × 2048 像素"].exists)
            if offset == 3 {
                XCTAssertFalse(app.buttons["nextBuiltInWallpaper"].isEnabled)
                app.buttons["previousBuiltInWallpaper"].tap()
                XCTAssertEqual(app.staticTexts["builtInWallpaperName"].label, "晴空小鸟")
                app.buttons["nextBuiltInWallpaper"].tap()
            }
            try app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-built-in-\(offset + 1).png"))
            app.buttons["useBuiltInWallpaper"].tap()
            XCTAssertTrue(app.staticTexts["selectedImageSource"].label.contains(title))
        }
        XCTAssertEqual(app.scrollViews.count, 0)
        XCTAssertLessThanOrEqual(app.buttons["同时写入亮暗壁纸"].frame.maxY, app.tabBars.firstMatch.frame.minY)
        try app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-built-in-selected.png"))
        app.buttons["同时写入亮暗壁纸"].tap()
        XCTAssertTrue(app.alerts["亮暗壁纸写入成功"].waitForExistence(timeout: 20))
        app.alerts.buttons["知道了"].tap()
        XCTAssertFalse(app.staticTexts["selectedImageSource"].label.contains("棕影晚霞"))
    }

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
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "点击「设置」")).firstMatch.exists)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "与缓存相同尺寸")).firstMatch.exists)
                let example = app.staticTexts["imageSizeExample"]
                XCTAssertTrue(example.exists)
                XCTAssertTrue(example.label.contains("140 DPI"))
                XCTAssertLessThan(example.frame.maxY, app.tabBars.firstMatch.frame.minY)
            default:
                XCTAssertTrue(app.staticTexts["CarPlayW"].exists)
                XCTAssertTrue(app.staticTexts["鱼头"].exists)
                XCTAssertTrue(app.staticTexts["v1.1"].exists)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "其它机型与系统请自行测试")).firstMatch.exists)
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
            if title == "Guide" {
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "tap Set")).firstMatch.exists)
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "matching the cache dimensions")).firstMatch.exists)
                let example = app.staticTexts["imageSizeExample"]
                XCTAssertTrue(example.exists)
                XCTAssertTrue(example.label.contains("2048 × 2048 pixels, 140 DPI"))
                XCTAssertLessThan(example.frame.maxY, app.tabBars.firstMatch.frame.minY)
            }
            if title == "About" {
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Please test other devices")).firstMatch.exists)
            }
            let screenshot = app.screenshot()
            try screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-en-\(index).png"))
        }
        app.tabBars.buttons["Cache"].tap()
        app.buttons["View Light cached image"].tap()
        XCTAssertTrue(app.staticTexts["32 × 32 pixels"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Close"].exists)
        try app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("CarPlayW-UI-viewer.png"))
        app.buttons["Close"].tap()
        app.tabBars.buttons["Wallpaper"].tap()
        app.buttons["chooseBuiltInWallpaper"].tap()
        for name in ["Seaside Joy", "Twilight Lighthouse", "Blue Sky Bird", "Palm Sunset"] {
            app.buttons["nextBuiltInWallpaper"].tap()
            XCTAssertEqual(app.staticTexts["builtInWallpaperName"].label, name)
        }
        XCTAssertTrue(app.buttons["Use this wallpaper"].exists)
        app.buttons["Close"].tap()
    }
}
