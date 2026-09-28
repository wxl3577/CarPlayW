import Foundation

final class CarPlayCacheLocator {
    static let families = ["CARWallpaperBlueGreenDynamic", "CARWallpaperRedBlueDynamic", "CARWallpaperRedDynamic"]
    private let fileManager: FileManager
    private let applicationContainerRoot: URL

    init(fileManager: FileManager = .default,
         applicationContainerRoot: URL = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application", isDirectory: true)) {
        self.fileManager = fileManager
        self.applicationContainerRoot = applicationContainerRoot
    }

    func locate() throws -> CarPlayCacheLocation { try locateAll()[0] }

    // Resolve the exact cache directory even when it has no supported pair.
    // Do not follow symlinks below the container root or choose among containers.
    func cacheDirectory() throws -> URL {
        let root = applicationContainerRoot.resolvingSymlinksInPath().standardizedFileURL
        let containers = try fileManager.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        var candidates: [URL] = []
        for container in containers {
            let values = try container.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
            var directory = container
            var valid = true
            for component in ["Library", "Caches", "MappedImageCache", "com.apple.CarPlayApp.wallpaper-images"] {
                directory.appendPathComponent(component, isDirectory: true)
                guard fileManager.fileExists(atPath: directory.path) else { valid = false; break }
                let properties = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard properties.isDirectory == true, properties.isSymbolicLink != true else { valid = false; break }
            }
            if valid { candidates.append(directory) }
        }
        guard candidates.count <= 1 else { throw CarPlayWError.multipleCaches(candidates.map(\.path)) }
        guard let directory = candidates.first else { throw CarPlayWError.cacheNotFound }
        return directory
    }

    func locateAll() throws -> [CarPlayCacheLocation] {
        guard fileManager.isReadableFile(atPath: applicationContainerRoot.path) else {
            throw CarPlayWError.cacheRootUnavailable(applicationContainerRoot.path)
        }
        let containers = try fileManager.contentsOfDirectory(at: applicationContainerRoot,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var locations: [CarPlayCacheLocation] = []
        var foundDirectory = false
        var discovered: [String] = []
        for container in containers {
            let directory = container.appendingPathComponent("Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images", isDirectory: true)
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            foundDirectory = true
            let urls = try fileManager.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            discovered += urls.map(\.lastPathComponent)
            for family in Self.families {
                var files: [WallpaperVariant: URL] = [:]
                for variant in WallpaperVariant.allCases {
                    let url = directory.appendingPathComponent("\(family)-\(variant.fileSuffix).cpbitmap")
                    if fileManager.fileExists(atPath: url.path) {
                        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                        guard values.isRegularFile == true, values.isSymbolicLink != true else {
                            throw CarPlayWError.invalidBitmap("目标不是普通文件：\(url.lastPathComponent)")
                        }
                        files[variant] = url
                    }
                }
                guard !files.isEmpty else { continue }
                for variant in WallpaperVariant.allCases {
                    files[variant] = directory.appendingPathComponent("\(family)-\(variant.fileSuffix).cpbitmap")
                }
                locations.append(CarPlayCacheLocation(directory: directory, files: files))
            }
        }
        let directories = Set(locations.map { $0.directory.path })
        guard directories.count <= 1 else { throw CarPlayWError.multipleCaches(directories.sorted()) }
        guard !locations.isEmpty else {
            if foundDirectory { throw CarPlayWError.wallpaperPairNotFound(discovered.sorted()) }
            throw CarPlayWError.cacheNotFound
        }
        return locations.sorted { $0.family < $1.family }
    }
}
