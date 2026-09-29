import SwiftUI

struct BuiltInWallpaperView: View {
    let onSelect: (UIImage, String) -> Void
    @StateObject private var model = WallpaperPickerModel.live()
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(model.wallpaper?.title(in: language) ?? language.text("在线壁纸"))
                    .font(.title2.bold()).accessibilityIdentifier("builtInWallpaperName")
                if let pixels = model.image?.cgImage {
                    Text("\(String(pixels.width)) × \(String(pixels.height)) \(language.text("像素"))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                GeometryReader { geometry in
                    ZStack {
                        SquareImage(image: model.image)
                            .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier("builtInSquarePreview")
                        if model.isLoading {
                            ProgressView(language.text(model.wallpapers.isEmpty ? "正在加载壁纸列表…" : "正在加载原图…"))
                                .padding().background(.regularMaterial).cornerRadius(12)
                                .accessibilityIdentifier("wallpaperLoading")
                        } else if let error = model.errorKey {
                            VStack(spacing: 12) {
                                Text(language.text(error)).multilineTextAlignment(.center)
                                Button(language.text("重试")) { model.retry() }
                                    .buttonStyle(.borderedProminent).accessibilityIdentifier("retryWallpaper")
                            }.padding().background(.regularMaterial).cornerRadius(12)
                        } else if model.wallpapers.isEmpty {
                            Text(language.text("暂无在线壁纸"))
                        }
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }
                HStack {
                    Button { model.select(at: model.selectedIndex - 1) } label: {
                        Label(language.text("上一张"), systemImage: "chevron.left")
                    }
                    .disabled(model.selectedIndex == 0 || model.wallpapers.isEmpty)
                    .accessibilityIdentifier("previousBuiltInWallpaper")
                    Spacer()
                    Text("\(model.wallpapers.isEmpty ? 0 : model.selectedIndex + 1) / \(model.wallpapers.count)")
                        .font(.subheadline.monospacedDigit()).accessibilityIdentifier("builtInWallpaperPosition")
                    Spacer()
                    Button { model.select(at: model.selectedIndex + 1) } label: {
                        Label(language.text("下一张"), systemImage: "chevron.right")
                    }
                    .disabled(model.selectedIndex >= model.wallpapers.count - 1)
                    .accessibilityIdentifier("nextBuiltInWallpaper")
                }.buttonStyle(.bordered)
                Text(language.text("原图下载后保留；选用后，返回壁纸页点击「同时写入亮暗壁纸」。"))
                    .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button {
                    guard let image = model.image, let wallpaper = model.wallpaper, !model.isLoading else { return }
                    onSelect(image, wallpaper.title(in: language))
                    dismiss()
                } label: {
                    Label(language.text("使用这张壁纸"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).disabled(model.image == nil || model.isLoading)
                .accessibilityIdentifier("useBuiltInWallpaper")
            }
            .padding(16)
            .navigationTitle(language.text("内置壁纸"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(language.text("刷新壁纸列表"))
                        .accessibilityIdentifier("refreshWallpaperCatalog")
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button(language.text("关闭")) { dismiss() } }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { model.reload() }
        .onDisappear { model.cancel() }
    }
}
