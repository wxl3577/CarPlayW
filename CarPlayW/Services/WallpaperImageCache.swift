import Foundation
import CryptoKit

/// Durable original images, separate from the CarPlay system wallpaper cache.
actor WallpaperImageCache {
    static let shared = WallpaperImageCache(directory: FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    )[0].appendingPathComponent("RemoteWallpapers", isDirectory: true))

    let directory: URL
    private var allowedKeys: Set<String>?
    private var generation = UUID()

    init(directory: URL) { self.directory = directory }

    nonisolated static func key(for wallpaper: BuiltInWallpaper) -> String {
        // Length-prefix the ID; neither server IDs nor URLs become filesystem paths.
        let identity = "\(wallpaper.id.utf8.count):\(wallpaper.id)\(wallpaper.url.absoluteString)"
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined() + ".image"
    }

    func read(_ wallpaper: BuiltInWallpaper) -> Data? {
        let key = Self.key(for: wallpaper)
        guard allowedKeys?.contains(key) != false else { return nil }
        let file = directory.appendingPathComponent(key)
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 32 * 1_048_576 else { return nil }
        return try? Data(contentsOf: file)
    }

    func remove(_ wallpaper: BuiltInWallpaper) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(Self.key(for: wallpaper)))
    }

    func ticket() -> UUID { generation }

    func save(_ data: Data, for wallpaper: BuiltInWallpaper, ticket: UUID) throws {
        try Task.checkCancellation()
        let key = Self.key(for: wallpaper)
        // A download started before a list refresh must never restore a removed image.
        guard ticket == generation, allowedKeys?.contains(key) != false else { return }
        try prepareDirectory()
        try data.write(to: directory.appendingPathComponent(key), options: .atomic)
    }

    /// Call only after a complete, valid server catalog has been received.
    func reconcile(_ wallpapers: [BuiltInWallpaper]) throws {
        try Task.checkCancellation()
        let keys = Set(wallpapers.map(Self.key(for:)))
        allowedKeys = keys
        generation = UUID()
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            if file.pathExtension == "image", !keys.contains(file.lastPathComponent) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var directory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }
}
