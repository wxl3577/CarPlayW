import Foundation

struct BuiltInWallpaper: Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String?
    let url: URL

    func title(in language: AppLanguage) -> String {
        language == .english ? (englishName ?? name) : name
    }
}

struct WallpaperCatalog: Decodable {
    struct Entry: Decodable {
        let id: String
        let name: String
        let name_en: String?
        let url: String
    }
    let version: Int
    let wallpapers: [Entry]

    func resolved(relativeTo baseURL: URL) throws -> [BuiltInWallpaper] {
        guard version == 1, wallpapers.count <= 500 else { throw RemoteWallpaperError.invalidCatalog }
        var identifiers = Set<String>()
        return try wallpapers.map { entry in
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.id.isEmpty, !name.isEmpty, !entry.url.isEmpty,
                  identifiers.insert(entry.id).inserted,
                  let url = URL(string: entry.url, relativeTo: baseURL)?.absoluteURL,
                  url.scheme?.lowercased() == "https", url.host != nil,
                  url.user == nil, url.password == nil else { throw RemoteWallpaperError.invalidCatalog }
            let english = entry.name_en?.trimmingCharacters(in: .whitespacesAndNewlines)
            return BuiltInWallpaper(id: entry.id, name: name,
                                    englishName: english?.isEmpty == false ? english : nil, url: url)
        }
    }
}

enum RemoteWallpaperError: Error {
    case invalidCatalog, invalidImage, response(Int), tooLarge
}
