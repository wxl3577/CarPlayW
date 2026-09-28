import CoreGraphics
import Foundation
import ImageIO
import UIKit

enum CPBitmapContainerFormat: Equatable {
    case legacyRawBGRA
    case appleATX
}

struct CPBitmapMetadata: Equatable {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let pixelByteCount: Int
    let containerFormat: CPBitmapContainerFormat
}

enum CPBitmapCodec {
    private static let footerSize = 24
    private static let rowAlignmentInPixels = 16
    private static let atxMagic = Data([0x41, 0x41, 0x50, 0x4C, 0x0D, 0x0A, 0x1A, 0x0A])

    static func metadata(from data: Data) throws -> CPBitmapMetadata {
        if data.starts(with: atxMagic) {
            return try atxMetadata(from: data)
        }
        return try legacyMetadata(from: data)
    }

    private static func legacyMetadata(from data: Data) throws -> CPBitmapMetadata {
        guard data.count >= footerSize else {
            throw CarPlayWError.invalidBitmap("文件不足 24 字节")
        }

        // iOS 12+ cpbitmap footer layout. Width and height are the second and
        // third little-endian Int32 values in the last 24 bytes.
        let width = Int(try littleEndianInt32(in: data, at: data.count - 20))
        let height = Int(try littleEndianInt32(in: data, at: data.count - 16))
        guard width > 0, height > 0, width <= 16_384, height <= 16_384 else {
            throw CarPlayWError.invalidBitmap("尺寸异常：\(width) × \(height)")
        }

        let alignedWidth = ((width + rowAlignmentInPixels - 1) / rowAlignmentInPixels) * rowAlignmentInPixels
        let (bytesPerRow, rowOverflow) = alignedWidth.multipliedReportingOverflow(by: 4)
        let (pixelByteCount, imageOverflow) = bytesPerRow.multipliedReportingOverflow(by: height)
        guard !rowOverflow, !imageOverflow, pixelByteCount <= data.count - footerSize else {
            throw CarPlayWError.invalidBitmap("像素区长度与文件不匹配")
        }

        return CPBitmapMetadata(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixelByteCount: pixelByteCount,
            containerFormat: .legacyRawBGRA
        )
    }

    private static func atxMetadata(from data: Data) throws -> CPBitmapMetadata {
        let container = try ATXContainer(data)
        return CPBitmapMetadata(
            width: container.width, height: container.height,
            bytesPerRow: 0, pixelByteCount: container.pixels.count,
            containerFormat: .appleATX
        )
    }

    static func encode(
        image: UIImage,
        using template: Data,
        layout: ImageLayoutMode,
        letterboxColor: UIColor = .black
    ) throws -> Data {
        let metadata = try metadata(from: template)
        if metadata.containerFormat == .appleATX {
            return try encodeATX(
                image: image,
                template: template,
                metadata: metadata,
                layout: layout,
                letterboxColor: letterboxColor
            )
        }

        let pixels = try renderPixels(
            image: image,
            metadata: metadata,
            layout: layout,
            letterboxColor: letterboxColor
        )

        var result = template
        result.replaceSubrange(0..<metadata.pixelByteCount, with: pixels)
        return result
    }

    static func decode(_ data: Data) throws -> UIImage {
        let metadata = try metadata(from: data)
        if metadata.containerFormat == .appleATX {
            return try SystemCPBitmapDecoder.decode(data)
        }

        let pixelData = data.subdata(in: 0..<metadata.pixelByteCount)
        guard let provider = CGDataProvider(data: pixelData as CFData),
              let image = CGImage(
                width: metadata.width,
                height: metadata.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: metadata.bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw CarPlayWError.invalidBitmap("无法创建预览图像")
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    private static func encodeATX(
        image: UIImage,
        template: Data,
        metadata: CPBitmapMetadata,
        layout: ImageLayoutMode,
        letterboxColor: UIColor
    ) throws -> Data {
        let rendered = renderImage(
            image: image,
            metadata: metadata,
            layout: layout,
            letterboxColor: letterboxColor
        )
        let result = try SoftwareATXCodec.encode(rendered, template: template)
        try validate(result, against: rendered)
        return result
    }

    // Force rasterization: creating an image object alone can defer decoding.
    static func validate(_ data: Data, against expected: UIImage? = nil) throws {
        let metadata = try metadata(from: data)
        let image: UIImage
        if metadata.containerFormat == .appleATX {
            // Same software ASTC reader on device and simulator, not ImageIO.
            image = try SystemCPBitmapDecoder.decodeATX(data)
        } else {
            #if targetEnvironment(simulator)
            image = try decode(data)
            #else
            image = try SystemCPBitmapDecoder.decode(data)
            #endif
        }
        guard image.cgImage?.width == metadata.width,
              image.cgImage?.height == metadata.height else {
            throw CarPlayWError.invalidBitmap("像素解码后的尺寸不匹配")
        }
        let actualPixels = try comparisonPixels(image)
        if let expected {
            let expectedPixels = try comparisonPixels(expected)
            var total = 0
            for offset in stride(from: 0, to: actualPixels.count, by: 4) {
                for channel in 0..<3 {
                    total += abs(Int(actualPixels[offset + channel]) - Int(expectedPixels[offset + channel]))
                }
            }
            let meanError = Double(total) / Double(64 * 64 * 3 * 255)
            guard meanError <= 0.08 else {
                throw CarPlayWError.invalidBitmap(
                    "解码图片与选中图片不符（误差 " + String(format: "%.3f", meanError) + "），已停止写入"
                )
            }
        }
    }

    static func expectedImage(image: UIImage, template: Data, layout: ImageLayoutMode) throws -> UIImage {
        renderImage(image: image, metadata: try metadata(from: template), layout: layout, letterboxColor: .black)
    }

    private static func comparisonPixels(_ image: UIImage) throws -> [UInt8] {
        guard let cgImage = image.cgImage else {
            throw CarPlayWError.invalidBitmap("解码图像没有像素")
        }
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        let success = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 64, height: 64,
                bitsPerComponent: 8, bytesPerRow: 64 * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            return true
        }
        guard success else { throw CarPlayWError.invalidBitmap("无法校验解码像素") }
        return pixels
    }

    private static func renderPixels(
        image: UIImage,
        metadata: CPBitmapMetadata,
        layout: ImageLayoutMode,
        letterboxColor: UIColor
    ) throws -> Data {
        let rendered = renderImage(
            image: image,
            metadata: metadata,
            layout: layout,
            letterboxColor: letterboxColor
        )

        guard let cgImage = rendered.cgImage else {
            throw CarPlayWError.invalidBitmap("无法读取选中图片的像素")
        }

        var pixels = Data(count: metadata.pixelByteCount)
        let drewImage = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: metadata.width,
                    height: metadata.height,
                    bitsPerComponent: 8,
                    bytesPerRow: metadata.bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
                  ) else {
                return false
            }

            context.translateBy(x: 0, y: CGFloat(metadata.height))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(
                cgImage,
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(metadata.width),
                    height: CGFloat(metadata.height)
                )
            )
            return true
        }

        guard drewImage else {
            throw CarPlayWError.invalidBitmap("无法创建 BGRA 像素缓冲区")
        }
        return pixels
    }

    private static func renderImage(
        image: UIImage,
        metadata: CPBitmapMetadata,
        layout: ImageLayoutMode,
        letterboxColor: UIColor
    ) -> UIImage {
        let outputSize = CGSize(width: CGFloat(metadata.width), height: CGFloat(metadata.height))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            letterboxColor.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: drawRect(for: image.size, inside: outputSize, layout: layout))
        }
    }

    private static func drawRect(
        for source: CGSize,
        inside destination: CGSize,
        layout: ImageLayoutMode
    ) -> CGRect {
        guard source.width > 0, source.height > 0 else {
            return CGRect(origin: .zero, size: destination)
        }
        let widthScale = destination.width / source.width
        let heightScale = destination.height / source.height
        let scale = layout == .fill ? max(widthScale, heightScale) : min(widthScale, heightScale)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: (destination.width - size.width) / 2,
            y: (destination.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func littleEndianInt32(in data: Data, at offset: Int) throws -> Int32 {
        Int32(bitPattern: try littleEndianUInt32(in: data, at: offset))
    }

    private static func littleEndianUInt32(in data: Data, at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else {
            throw CarPlayWError.invalidBitmap("尾部字段越界")
        }
        let value = data.withUnsafeBytes { rawBuffer -> UInt32 in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return UInt32(bytes[offset]) |
                (UInt32(bytes[offset + 1]) << 8) |
                (UInt32(bytes[offset + 2]) << 16) |
                (UInt32(bytes[offset + 3]) << 24)
        }
        return value
    }

}
