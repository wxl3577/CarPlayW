import Foundation
import CryptoKit

struct CacheClearPlan {
    let directory: URL
    let fingerprints: [URL: String]
    var count: Int { fingerprints.count }
}

enum CacheCleaner {
    static let imageExtensions: Set<String> = ["cpbitmap", "bitmap", "atx", "png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"]
    // Bounded in-memory rollback only; never create persistent backups.
    static let maximumBytes = 128 * 1024 * 1024

    static func snapshot(directory: URL, fileManager: FileManager) throws -> [URL: Data] {
        let files = try fileManager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        var contents: [URL: Data] = [:]
        var total = 0
        for file in files where imageExtensions.contains(file.pathExtension.lowercased()) {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let size = values.fileSize ?? maximumBytes + 1
            guard size >= 0, size <= maximumBytes - total else {
                throw CarPlayWError.cacheClearFailed("缓存图像总量超过 128 MB，已停止清理。")
            }
            let data = try Data(contentsOf: file)
            guard data.count <= maximumBytes - total else {
                throw CarPlayWError.cacheClearFailed("缓存大小发生变化，请断开 CarPlay 后重试。")
            }
            total += data.count
            contents[file] = data
        }
        return contents
    }

    static func fingerprints(_ contents: [URL: Data]) -> [URL: String] {
        contents.mapValues { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }
}
