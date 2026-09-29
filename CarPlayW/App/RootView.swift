import SwiftUI

struct RootView: View {
    enum Page: Hashable { case wallpaper, cache, guide, about }
    @StateObject private var model = AppModel()
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese
    @State private var page: Page = .wallpaper
    @State private var showingPhotoPicker = false
    @State private var viewingImage: CachedWallpaper?

    var body: some View {
        TabView(selection: $page) {
            pageShell("CarPlayW") { wallpaperPage }
                .tabItem { Label(t("壁纸"), systemImage: "photo") }.tag(Page.wallpaper)
            pageShell(t("缓存图像")) { cachePage }
                .tabItem { Label(t("缓存"), systemImage: "square.stack") }.tag(Page.cache)
            pageShell(t("使用说明")) { guidePage }
                .tabItem { Label(t("说明"), systemImage: "list.number") }.tag(Page.guide)
            pageShell(t("关于")) { aboutPage }
                .tabItem { Label(t("关于"), systemImage: "info.circle") }.tag(Page.about)
        }
        .task { model.scan() }
        .fullScreenCover(isPresented: $showingPhotoPicker) {
            PhotoPicker { image in
                showingPhotoPicker = false
                if let image { model.setSelectedImage(image) }
            }
        }
        .fullScreenCover(item: $viewingImage) { CacheImageView(wallpaper: $0) }
        .alert(item: $model.notice) { notice in
            Alert(title: Text(t(notice.title)), message: Text(t(notice.message)), dismissButton: .default(Text(t("知道了"))))
        }
        .confirmationDialog(language.format("清除全部 %d 个缓存图像？", model.clearCount), isPresented: $model.showingClearConfirmation, titleVisibility: .visible) {
            Button(t("确认已断开 CarPlay，清除全部"), role: .destructive, action: model.clearCache)
            Button(t("取消"), role: .cancel, action: model.cancelClearCache)
        } message: {
            Text(t("清除所有系列的缓存图像，无备份、不可撤销。不删除子目录或其他类型文件。之后需连接 CarPlay 并选择系统壁纸重新生成缓存。"))
        }
        .environment(\.locale, Locale(identifier: language.rawValue))
    }

    private func t(_ key: String) -> String { language.text(key) }

    /// Fixed pages: no ScrollView, List, or draggable bottom sheet.
    private func pageShell<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        NavigationView {
            content()
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if page == .wallpaper || page == .cache {
                            Button(action: model.scan) { Label(t("刷新缓存"), systemImage: "arrow.clockwise") }
                                .disabled(model.isBusy)
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }

    private var wallpaperPage: some View {
        VStack(spacing: 10) {
            statusCard
            Panel {
                familyPicker
                Button { page = .cache } label: {
                    Label(t("查看当前系列缓存图像"), systemImage: "eye")
                        .font(.subheadline)
                }
                .disabled(model.isBusy || model.currentLocation == nil)
            }
            Panel {
                HStack {
                    Label(t("选择图片"), systemImage: "photo.on.rectangle").font(.headline)
                    Spacer()
                    if model.selectedImage != nil {
                        Button(t("移除"), action: model.clearSelectedImage).font(.caption)
                    }
                    Button(t(model.selectedImage == nil ? "选择" : "更换")) { showingPhotoPicker = true }
                        .buttonStyle(.bordered)
                }
                .disabled(model.isBusy)
                if let image = model.selectedImage {
                    SquareImage(image: image).frame(width: 152, height: 152)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("selectedSquareImage")
                        .frame(maxWidth: .infinity)
                }
                Text(t("完整留边写入，不拉伸、不裁切。"))
                    .font(.footnote).foregroundColor(.secondary)
                Text(t("显示比例 1:1 · 建议 2048 × 2048 像素"))
                    .font(.caption).foregroundColor(.secondary)
                Text(CachedWallpaper.recommendation(for: model.cachedImages, language: language))
                    .font(.caption).foregroundColor(.secondary)
                    .accessibilityIdentifier("recommendedDimensions")
            }
            Spacer(minLength: 0)
            Button(action: model.apply) {
                Label(t("同时写入亮暗壁纸"), systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canWrite || model.selectedImage == nil)
        }
    }

    private var cachePage: some View {
        VStack(spacing: 14) {
            statusCard
            Panel { familyPicker }
            HStack(alignment: .top, spacing: 12) {
                ForEach(WallpaperVariant.allCases) { variant in
                    cacheTile(variant)
                }
            }
            Text(t("点击原图查看尺寸。刷新或写入后重新读取实际文件。"))
                .font(.footnote).foregroundColor(.secondary)
            Spacer(minLength: 0)
            Panel {
                Button(role: .destructive, action: model.prepareClearCache) {
                    Label(t("清除全部缓存图像"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).disabled(model.isBusy)
                Text(t("先断开 CarPlay。删除所有系列图像，无备份、不可撤销。"))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var familyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("壁纸系列")).font(.caption).foregroundColor(.secondary)
            HStack {
                Text(model.selectedFamily.isEmpty ? t("暂无可修改系列") : model.selectedFamily.replacingOccurrences(of: "CARWallpaper", with: ""))
                    .font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
            }
            Menu {
                Picker(t("壁纸系列"), selection: Binding(get: { model.selectedFamily }, set: { model.selectFamily($0) })) {
                    ForEach(model.availableLocations, id: \.family) { location in
                        Text(location.family.replacingOccurrences(of: "CARWallpaper", with: "")).tag(location.family)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up")
                    Text(t("选择 / 切换系列"))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline.bold()).padding(.vertical, 9).padding(.horizontal, 12)
                .foregroundColor(.white).background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("familySelector")
            .disabled(model.isBusy || model.availableLocations.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cacheTile(_ variant: WallpaperVariant) -> some View {
        Panel {
            Text(t(variant.title)).font(.subheadline.bold())
            if let cached = model.cachedImages[variant] {
                Button { viewingImage = cached } label: {
                    SquareImage(image: cached.image)
                }
                .disabled(model.isBusy)
                .accessibilityLabel(language.format("查看%@缓存原图", t(variant.title)))
                Text("\(cached.dimensions) \(t("像素"))").font(.caption).minimumScaleFactor(0.8)
                Text(cached.fileSize).font(.caption).foregroundColor(.secondary)
            } else {
                SquareImage(image: nil)
                Text(t("暂无可读图像")).font(.caption).foregroundColor(.secondary)
                Text(t("缺失或无法读取")).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var guidePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel {
                ForEach(Array(UsageGuide.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)").font(.subheadline.bold()).foregroundColor(.accentColor)
                            .frame(width: 28, height: 28).background(Color.accentColor.opacity(0.1)).clipShape(Circle())
                        Text(t(step)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 5)
                }
            }
            Text(t(UsageGuide.imageExample))
                .font(.footnote).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("imageSizeExample")
            Text(t("请停车后操作。刷新仅读取手机已有缓存。"))
                .font(.footnote).foregroundColor(.secondary)
            Text(t("重启或切换系统壁纸可能重建缓存；如效果消失，请刷新检查。"))
                .font(.footnote).foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var aboutPage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "car.fill").font(.system(size: 34)).foregroundColor(.white)
                .frame(width: 88, height: 88)
                .background(LinearGradient(colors: [.blue, .purple], startPoint: .bottomLeading, endPoint: .topTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("CarPlayW").font(.title2.bold())
                Text(t("让车机壁纸，多一点你的风格。"))
                    .font(.subheadline).foregroundColor(.secondary)
                Text("v\(model.version)").font(.caption.monospacedDigit())
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1)).clipShape(Capsule())
            }
            Panel {
                HStack { Text(t("作者")).foregroundColor(.secondary); Spacer(); Text("鱼头") }
                Divider()
                Text(t("语言 / Language")).font(.caption).foregroundColor(.secondary)
                Picker("Language", selection: $language) {
                    Text("简体中文").tag(AppLanguage.chinese)
                    Text("English").tag(AppLanguage.english)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("languageSelector")
                Divider()
                Link(destination: UsageGuide.projectURL) {
                    HStack { Label(t("项目主页"), systemImage: "link"); Spacer(); Image(systemName: "arrow.up.right") }
                }
            }
            Text(t(UsageGuide.testedDeviceMessage))
                .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .scanning:
                ProgressView(); Text(t("正在查找缓存"))
            case .working(let message):
                ProgressView(); Text(t(message))
            case .ready:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text(t("找到图像缓存"))
            case .unavailable:
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(t("未找到图像缓存"))
            }
            Spacer(minLength: 0)
        }
        .font(.subheadline.bold()).padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct Panel<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
