import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans"
    case english = "en"
    static let storageKey = "appLanguage"
    static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .chinese
    }
    func save(to defaults: UserDefaults = .standard) { defaults.set(rawValue, forKey: Self.storageKey) }
    func text(_ key: String) -> String { self == .chinese ? key : Self.englishText[key] ?? key }
    func format(_ key: String, _ values: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: rawValue), arguments: values)
    }
    func errorMessage(_ error: Error) -> String {
        guard self == .english else { return error.localizedDescription }
        guard let known = error as? CarPlayWError else {
            let ns = error as NSError
            return "Operation failed (\(ns.domain), \(ns.code)). Refresh the cache and try again."
        }
        switch known {
        case .cacheRootUnavailable: return "Cannot access CarPlay containers. Install using TrollStore with the required entitlements."
        case .cacheNotFound: return "No wallpaper cache found. Connect CarPlay and choose a system wallpaper first."
        case .multipleCaches: return "Multiple cache directories found. Stopped to avoid changing the wrong files."
        case .wallpaperPairNotFound, .missingFiles: return "No supported cached appearance found for this family. Generate the system wallpaper cache, then refresh."
        case .invalidBitmap: return "The cached image could not be decoded or validated. No new wallpaper was written. Regenerate the system cache and refresh."
        case .noImageSelected: return "Select one photo for both appearances."
        case .cacheClearFailed: return "Cache clearing could not finish. Disconnect CarPlay and refresh before trying again."
        case .writeFailed: return "Writing failed; rollback was attempted. Refresh and inspect both cached images. If they cannot be read, regenerate the system wallpaper cache."
        }
    }

    static let englishText: [String: String] = [
        "壁纸": "Wallpaper", "缓存": "Cache", "说明": "Guide", "关于": "About",
        "缓存图像": "Cached images", "使用说明": "Quick guide", "知道了": "OK", "取消": "Cancel",
        "清除全部 %d 个缓存图像？": "Clear all %d cached images?",
        "确认已断开 CarPlay，清除全部": "Disconnected — clear all",
        "清除所有系列的缓存图像，无备份、不可撤销。不删除子目录或其他类型文件。之后需连接 CarPlay 并选择系统壁纸重新生成缓存。": "Deletes cached images for all families. No backup or undo. Subfolders and other file types are kept. Reconnect CarPlay and choose a system wallpaper to regenerate the cache.",
        "刷新缓存": "Refresh cache", "查看当前系列缓存图像": "View this family's cache",
        "选择图片": "Photo", "移除": "Remove", "选择": "Choose", "更换": "Change",
        "完整留边写入，不拉伸、不裁切。": "Writes with aspect fit. No stretching or cropping.",
        "显示比例 1:1 · 建议 2048 × 2048 像素": "Square display · 2048 × 2048 recommended",
        "同时写入亮暗壁纸": "Apply to light & dark",
        "点击原图查看尺寸。刷新或写入后重新读取实际文件。": "Tap an image for details. Refresh and writes reload the actual files.",
        "清除全部缓存图像": "Clear all cached images",
        "先断开 CarPlay。删除所有系列图像，无备份、不可撤销。": "Disconnect first. Clears all families, with no backup or undo.",
        "壁纸系列": "Wallpaper family", "暂无可修改系列": "No available families",
        "选择 / 切换系列": "Select / change family", "点击按钮选择其他系列": "Tap the button to choose a family",
        "浅色": "Light", "深色": "Dark", "像素": "pixels", "字节": "bytes",
        "查看%@缓存原图": "View %@ cached image", "%@缓存原图": "%@ cached image",
        "暂无可读图像": "No readable image", "缺失或无法读取": "Missing or unreadable",
        "请停车后操作。刷新仅读取手机已有缓存。": "Use only while parked. Refresh reads files already on the phone.",
        "重启或切换系统壁纸可能重建缓存；如效果消失，请刷新检查。": "Restarting or switching system wallpapers may rebuild caches. Refresh and check if your wallpaper disappears.",
        "让车机壁纸，多一点你的风格。": "Make your CarPlay wallpaper your own.",
        "作者": "Author", "项目主页": "Project homepage", "语言 / Language": "Language / 语言",
        "已测试 iPhone 12 · iOS 15.6\n其他机型与系统不保证可用。": "Tested: iPhone 12 · iOS 15.6\nOther devices and versions are not guaranteed.",
        "正在查找缓存": "Finding cache…", "找到图像缓存": "Image cache found", "未找到图像缓存": "No image cache found",
        "实际缓存文件 · 正方形显示区域": "Actual cache file · square display area", "关闭": "Close",
        "还没有图片": "No photo selected", "请选择一张图片。": "Please choose a photo.",
        "正在写入壁纸…": "Writing wallpapers…", "亮暗壁纸写入成功": "Both wallpapers saved",
        "操作失败": "Operation failed", "正在检查可清理图像…": "Checking cached images…",
        "无需清理": "Nothing to clear", "目录中没有可清理的缓存图像。": "There are no cached images to clear.",
        "无法清理": "Cannot clear cache", "正在清除缓存图像…": "Clearing cached images…",
        "清理完成": "Cache cleared", "清理未完成": "Clear incomplete",
        "已清除 %d 个缓存图像，不提供撤销。请连接 CarPlay，打开车机的壁纸设置并重新选择系统壁纸；断开后回到本应用刷新。": "Cleared %d cached images. This cannot be undone. Connect CarPlay and choose a system wallpaper to regenerate the cache, then disconnect and refresh this app.",
        "连接 CarPlay，在车机「设置 → 壁纸」选择系统壁纸，生成缓存。": "Connect CarPlay. Choose a system wallpaper in Settings → Wallpaper to generate the cache.",
        "断开 CarPlay，打开本应用，点击右上角刷新。": "Disconnect CarPlay. Open this app and tap Refresh at the top right.",
        "选择系列，在「缓存」查看原图尺寸；选择一张图片，同时写入亮暗壁纸。": "Select a family and inspect its images in Cache. Choose a photo and apply it to both appearances.",
        "写入成功后推荐重启手机，再重新连接 CarPlay 查看效果。": "After saving, restart the phone as recommended, then reconnect CarPlay to check the result.",
        "亮暗壁纸已写入。可先到「缓存」查看实际文件确认效果，推荐重启手机后重新连接 CarPlay。系统可能重新生成缓存，如未生效请返回应用刷新检查。": "Both wallpapers were saved. Inspect the actual files in Cache, then restart the phone and reconnect CarPlay. iOS may regenerate caches; refresh and inspect again if the change disappears.",
        "建议使用缓存原图尺寸，如 2048 × 2048 像素；请先到「缓存」查看。": "Use the original cache dimensions, e.g. 2048 × 2048. Check them in Cache first.",
        "建议图片尺寸：%@ 像素，与当前缓存原图一致。": "Recommended size: %@ pixels, matching the current cache.",
        "缓存原图：%@ 像素。亮暗尺寸不同，将分别完整留边适配。": "Cache dimensions: %@ pixels. Sizes differ; each appearance is fitted separately."
    ]
}
