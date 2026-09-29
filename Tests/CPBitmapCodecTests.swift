import XCTest
import UIKit
import ImageIO
@testable import CarPlayW

final class CPBitmapCodecTests: XCTestCase {
    func testLegacyNonUniformImageKeepsTopAndBottomRows() throws {
        var original = Data(count: 128 * 128 * 4)
        append([0, 128, 128, 1, 1, 0], to: &original)
        let image = pattern()
        let result = try CPBitmapCodec.encode(image: image, using: original, layout: .fit)
        XCTAssertEqual(Array(result[0..<4]), [0, 255, 0, 255], "Top-left stays green in BGRA")
        let bottomRight = (128 * 128 - 1) * 4
        XCTAssertEqual(Array(result[bottomRight..<bottomRight + 4]), [0, 255, 255, 255], "Bottom-right stays yellow in BGRA")
        try CPBitmapCodec.validate(result, against: image)
    }

    func testBuiltInWallpaperSurvivesATXEncodeAndReadBack() throws {
        let original = try template()
        let source = try XCTUnwrap(BuiltInWallpaper.load())
        let expected = try CPBitmapCodec.expectedImage(image: source, template: original, layout: .fit)
        let encoded = try CPBitmapCodec.encode(image: source, using: original, layout: .fit)
        try CPBitmapCodec.validate(encoded, against: expected)
        XCTAssertEqual(try CPBitmapCodec.decode(encoded).cgImage?.width, 128)
    }

    func testParsesIOS15FooterAndAlignedStride() throws {
        var data = Data(count: 112 * 4 * 55 + 40)
        append([17, 101, 55, 1, 1, 0], to: &data)
        let metadata = try CPBitmapCodec.metadata(from: data)
        XCTAssertEqual(metadata.width, 101)
        XCTAssertEqual(metadata.height, 55)
        XCTAssertEqual(metadata.bytesPerRow, 448)
    }

    func testATXReaderUsesSoftwarePathForPreviewAndValidation() throws {
        let original = try template()
        let systemImage = try SystemCPBitmapDecoder.decode(original)
        let preview = try CPBitmapCodec.decode(original)
        XCTAssertEqual(systemImage.cgImage?.width, 128)
        XCTAssertEqual(preview.cgImage?.height, 128)
        try CPBitmapCodec.validate(original, against: pattern())
    }

    func testImageIOInputRemovesOnlyValidatedFooterWithoutChangingSource() throws {
        let original = try template()
        let container = try ATXContainer(original)
        let input = container.imageIOData
        XCTAssertEqual(input.count, original.count - 28)
        XCTAssertEqual(input, Data(original.dropLast(28)))
        XCTAssertEqual(container.data, original)
        let standalone = try ATXContainer(input)
        XCTAssertTrue(standalone.trailer.isEmpty)
        XCTAssertEqual(standalone.imageIOData, input)
        XCTAssertEqual(standalone.identifier, container.identifier)
        XCTAssertEqual(input[standalone.pixels], original[container.pixels])
        let image = try SystemCPBitmapDecoder.decodeATX(input)
        XCTAssertEqual(image.cgImage?.width, 128)
    }

    func testATXReaderDoesNotIgnoreMalformedPrivateFooter() throws {
        var data = try template()
        data[data.count - 1] ^= 1
        XCTAssertThrowsError(try SystemCPBitmapDecoder.decode(data))
    }

    func testReplacesOnlyTexturePlaneAndPreservesBothIdentifiers() throws {
        let original = try template()
        let parsed = try ATXContainer(original)
        let image = pattern(swapped: true)
        let encoded = try CPBitmapCodec.encode(image: image, using: original, layout: .fill)
        XCTAssertEqual(encoded.count, original.count)
        XCTAssertEqual(encoded.prefix(parsed.pixels.lowerBound), original.prefix(parsed.pixels.lowerBound))
        XCTAssertEqual(encoded.suffix(from: parsed.pixels.upperBound), original.suffix(from: parsed.pixels.upperBound))
        XCTAssertNotEqual(encoded[parsed.pixels], original[parsed.pixels])
        XCTAssertEqual(try ATXContainer(encoded).identifier, parsed.identifier)
        try CPBitmapCodec.validate(encoded, against: image)
    }

    func testRejectsOldFixWithZeroHeadAndNonzeroTailIdentifier() throws {
        var broken = try template()
        let parsed = try ATXContainer(broken)
        broken.replaceSubrange((parsed.head.lowerBound + 60)..<(parsed.head.lowerBound + 76),
                               with: repeatElement(UInt8(0), count: 16))
        broken.replaceSubrange(parsed.pixels.upperBound..<(parsed.pixels.upperBound + 16),
                               with: repeatElement(UInt8(0xA5), count: 16))
        XCTAssertThrowsError(try ATXContainer(broken))
    }

    func testRejectsLayoutMismatchInsteadOfSplicingDifferentEncoding() throws {
        let original = try ATXContainer(template())
        var wrong = original.data
        wrong[original.head.lowerBound + 80] ^= 1
        let incompatible = try ATXContainer(wrong)
        XCTAssertThrowsError(try original.replacingPixels(with: incompatible))
    }

    func testRejectsTruncatedContainerAndWrongFooter() throws {
        let original = try template()
        XCTAssertThrowsError(try ATXContainer(Data(original.dropLast(32))))
        var broken = original
        broken[broken.count - 1] ^= 1
        XCTAssertThrowsError(try ATXContainer(broken))
    }

    func testRejectsDifferentImageDespiteValidContainerAndDimensions() throws {
        let original = try template()
        XCTAssertThrowsError(try CPBitmapCodec.validate(original, against: pattern(swapped: true)))
    }

    func testRejectsTruncatedPixelPlane() {
        var data = Data(count: 32)
        append([17, 1920, 1080, 1, 1, 0], to: &data)
        XCTAssertThrowsError(try CPBitmapCodec.metadata(from: data))
    }

    func testEncodePreservesLegacyTrailer() throws {
        var original = Data(repeating: 0, count: 32 * 16 * 4 + 12)
        append([17, 32, 16, 1, 1, 0x12345678], to: &original)
        let result = try CPBitmapCodec.encode(image: pattern(), using: original, layout: .fill)
        XCTAssertEqual(result.count, original.count)
        XCTAssertEqual(result.suffix(36), original.suffix(36))
    }

    private func pattern(swapped: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { ctx in
            (swapped ? UIColor.blue : UIColor.red).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 64, y: 64, width: 64, height: 64))
        }
    }

    // Hand-authored ASTC LDR void-extent blocks (not generated by our encoder).
    // Exact known pixels give an independent decode oracle. Framing matches
    // the observed iOS 15.6 layout; no user image bytes are included.
    private func template() throws -> Data {
        try ASTCTestFixture.container(width: 128, height: 128) { x, y in
            if x < 64 && y < 64 { return [0, 255, 0, 255] }
            if x >= 64 && y >= 64 { return [255, 255, 0, 255] }
            return [255, 0, 0, 255]
        }
    }

    private func append(_ values: [UInt32], to data: inout Data) {
        for value in values {
            data.append(contentsOf: (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
        }
    }

    private func replace(_ value: UInt32, in data: inout Data, at offset: Int) {
        data.replaceSubrange(offset..<(offset + 4), with:
            (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
    }
}
