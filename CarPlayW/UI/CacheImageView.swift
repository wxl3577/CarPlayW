import SwiftUI

struct CacheImageView: View {
    let wallpaper: CachedWallpaper
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .chinese
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("\(wallpaper.dimensions) \(language.text("像素"))").font(.headline)
                    Text("\(wallpaper.fileSize) · \(wallpaper.byteCount) \(language.text("字节"))").font(.caption).foregroundColor(.secondary)
                    Text(wallpaper.fileName).font(.caption2).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                GeometryReader { geometry in
                    SquareImage(image: wallpaper.image)
                        .frame(width: min(geometry.size.width, geometry.size.height), height: min(geometry.size.width, geometry.size.height))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                Text(language.text("实际缓存文件 · 正方形显示区域"))
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(16)
            .navigationTitle(language.format("%@缓存原图", language.text(wallpaper.variant.title)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(language.text("关闭")) { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}
