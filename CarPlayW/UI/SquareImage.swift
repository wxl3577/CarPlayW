import SwiftUI

/// A 1:1 display viewport (the ratio of 2048 × 2048), not a cache resize operation.
/// Keep real pixels intact, including any border already encoded in the source.
struct SquareImage: View {
    let image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
