import Foundation
import AppKit

struct ProcessedPage: Identifiable {
    let id: UUID
    let index: Int
    let originalImage: NSImage
    let inpaintedImage: NSImage
    let textBlocks: [TextBlock]
    let bounds: CGRect
    
    init(
        id: UUID = UUID(),
        index: Int,
        originalImage: NSImage,
        inpaintedImage: NSImage,
        textBlocks: [TextBlock],
        bounds: CGRect
    ) {
        self.id = id
        self.index = index
        self.originalImage = originalImage
        self.inpaintedImage = inpaintedImage
        self.textBlocks = textBlocks
        self.bounds = bounds
    }

    var width: CGFloat { bounds.width }
    var height: CGFloat { bounds.height }
}
