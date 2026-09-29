import SwiftUI

struct BuiltInWallpaperView: View {
    let onSelect: (UIImage) -> Void
    private let image = BuiltInWallpaper.load()
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(language.text(BuiltInWallpaper.name)).font(.title2.bold())
                if let pixels = image?.cgImage {
                    Text("\(pixels.width) × \(pixels.height) \(language.text("像素"))")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                GeometryReader { geometry in
                    SquareImage(image: image)
                        .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("builtInSquarePreview")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                Text(language.text(image == nil ? "内置图片无法加载，请重新安装应用。" : "选用后，返回壁纸页点击「同时写入亮暗壁纸」。"))
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    guard let image else { return }
                    onSelect(image)
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
}
