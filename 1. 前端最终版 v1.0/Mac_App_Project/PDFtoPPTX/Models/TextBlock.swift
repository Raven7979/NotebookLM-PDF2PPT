import Foundation
import AppKit

struct TextBlock: Identifiable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // 归一化坐标 (0-1)
    let fontSizeRatio: CGFloat  // 字体大小占图片高度的比例 (0-1)
    let textColor: NSColor  // 文字颜色
    let backgroundColor: NSColor  // 背景色（用于覆盖原文字）
    let isBold: Bool  // 是否加粗（标题）
    let rotation: CGFloat // 旋转角度 (度)
    let strokeColor: NSColor? // 描边颜色
    let strokeWidth: CGFloat? // 描边宽度 (Points)
    
    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect,
        fontSizeRatio: CGFloat,
        textColor: NSColor,
        backgroundColor: NSColor,
        isBold: Bool,
        rotation: CGFloat,
        strokeColor: NSColor?,
        strokeWidth: CGFloat?
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.fontSizeRatio = fontSizeRatio
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.isBold = isBold
        self.rotation = rotation
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }

    // 转换为实际像素坐标
    func pixelRect(imageSize: CGSize) -> CGRect {
        // boundingBox 已经是 Top-Left 原点的归一化坐标
        // 直接映射到 imageSize，不需要再次翻转 Y 轴
        CGRect(
            x: boundingBox.minX * imageSize.width,
            y: boundingBox.minY * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
    }

    // 转换为EMU单位 (用于PPTX)
    func emuRect(slideSize: CGSize, scaleFactor: CGFloat = 914400) -> (x: Int, y: Int, cx: Int, cy: Int) {
        let pixelRect = self.pixelRect(imageSize: slideSize)
        return (
            x: Int(pixelRect.minX * scaleFactor / 72),
            y: Int(pixelRect.minY * scaleFactor / 72),
            cx: Int(pixelRect.width * scaleFactor / 72),
            cy: Int(pixelRect.height * scaleFactor / 72)
        )
    }

    // 获取颜色的十六进制值 (用于PPTX)
    func colorHex(for color: NSColor? = nil) -> String {
        // 确保转换到 RGB 颜色空间
        let targetColor = color ?? self.textColor
        let safeColor = targetColor.usingColorSpace(.sRGB) ?? .black
        
        let r = Int(safeColor.redComponent * 255)
        let g = Int(safeColor.greenComponent * 255)
        let b = Int(safeColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }

    // 获取背景色的十六进制值
    func bgColorHex() -> String {
        // 确保转换到 RGB 颜色空间
        let safeColor = backgroundColor.usingColorSpace(.sRGB) ?? .white
        
        let r = Int(safeColor.redComponent * 255)
        let g = Int(safeColor.greenComponent * 255)
        let b = Int(safeColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
