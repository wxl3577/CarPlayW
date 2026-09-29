import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case scanning
        case ready
        case working(String)
        case unavailable
    }

    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var phase: Phase = .unavailable
    @Published var selectedImage: UIImage?
    @Published var selectedImageName: String?
    @Published var cachedImages: [WallpaperVariant: CachedWallpaper] = [:]
    @Published var notice: Notice?
    @Published var availableLocations: [CarPlayCacheLocation] = []
    @Published var selectedFamily = ""
    @Published var currentLocation: CarPlayCacheLocation?
    @Published var showingClearConfirmation = false
    @Published var clearCount = 0
    private var clearPlan: CacheClearPlan?
    private let service: WallpaperService
    private let queue = DispatchQueue(label: "dev.carplaycanvas.files", qos: .userInitiated)

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CPW_UI_FIXTURES"] == "1",
           let fixture = try? UITestFixtures.make() {
            service = fixture.service
            selectedImage = fixture.image
            return
        }
        #endif
        service = WallpaperService()
    }

    var isBusy: Bool {
        if case .working = phase { return true }
        return phase == .scanning || showingClearConfirmation
    }
    var canWrite: Bool { phase == .ready && !isBusy && currentLocation != nil }
    var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2" }
    var recommendedDimensions: String { CachedWallpaper.recommendation(for: cachedImages) }

    func setSelectedImage(_ image: UIImage, name: String? = nil) {
        selectedImage = image
        selectedImageName = name
    }
    func clearSelectedImage() {
        selectedImage = nil
        selectedImageName = nil
    }

    func selectFamily(_ family: String) {
        guard !isBusy else { return }
        selectedFamily = family
        scan()
    }

    func scan() {
        guard !isBusy else { return }
        phase = .scanning
        cachedImages = [:]
        let requestedFamily = selectedFamily
        let service = service
        queue.async {
            let result = Result { () -> ([CarPlayCacheLocation], CarPlayCacheLocation, [WallpaperVariant: CachedWallpaper]) in
                let locations = try service.availableLocations()
                guard let location = locations.first(where: { $0.family == requestedFamily }) ?? locations.first else {
                    throw CarPlayWError.cacheNotFound
                }
                let (_, images) = try service.scanCache(at: location)
                return (locations, location, images)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let (locations, location, images)):
                    self.availableLocations = locations
                    self.selectedFamily = location.family
                    self.currentLocation = location
                    self.cachedImages = images
                    self.phase = .ready
                case .failure:
                    self.resetCacheState()
                }
            }
        }
    }

    func apply() {
        guard canWrite else { return }
        guard let image = selectedImage else {
            notice = Notice(title: "还没有图片", message: "请选择一张图片。")
            return
        }
        let service = service
        phase = .working("正在写入壁纸…")
        queue.async {
            let result = Result { try service.apply(image: image, layout: .fit) }
            let refreshed = result.flatMap { location in Result { try service.scanCache(at: location) } }
            DispatchQueue.main.async {
                switch refreshed {
                case .success(let (location, images)):
                    self.currentLocation = location
                    self.cachedImages = images
                    self.clearSelectedImage()
                    self.phase = .ready
                    self.notice = Notice(title: "亮暗壁纸写入成功", message: UsageGuide.writeSuccessMessage)
                case .failure(let error):
                    self.phase = .ready
                    self.notice = Notice(title: "操作失败", message: AppLanguage.load().errorMessage(error))
                }
            }
        }
    }

    func prepareClearCache() {
        guard !isBusy else { return }
        let previous = phase
        phase = .working("正在检查可清理图像…")
        let service = service
        queue.async {
            let result = Result { try service.prepareCacheClear() }
            DispatchQueue.main.async {
                self.phase = previous
                switch result {
                case .success(let plan):
                    guard plan.count > 0 else {
                        self.notice = Notice(title: "无需清理", message: "目录中没有可清理的缓存图像。")
                        return
                    }
                    self.clearPlan = plan
                    self.clearCount = plan.count
                    self.showingClearConfirmation = true
                case .failure(let error):
                    self.notice = Notice(title: "无法清理", message: AppLanguage.load().errorMessage(error))
                }
            }
        }
    }

    func cancelClearCache() {
        clearPlan = nil
        showingClearConfirmation = false
    }

    func clearCache() {
        guard let plan = clearPlan else { return }
        clearPlan = nil
        showingClearConfirmation = false
        phase = .working("正在清除缓存图像…")
        let service = service
        queue.async {
            let result = Result { try service.clearCache(plan) }
            DispatchQueue.main.async {
                self.resetCacheState()
                self.clearSelectedImage()
                switch result {
                case .success(let count):
                    self.notice = Notice(title: "清理完成", message: AppLanguage.load().format("已清除 %d 个缓存图像，不提供撤销。请连接 CarPlay，打开车机的壁纸设置并重新选择系统壁纸；断开后回到本应用刷新。", count))
                case .failure(let error):
                    self.notice = Notice(title: "清理未完成", message: AppLanguage.load().errorMessage(error))
                }
            }
        }
    }

    private func resetCacheState() {
        cachedImages = [:]
        currentLocation = nil
        availableLocations = []
        selectedFamily = ""
        phase = .unavailable
    }
}
