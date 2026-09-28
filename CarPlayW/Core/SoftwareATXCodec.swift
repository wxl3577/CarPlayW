import Foundation
import UIKit

// Observed iOS 15.6 layout: 32x32 ASTC blocks per 128px macro-tile,
// row-major macro-tiles, even Morton bits = X, odd bits = Y. No heuristic
// chooses an orientation from the user's image. Unknown layouts fail closed.
enum SoftwareATXCodec {
    static func checkLayout(_ container: ATXContainer) throws {
        guard container.width <= 4096, container.height <= 4096,
              container.width % 128 == 0, container.height % 128 == 0 else {
            throw CarPlayWError.invalidBitmap("软件 ATX 仅支持已验证的 128 像素整块布局（最大 4096）")
        }
        let expected: [UInt32] = [1, 0, 0, 0, 0x93B0, 0x1908, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 5]
        for index in 0..<21 where index != 6 && index != 7 && !(15...18).contains(index) {
            let value = try ATXContainer.uint32(container.data, container.head.lowerBound + index * 4)
            guard value == expected[index] else {
                throw CarPlayWError.invalidBitmap("ATX 布局未验证：HEAD[\(index * 4)]=\(value)，预期 \(expected[index])")
            }
        }
        guard container.chunks.first(where: { $0.tag.lowercased() == "astc" })?.tag == "astc" else {
            throw CarPlayWError.invalidBitmap("软件 ATX 仅支持样本中已验证的小写 astc 布局")
        }
    }

    static func reorder(_ input: Data, width: Int, height: Int, toLinear: Bool) throws -> Data {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              width % 128 == 0, height % 128 == 0, input.count == width * height else {
            throw CarPlayWError.invalidBitmap("ASTC 分块尺寸不匹配")
        }
        let blocksWide = width / 4
        var result = Data(count: input.count)
        input.withUnsafeBytes { srcRaw in
            result.withUnsafeMutableBytes { dstRaw in
                let src = srcRaw.bindMemory(to: UInt8.self).baseAddress!
                let dst = dstRaw.bindMemory(to: UInt8.self).baseAddress!
                var tiledOffset = 0
                for macroY in stride(from: 0, to: height / 4, by: 32) {
                    for macroX in stride(from: 0, to: blocksWide, by: 32) {
                        for z in 0..<1024 {
                            var x = 0, y = 0
                            for bit in 0..<5 {
                                x |= ((z >> (bit * 2)) & 1) << bit
                                y |= ((z >> (bit * 2 + 1)) & 1) << bit
                            }
                            let linearOffset = ((macroY + y) * blocksWide + macroX + x) * 16
                            let sourceOffset = toLinear ? tiledOffset : linearOffset
                            let targetOffset = toLinear ? linearOffset : tiledOffset
                            dst.advanced(by: targetOffset).update(from: src.advanced(by: sourceOffset), count: 16)
                            tiledOffset += 16
                        }
                    }
                }
            }
        }
        return result
    }

    static func decode(_ data: Data) throws -> UIImage {
        let container = try ATXContainer(data)
        try checkLayout(container)
        let linear = try reorder(data.subdata(in: container.pixels), width: container.width,
                                 height: container.height, toLinear: true)
        var rgba = Data(count: container.width * container.height * 4)
        let outputCount = rgba.count
        let code = linear.withUnsafeBytes { source in
            rgba.withUnsafeMutableBytes { destination in
                CCDecodeASTC(source.bindMemory(to: UInt8.self).baseAddress, linear.count,
                             UInt32(container.width), UInt32(container.height),
                             destination.bindMemory(to: UInt8.self).baseAddress, outputCount)
            }
        }
        try checkResult(code)
        guard let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(width: container.width, height: container.height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: container.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw CarPlayWError.invalidBitmap("无法从 ASTC 像素创建图像")
        }
        return UIImage(cgImage: image)
    }

    static func encode(_ image: UIImage, template: Data) throws -> Data {
        let container = try ATXContainer(template)
        try checkLayout(container)
        guard let cgImage = image.cgImage, cgImage.width == container.width, cgImage.height == container.height else {
            throw CarPlayWError.invalidBitmap("软件 ASTC 编码输入尺寸不匹配")
        }
        var rgba = Data(count: container.width * container.height * 4)
        let rendered = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: container.width, height: container.height,
                bitsPerComponent: 8, bytesPerRow: container.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: container.width, height: container.height))
            return true
        }
        guard rendered else { throw CarPlayWError.invalidBitmap("无法提取 ASTC 编码像素") }
        var linear = Data(count: container.pixels.count)
        let outputCount = linear.count
        let code = rgba.withUnsafeBytes { source in
            linear.withUnsafeMutableBytes { destination in
                CCEncodeASTC(source.bindMemory(to: UInt8.self).baseAddress, rgba.count,
                             UInt32(container.width), UInt32(container.height),
                             destination.bindMemory(to: UInt8.self).baseAddress, outputCount)
            }
        }
        try checkResult(code)
        let tiled = try reorder(linear, width: container.width, height: container.height, toLinear: false)
        var result = template
        result.replaceSubrange(container.pixels, with: tiled)
        _ = try ATXContainer(result)
        return result
    }

    private static func checkResult(_ code: Int32) throws {
        guard code == 0 else {
            throw CarPlayWError.invalidBitmap("软件 ASTC：\(String(cString: CCASTCError(code)))")
        }
    }
}
