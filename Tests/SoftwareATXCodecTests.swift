import XCTest
import UIKit
@testable import CarPlayW

enum ASTCTestFixture {
    static func container(width: Int, height: Int, color: (Int, Int) -> [UInt8]) throws -> Data {
        var result = Data([0x41, 0x41, 0x50, 0x4c, 13, 10, 26, 10])
        func words(_ values: [UInt32]) -> Data {
            Data(values.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } })
        }
        func chunk(_ tag: String, _ payload: Data) {
            result.append(words([UInt32(payload.count)]))
            result.append(Data(tag.utf8))
            result.append(payload)
        }
        let identifier = Array(repeating: UInt32(0xa5a5a5a5), count: 4)
        chunk("HEAD", words([1, 0, 0, 0, 0x93B0, 0x1908, UInt32(width), UInt32(height), 1, 0, 1, 1, 1, 0, 1] + identifier + [1, 5]))
        chunk("FILL", Data(repeating: 0, count: 16264))
        var blocks = Data()
        // Independent construction: start with block coordinates, sort each
        // macro-tile by a bit-interleaved address rather than use app reorder().
        for my in stride(from: 0, to: height, by: 128) {
            for mx in stride(from: 0, to: width, by: 128) {
                var ordered: [(Int, Data)] = []
                for by in 0..<32 { for bx in 0..<32 {
                    var address = 0
                    for bit in 0..<5 {
                        address |= ((bx >> bit) & 1) << (2 * bit)
                        address |= ((by >> bit) & 1) << (2 * bit + 1)
                    }
                    let rgba = color(mx + bx * 4, my + by * 4)
                    let block = Data([0xfc, 0xfd, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff] + rgba.flatMap { [$0, $0] })
                    ordered.append((address, block))
                }}
                for (_, block) in ordered.sorted(by: { $0.0 < $1.0 }) { blocks.append(block) }
            }
        }
        chunk("astc", words([UInt32(blocks.count + 16)]) + blocks + words(identifier))
        chunk("END ", Data())
        result.append(words([0, 0, UInt32(width), UInt32(height), 6, 1, 0xDCB543A2]))
        return result
    }
}

final class SoftwareATXCodecTests: XCTestCase {
    func testSoftwareEncodingAcrossMultipleMacroTiles() throws {
        let template = try ASTCTestFixture.container(width: 256, height: 384) { _, _ in [0, 0, 0, 255] }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 384), format: format).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 256, height: 384))
            UIColor.red.setFill(); ctx.fill(CGRect(x: 17, y: 33, width: 61, height: 207))
            UIColor.green.setFill(); ctx.fill(CGRect(x: 110, y: 217, width: 129, height: 83))
        }
        let result = try CPBitmapCodec.encode(image: image, using: template, layout: .fill)
        let parsed = try ATXContainer(template)
        XCTAssertEqual(result.prefix(parsed.pixels.lowerBound), template.prefix(parsed.pixels.lowerBound))
        XCTAssertEqual(result.suffix(from: parsed.pixels.upperBound), template.suffix(from: parsed.pixels.upperBound))
        try CPBitmapCodec.validate(result, against: image)
    }

    func testKnownPixelsAcrossMultipleAsymmetricMacroTiles() throws {
        let data = try ASTCTestFixture.container(width: 256, height: 384) { x, y in
            [UInt8(x / 4), UInt8(y / 4), UInt8((x + y) / 4), 255]
        }
        let image = try XCTUnwrap(SoftwareATXCodec.decode(data).cgImage)
        let rgba = try XCTUnwrap(image.dataProvider?.data) as Data
        for y in stride(from: 0, to: 384, by: 4) {
            for x in stride(from: 0, to: 256, by: 4) {
                let offset = (y * 256 + x) * 4
                XCTAssertEqual(Array(rgba[offset..<offset+4]), [UInt8(x / 4), UInt8(y / 4), UInt8((x + y) / 4), 255])
            }
        }
    }

    func testReorderRoundTripAcrossMacroTileRows() throws {
        let bytes = Data((0..<(256 * 384)).map { UInt8(truncatingIfNeeded: $0 * 17 + $0 / 16) })
        let tiled = try SoftwareATXCodec.reorder(bytes, width: 256, height: 384, toLinear: false)
        XCTAssertNotEqual(tiled, bytes)
        XCTAssertEqual(try SoftwareATXCodec.reorder(tiled, width: 256, height: 384, toLinear: true), bytes)
    }

    func testInvalidASTCBlockStopsBeforeImageCreation() throws {
        var data = try ASTCTestFixture.container(width: 128, height: 128) { _, _ in [20, 30, 40, 255] }
        let range = try ATXContainer(data).pixels
        data.replaceSubrange(range.lowerBound..<range.lowerBound+16, with: repeatElement(UInt8(0), count: 16))
        XCTAssertThrowsError(try SoftwareATXCodec.decode(data))
    }

    func testUnknownLayoutIsNotGuessed() throws {
        var data = try ASTCTestFixture.container(width: 128, height: 128) { _, _ in [20, 30, 40, 255] }
        let head = try ATXContainer(data).head
        data[head.lowerBound + 76] = 3
        XCTAssertThrowsError(try SoftwareATXCodec.decode(data))
    }

    func testReorderRejectsWrongSizeAndNonMacroGeometry() throws {
        XCTAssertThrowsError(try SoftwareATXCodec.reorder(Data(count: 16), width: 128, height: 128, toLinear: true))
        XCTAssertThrowsError(try SoftwareATXCodec.reorder(Data(count: 4 * 4), width: 4, height: 4, toLinear: true))
    }
}
