import Darwin
import Foundation
import ImageIO
import UIKit

enum SystemCPBitmapDecoder {
    // Route by container bytes, not filename. AAPL/ATX wallpapers are textures,
    // not the legacy raw CPBitmap serialization accepted by AppSupport.
    private typealias Decoder = @convention(c) (
        CFData, UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFArray>?

    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/AppSupport.framework/AppSupport", RTLD_LAZY
    )

    static var validationLabel: String {
        #if targetEnvironment(simulator)
        return "ATX → 软件 ASTC（Arm 5.3.0 / Morton32）；模拟器测试不代表车机验证"
        #else
        return "ATX → 软件 ASTC（Arm 5.3.0 / Morton32）；传统位图 → AppSupport"
        #endif
    }

    static func decode(_ data: Data) throws -> UIImage {
        if data.starts(with: [0x41, 0x41, 0x50, 0x4C, 13, 10, 26, 10]) {
            return try decodeATX(data)
        }
        #if targetEnvironment(simulator)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CarPlayWError.invalidBitmap("模拟器 ImageIO 无法解码")
        }
        return UIImage(cgImage: image)
        #else
        guard let handle, let symbol = dlsym(handle, "CPBitmapCreateImagesFromData") else {
            throw CarPlayWError.invalidBitmap("本机 CPBitmap 解码接口不可用，已停止写入")
        }
        let decoder = unsafeBitCast(symbol, to: Decoder.self)
        guard let array = decoder(data as CFData, nil, 1, nil)?.takeRetainedValue(),
              CFArrayGetCount(array) == 1,
              let pointer = CFArrayGetValueAtIndex(array, 0) else {
            throw CarPlayWError.invalidBitmap("本机传统 CPBitmap 解码失败（非 ATX 路径），已停止写入")
        }
        let object = Unmanaged<CFTypeRef>.fromOpaque(pointer).takeUnretainedValue()
        guard CFGetTypeID(object) == CGImage.typeID else {
            throw CarPlayWError.invalidBitmap("CPBitmap 解码未返回 CGImage")
        }
        let image = unsafeBitCast(object, to: CGImage.self)
        return UIImage(cgImage: image)
        #endif
    }

    // A real ASTC-to-RGBA decode, independent of iOS ImageIO's ATX rasterizer.
    static func decodeATX(_ data: Data) throws -> UIImage {
        try SoftwareATXCodec.decode(data)
    }

    // Kept only as an explicit test/reference reader, never a write gate.
    static func decodeATXWithImageIO(_ data: Data) throws -> UIImage {
        let container = try ATXContainer(data)
        let input = container.imageIOData
        let options: [CFString: Any] = [
            kCGImageSourceTypeIdentifierHint: "com.apple.atx",
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(input as CFData, options as CFDictionary) else {
            let supported = (CGImageSourceCopyTypeIdentifiers() as NSArray).contains("com.apple.atx")
            throw CarPlayWError.invalidBitmap("ATX ImageIO 无法建立图像源；系统声明 ATX 支持：\(supported)")
        }
        let count = CGImageSourceGetCount(source)
        let type = CGImageSourceGetType(source).map { $0 as String } ?? "未知"
        guard count == 1, let image = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            throw CarPlayWError.invalidBitmap(
                "ATX ImageIO 解码失败；类型=\(type)，图像数=\(count)，状态=\(CGImageSourceGetStatus(source).rawValue)，输入=\(input.count)字节。未写入文件。"
            )
        }
        guard image.width == container.width, image.height == container.height else {
            throw CarPlayWError.invalidBitmap("ATX ImageIO 解码尺寸与 HEAD 不匹配")
        }
        return UIImage(cgImage: image)
    }
}
