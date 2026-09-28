import Foundation
import UIKit

final class WallpaperService {
    private let locator: CarPlayCacheLocator
    private let fileManager: FileManager
    private var scannedLocation: CarPlayCacheLocation?

    init(locator: CarPlayCacheLocator = CarPlayCacheLocator(), fileManager: FileManager = .default) {
        self.locator = locator
        self.fileManager = fileManager
    }

    func availableLocations() throws -> [CarPlayCacheLocation] { try locator.locateAll() }

    func scan(at pinnedLocation: CarPlayCacheLocation? = nil) throws -> (CarPlayCacheLocation, [WallpaperVariant: UIImage]) {
        let (location, images) = try scanCache(at: pinnedLocation)
        return (location, images.mapValues(\.image))
    }

    func scanCache(at pinnedLocation: CarPlayCacheLocation? = nil) throws -> (CarPlayCacheLocation, [WallpaperVariant: CachedWallpaper]) {
        let location = try pinnedLocation ?? locator.locate()
        scannedLocation = location
        var previews: [WallpaperVariant: CachedWallpaper] = [:]
        for (variant, url) in location.files where fileManager.fileExists(atPath: url.path) {
            // Preview failure is not a write exemption: apply validates every template.
            guard let data = try? Data(contentsOf: url), let image = try? CPBitmapCodec.decode(data) else { continue }
            previews[variant] = CachedWallpaper(variant: variant, fileName: url.lastPathComponent,
                                               image: image, byteCount: data.count)
        }
        return (location, previews)
    }

    func prepareCacheClear() throws -> CacheClearPlan {
        let directory = try locator.cacheDirectory()
        return CacheClearPlan(directory: directory,
            fingerprints: CacheCleaner.fingerprints(try CacheCleaner.snapshot(directory: directory, fileManager: fileManager)))
    }

    func clearCache(_ plan: CacheClearPlan) throws -> Int {
        let directory = try locator.cacheDirectory()
        guard directory == plan.directory else {
            throw CarPlayWError.cacheClearFailed("缓存目录已变化，请重新确认。")
        }
        let contents = try CacheCleaner.snapshot(directory: directory, fileManager: fileManager)
        guard CacheCleaner.fingerprints(contents) == plan.fingerprints else {
            throw CarPlayWError.cacheClearFailed("确认后缓存发生变化，未删除文件。请断开 CarPlay 后重试。")
        }
        try writeTransaction([:], deletions: Array(contents.keys), expectedOriginals: contents)
        scannedLocation = nil
        return contents.count
    }

    func apply(image: UIImage, layout: ImageLayoutMode) throws -> CarPlayCacheLocation {
        let family = try scannedLocation?.family ?? locator.locate().family
        // Re-resolve the random container on each write. Never revive a removed pair.
        guard let location = try locator.locateAll().first(where: { $0.family == family }) else {
            throw CarPlayWError.missingFiles(["该系列至少需要已有一份亮或暗文件"])
        }
        var templates: [WallpaperVariant: Data] = [:]
        var originals: [URL: Data] = [:]
        for (variant, url) in location.files where fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            try CPBitmapCodec.validate(data)
            templates[variant] = data
            originals[url] = data
        }
        guard let source = originals.keys.first else {
            throw CarPlayWError.missingFiles(["当前系列没有缓存图像"])
        }
        var replacements: [URL: Data] = [:]
        var expectedImages: [URL: UIImage] = [:]
        for variant in WallpaperVariant.allCases {
            guard let target = location.files[variant],
                  let template = templates[variant] ?? templates[variant == .light ? .dark : .light] else {
                throw CarPlayWError.missingFiles([variant.title])
            }
            let permissionPath = fileManager.fileExists(atPath: target.path) ? target.path : location.directory.path
            guard fileManager.isWritableFile(atPath: permissionPath) else {
                throw CarPlayWError.writeFailed("没有缓存写入权限")
            }
            expectedImages[target] = try CPBitmapCodec.expectedImage(image: image, template: template, layout: layout)
            replacements[target] = try CPBitmapCodec.encode(image: image, using: template, layout: layout)
            try CPBitmapCodec.validate(replacements[target]!, against: expectedImages[target])
        }
        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        try writeTransaction(replacements, expectedImages: expectedImages,
            creationAttributes: attributes, expectedOriginals: originals)
        scannedLocation = location
        return location
    }

    func writeTransaction(_ replacements: [URL: Data], expectedImages: [URL: UIImage] = [:],
                          creationAttributes: [FileAttributeKey: Any] = [:], deletions: [URL] = [],
                          expectedOriginals: [URL: Data]? = nil) throws {
        var originals: [URL: Data] = [:]
        var attributes: [URL: [FileAttributeKey: Any]] = [:]
        var attempted: [URL] = []
        do {
            let targets = Set(replacements.keys).union(deletions).sorted { $0.path < $1.path }
            for target in targets {
                if fileManager.fileExists(atPath: target.path) {
                    let values = try target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else {
                        throw CarPlayWError.writeFailed("目标不是普通文件")
                    }
                    originals[target] = try Data(contentsOf: target)
                    attributes[target] = try fileManager.attributesOfItem(atPath: target.path)
                }
            }

            if let expectedOriginals, originals != expectedOriginals {
                throw CarPlayWError.writeFailed("缓存已变化，请断开 CarPlay 后重试")
            }
            for target in targets {
                let fresh = URL(fileURLWithPath: target.path)
                if fileManager.fileExists(atPath: fresh.path) {
                    let values = try fresh.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true else {
                        throw CarPlayWError.writeFailed("目标文件类型已变化，请刷新后重试")
                    }
                }
                let current = fileManager.fileExists(atPath: target.path) ? try Data(contentsOf: target) : nil
                guard current == originals[target] else {
                    throw CarPlayWError.writeFailed("缓存被系统更新，请断开 CarPlay 后刷新")
                }
                attempted.append(target)
                guard let data = replacements[target] else {
                    if current != nil { try fileManager.removeItem(at: target) }
                    continue
                }
                try data.write(to: target, options: .atomic)
                try restoreAttributes(attributes[target] ?? creationAttributes, to: target)
                let readBack = try Data(contentsOf: target)
                guard readBack == data else {
                    throw CarPlayWError.writeFailed("写后校验失败：\(target.lastPathComponent)")
                }
                if let expected = expectedImages[target] {
                    try CPBitmapCodec.validate(readBack, against: expected)
                }
            }
        } catch {
            var failedRollbacks: [String] = []
            for target in attempted.reversed() {
                do {
                    guard let data = originals[target] else {
                        if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
                        continue
                    }
                    try data.write(to: target, options: .atomic)
                    try restoreAttributes(attributes[target] ?? [:], to: target)
                    guard try Data(contentsOf: target) == data else {
                        throw CarPlayWError.writeFailed("回滚读回不一致")
                    }
                } catch {
                    failedRollbacks.append(target.lastPathComponent)
                }
            }
            let recovery = failedRollbacks.isEmpty ? "本次已写入的文件已回滚。" :
                "以下文件未能还原，请重新连接 CarPlay 并重新选择系统壁纸生成缓存：" + failedRollbacks.joined(separator: "、")
            throw CarPlayWError.writeFailed(error.localizedDescription + "\n" + recovery)
        }
    }

    private func restoreAttributes(_ attributes: [FileAttributeKey: Any], to target: URL) throws {
        let current = try fileManager.attributesOfItem(atPath: target.path)
        for key in [FileAttributeKey.ownerAccountID, .groupOwnerAccountID, .posixPermissions] {
            if let value = attributes[key] as? NSNumber, value != current[key] as? NSNumber {
                try fileManager.setAttributes([key: value], ofItemAtPath: target.path)
            }
        }
        if let protection = attributes[.protectionKey] {
            try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: target.path)
        }
    }
}
