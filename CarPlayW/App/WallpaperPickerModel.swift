import UIKit

@MainActor
final class WallpaperPickerModel: ObservableObject {
    @Published private(set) var wallpapers: [BuiltInWallpaper] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var errorKey: String?
    private let client: WallpaperLoading
    private var task: Task<Void, Never>?
    private var generation = UUID()

    var wallpaper: BuiltInWallpaper? {
        wallpapers.indices.contains(selectedIndex) ? wallpapers[selectedIndex] : nil
    }

    init(client: WallpaperLoading = RemoteWallpaperClient()) { self.client = client }

    static func live() -> WallpaperPickerModel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CPW_UI_FIXTURES"] == "1" {
            return WallpaperPickerModel(client: UITestWallpaperClient())
        }
        #endif
        return WallpaperPickerModel()
    }

    func reload() {
        cancel()
        let token = generation
        wallpapers = []
        selectedIndex = 0
        image = nil
        errorKey = nil
        isLoading = true
        task = Task {
            do {
                let catalog = try await client.catalog()
                guard token == generation, !Task.isCancelled else { return }
                wallpapers = catalog
                isLoading = false
                if !catalog.isEmpty { select(at: 0) }
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                errorKey = "壁纸列表加载失败，请检查网络后重试。"
                isLoading = false
            }
        }
    }

    func select(at index: Int) {
        guard wallpapers.indices.contains(index) else { return }
        cancel()
        let token = generation
        selectedIndex = index
        let requested = wallpapers[index]
        // Clear the previous image immediately; never select it under the next image's name.
        image = nil
        errorKey = nil
        isLoading = true
        task = Task {
            do {
                let result = try await client.image(for: requested)
                guard token == generation, !Task.isCancelled else { return }
                image = result
                isLoading = false
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                errorKey = "图片下载失败，请检查网络后重试。"
                isLoading = false
            }
        }
    }

    func retry() {
        if wallpapers.isEmpty { reload() } else { select(at: selectedIndex) }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        isLoading = false
    }
}
