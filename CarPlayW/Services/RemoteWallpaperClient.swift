import Foundation
import UIKit
import ImageIO

protocol WallpaperLoading {
    func catalog() async throws -> [BuiltInWallpaper]
    func image(for wallpaper: BuiltInWallpaper) async throws -> UIImage
}

struct RemoteWallpaperClient: WallpaperLoading {
    static let catalogURL = URL(string: "https://480.pp.ua/web_share/carplay/yc/wallpapers.json")!
    typealias Download = (URLRequest) async throws -> (URL, URLResponse)
    private let download: Download
    private let cache: WallpaperImageCache
    let catalogURL: URL

    init(session: URLSession = .shared, catalogURL: URL = Self.catalogURL, cache: WallpaperImageCache = .shared) {
        self.download = { try await session.download(for: $0) }
        self.catalogURL = catalogURL
        self.cache = cache
    }

    init(catalogURL: URL = Self.catalogURL, cache: WallpaperImageCache = .shared, download: @escaping Download) {
        self.catalogURL = catalogURL
        self.cache = cache
        self.download = download
    }

    func catalog() async throws -> [BuiltInWallpaper] {
        let data = try await fetch(catalogURL, limit: 1_048_576)
        let wallpapers: [BuiltInWallpaper]
        do {
            wallpapers = try JSONDecoder().decode(WallpaperCatalog.self, from: data).resolved(relativeTo: catalogURL)
        } catch {
            throw RemoteWallpaperError.invalidCatalog
        }
        try await cache.reconcile(wallpapers)
        return wallpapers
    }

    func image(for wallpaper: BuiltInWallpaper) async throws -> UIImage {
        try Task.checkCancellation()
        if let data = await cache.read(wallpaper) {
            if let image = try? Self.decodeImage(data) {
                try Task.checkCancellation()
                return image
            }
            await cache.remove(wallpaper)
        }
        let ticket = await cache.ticket()
        let data = try await fetch(wallpaper.url, limit: 32 * 1_048_576)
        try Task.checkCancellation()
        let image = try Self.decodeImage(data)
        try await cache.save(data, for: wallpaper, ticket: ticket)
        return image
    }

    static func decodeImage(_ data: Data) throws -> UIImage {
        // Check dimensions before decoding. Preserve the original resolution.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 8192, height <= 8192,
              width * height <= 32_000_000,
              let image = UIImage(data: data), image.cgImage != nil else {
            throw RemoteWallpaperError.invalidImage
        }
        return image
    }

    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        // The catalog is always fresh; images reach the network only on a disk-cache miss.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (file, response) = try await download(request)
        defer { try? FileManager.default.removeItem(at: file) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RemoteWallpaperError.response((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard response.url?.scheme?.lowercased() == "https" else { throw RemoteWallpaperError.invalidCatalog }
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= limit else { throw RemoteWallpaperError.tooLarge }
        return try Data(contentsOf: file)
    }
}
