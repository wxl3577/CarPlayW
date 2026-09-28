import Foundation

// Parses the observed single-image ASTC 4x4 layout. Unknown layouts fail closed.
struct ATXContainer {
    struct Chunk {
        let tag: String
        let payload: Range<Int>
    }

    let data: Data
    let chunks: [Chunk]
    let head: Range<Int>
    let pixels: Range<Int>
    let identifier: Data
    let trailer: Range<Int>
    let width: Int
    let height: Int

    var imageIOData: Data { Data(data.prefix(trailer.lowerBound)) }

    init(_ data: Data) throws {
        func invalid(_ message: String) -> CarPlayWError {
            .invalidBitmap("ATX：\(message)")
        }
        guard data.starts(with: [0x41, 0x41, 0x50, 0x4C, 13, 10, 26, 10]) else {
            throw invalid("签名错误")
        }
        var chunks: [Chunk] = []
        var offset = 8
        var end: Int?
        while offset + 8 <= data.count {
            let size = Int(try Self.uint32(data, offset))
            let start = offset + 8
            guard size <= data.count - start,
                  let tag = String(data: data[(offset + 4)..<start], encoding: .ascii) else {
                throw invalid("数据块越界")
            }
            chunks.append(Chunk(tag: tag, payload: start..<(start + size)))
            offset = start + size
            if tag == "END " {
                guard size == 0 else { throw invalid("END 长度错误") }
                end = offset
                break
            }
        }
        guard let end,
              chunks.filter({ $0.tag == "HEAD" }).count == 1,
              let head = chunks.first, head.tag == "HEAD", head.payload.count == 84 else {
            throw invalid("缺少完整 HEAD/END")
        }
        let textures = chunks.filter { $0.tag.lowercased() == "astc" }
        guard textures.count == 1,
              chunks.allSatisfy({ ["HEAD", "FILL", "astc", "ASTC", "END "].contains($0.tag) }) else {
            throw invalid("暂不支持这种纹理布局")
        }
        let h = head.payload.lowerBound
        let width = Int(try Self.uint32(data, h + 24))
        let height = Int(try Self.uint32(data, h + 28))
        guard width > 0, height > 0, width <= 8192, height <= 8192,
              try Self.uint32(data, h + 16) == 0x93B0,
              try Self.uint32(data, h + 32) == 1,
              try Self.uint32(data, h + 40) == 1,
              try Self.uint32(data, h + 44) == 1 else {
            throw invalid("仅支持单层、单 mip 的 ASTC 4×4 纹理")
        }
        let texture = textures[0].payload
        guard texture.count >= 4,
              Int(try Self.uint32(data, texture.lowerBound)) == texture.count - 4 else {
            throw invalid("纹理内外长度不一致")
        }
        let planeSize = ((width + 3) / 4) * ((height + 3) / 4) * 16
        let extraSize = texture.count - 4 - planeSize
        guard extraSize == 0 || extraSize == 16 else {
            throw invalid("纹理像素区长度不符合 ASTC 4×4")
        }
        let identifier = data.subdata(in: (h + 60)..<(h + 76))
        if extraSize == 16 {
            guard data.subdata(in: (texture.upperBound - 16)..<texture.upperBound) == identifier else {
                throw invalid("HEAD 标识与纹理末尾标识不一致；请让 CarPlay 重新生成系统壁纸缓存")
            }
        }
        let footer = end..<data.count
        if !footer.isEmpty {
            guard footer.count == 28,
                  try Self.uint32(data, end + 8) == UInt32(width),
                  try Self.uint32(data, end + 12) == UInt32(height),
                  try Self.uint32(data, end + 24) == 0xDCB543A2 else {
                throw invalid("cpbitmap 尾部尺寸或签名错误")
            }
        }
        self.data = data
        self.chunks = chunks
        self.head = head.payload
        self.pixels = (texture.lowerBound + 4)..<(texture.lowerBound + 4 + planeSize)
        self.identifier = identifier
        self.trailer = footer
        self.width = width
        self.height = height
    }

    // Keep ALL template framing, including the identifier in both locations.
    // Encoded headers must agree on geometry, layout and pixel-format fields.
    func replacingPixels(with encoded: ATXContainer) throws -> Data {
        var expected = data.subdata(in: head)
        var actual = encoded.data.subdata(in: encoded.head)
        expected.replaceSubrange(60..<76, with: repeatElement(UInt8(0), count: 16))
        actual.replaceSubrange(60..<76, with: repeatElement(UInt8(0), count: 16))
        guard expected == actual, pixels.count == encoded.pixels.count,
              chunks.first(where: { $0.tag.lowercased() == "astc" })?.tag ==
                encoded.chunks.first(where: { $0.tag.lowercased() == "astc" })?.tag else {
            let differences = expected.indices.filter { expected[$0] != actual[$0] }.map {
                "HEAD[\($0)]:\(expected[$0])→\(actual[$0])"
            }.joined(separator: ", ")
            throw CarPlayWError.invalidBitmap("编码器的纹理布局与原版模板不同，已停止写入。\(differences)")
        }
        var result = data
        result.replaceSubrange(pixels, with: encoded.data[encoded.pixels])
        _ = try ATXContainer(result)
        return result
    }

    static func uint32(_ data: Data, _ offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else {
            throw CarPlayWError.invalidBitmap("字段越界")
        }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << ($1 * 8) }
    }
}
