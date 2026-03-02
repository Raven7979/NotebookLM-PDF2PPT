import Foundation
import AppKit

struct PageContent: Identifiable {
    let id = UUID()
    let index: Int
    let image: NSImage
    let bounds: CGRect

    var width: CGFloat { bounds.width }
    var height: CGFloat { bounds.height }
}
