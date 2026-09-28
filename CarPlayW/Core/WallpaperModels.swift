import Foundation

enum WallpaperVariant: String, CaseIterable, Codable, Hashable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var fileSuffix: String { self == .light ? "Light" : "Dark" }

    var title: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var preferredFileName: String {
        switch self {
        case .light: return "CARWallpaperBlue-Light-14.cpbitmap"
        case .dark: return "CARWallpaperBlue-Dark-14.cpbitmap"
        }
    }
}

enum ImageLayoutMode: String, CaseIterable, Identifiable {
    case fill
    case fit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fill: return "裁切填满"
        case .fit: return "完整留边"
        }
    }
}

struct CarPlayCacheLocation {
    let directory: URL
    let files: [WallpaperVariant: URL]

    var family: String {
        (files[.light] ?? files[.dark])!.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-Light", with: "")
            .replacingOccurrences(of: "-Dark", with: "")
    }
}

enum CarPlayWError: LocalizedError {
    case cacheRootUnavailable(String)
    case cacheNotFound
    case multipleCaches([String])
    case wallpaperPairNotFound([String])
    case missingFiles([String])
    case invalidBitmap(String)
    case noImageSelected
    case cacheClearFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cacheRootUnavailable(let path):
            return "无法读取 CarPlay 容器根目录：\(path)。请确认 IPA 由 TrollStore 安装且 entitlement 已保留。"
        case .cacheNotFound:
            return "没有找到 com.apple.CarPlayApp.wallpaper-images。请先连接一次 CarPlay，并在车机中打开壁纸设置以生成缓存。"
        case .multipleCaches(let paths):
            return "检测到多个可用缓存，为避免覆盖错误容器，已停止写入：\n" + paths.joined(separator: "\n")
        case .wallpaperPairNotFound(let names):
            let discovered = names.isEmpty
                ? "没有扫描到壁纸位图文件。"
                : "当前扫描到：\n" + names.joined(separator: "\n")
            return "目标目录存在，但没有找到 BlueGreenDynamic、RedBlueDynamic 或 RedDynamic 的 cpbitmap 文件。每种至少需要已有一份 Light 或 Dark 文件。\n\(discovered)"
        case .missingFiles(let names):
            return "缓存目录存在，但缺少目标文件：" + names.joined(separator: "、")
        case .invalidBitmap(let reason):
            return "无法解析 cpbitmap：\(reason)"
        case .noImageSelected:
            return "请选择一张图片，将同时用于浅色和深色。"
        case .cacheClearFailed(let reason):
            return "清理未完成：\(reason)"
        case .writeFailed(let reason):
            return "写入失败，已尝试回滚：\(reason)"
        }
    }
}
