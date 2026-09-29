import SwiftUI

struct BuiltInWallpaperView: View {
    let onSelect: (UIImage, String) -> Void
    @State private var selectedIndex = 0
    @State private var image = BuiltInWallpaper.alpineReflection.load()
    private var wallpaper: BuiltInWallpaper { BuiltInWallpaper.all[selectedIndex] }
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(language.text(wallpaper.name)).font(.title2.bold())
                    .accessibilityIdentifier("builtInWallpaperName")
                if let pixels = image?.cgImage {
                    Text("\(String(pixels.width)) × \(String(pixels.height)) \(language.text("像素"))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                GeometryReader { geometry in
                    SquareImage(image: image)
                        .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("builtInSquarePreview")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                HStack {
                    Button { selectWallpaper(at: selectedIndex - 1) } label: {
                        Label(language.text("上一张"), systemImage: "chevron.left")
                    }
                    .disabled(selectedIndex == 0)
                    .accessibilityIdentifier("previousBuiltInWallpaper")
                    Spacer()
                    Text("\(selectedIndex + 1) / \(BuiltInWallpaper.all.count)")
                        .font(.subheadline.monospacedDigit())
                        .accessibilityIdentifier("builtInWallpaperPosition")
                    Spacer()
                    Button { selectWallpaper(at: selectedIndex + 1) } label: {
                        Label(language.text("下一张"), systemImage: "chevron.right")
                    }
                    .disabled(selectedIndex == BuiltInWallpaper.all.count - 1)
                    .accessibilityIdentifier("nextBuiltInWallpaper")
                }
                .buttonStyle(.bordered)
                Text(language.text(image == nil ? "内置图片无法加载，请重新安装应用。" : "选用后，返回壁纸页点击「同时写入亮暗壁纸」。"))
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    guard let image else { return }
                    onSelect(image, wallpaper.name)
                    dismiss()
                } label: {
                    Label(language.text("使用这张壁纸"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).disabled(image == nil)
                .accessibilityIdentifier("useBuiltInWallpaper")
            }
            .padding(16)
            .navigationTitle(language.text("内置壁纸"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(language.text("关闭")) { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }

    private func selectWallpaper(at index: Int) {
        guard BuiltInWallpaper.all.indices.contains(index) else { return }
        selectedIndex = index
        // Keep only the current full-resolution image in memory.
        image = BuiltInWallpaper.all[index].load()
    }
}
