import Foundation
import AppKit
import CoreImage

/// 图像修复引擎 - 用于抹除图片上的文字
/// 注意：完整的AI inpainting需要Core ML模型，这里提供基础实现和模型集成接口
class InpaintingEngine {
    private let ciContext = CIContext()
    
    private func rectForDrawing(from block: TextBlock, imageSize: CGSize) -> CGRect {
        CGRect(
            x: block.boundingBox.minX * imageSize.width,
            y: (1 - block.boundingBox.maxY) * imageSize.height,
            width: block.boundingBox.width * imageSize.width,
            height: block.boundingBox.height * imageSize.height
        )
    }

    /// 根据文字区域创建mask图像
    /// - Parameters:
    ///   - textBlocks: OCR识别的文字块
    ///   - imageSize: 原图尺寸
    ///   - expansion: mask扩展像素（避免边缘残留）
    /// - Returns: mask图像（白色区域为需要修复的部分）
    func createMask(from textBlocks: [TextBlock], imageSize: CGSize, expansion: CGFloat = 8) -> NSImage {
        let image = NSImage(size: imageSize)

        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // 黑色背景
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: imageSize))

        // 白色填充文字区域
        context.setFillColor(NSColor.white.cgColor)

        for block in textBlocks {
            var rect = rectForDrawing(from: block, imageSize: imageSize)
            // 扩展区域
            rect = rect.insetBy(dx: -expansion, dy: -expansion)
            // 确保不超出图像边界
            rect = rect.intersection(CGRect(origin: .zero, size: imageSize))

            // 使用圆角矩形使边缘更自然
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.fill()
        }

        image.unlockFocus()

        return image
    }

    /// 使用简单的颜色填充进行修复（备用方案）
    /// 当没有AI模型时使用此方法
    func inpaintSimple(image: NSImage, textBlocks: [TextBlock]) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let result = NSImage(size: size)

        result.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            result.unlockFocus()
            return image
        }

        // 绘制原图
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        // 对每个文字区域进行简单填充
        for block in textBlocks {
            var rect = rectForDrawing(from: block, imageSize: size)
            rect = rect.insetBy(dx: -4, dy: -4)
            rect = rect.intersection(CGRect(origin: .zero, size: size))

            // 采样周围颜色
            let sampleColor = sampleSurroundingColor(cgImage: cgImage, rect: rect)
            context.setFillColor(sampleColor)
            context.fill(rect)
        }

        result.unlockFocus()

        return result
    }

    /// 不做inpainting，直接返回原图
    /// 改用PPTX中带背景色的文字框覆盖原文字
    func inpaintWithModel(image: NSImage, mask: NSImage) async throws -> NSImage {
        // 直接返回原图，不做任何处理
        // 文字覆盖将在PPTX层面通过带背景色的文字框实现
        return image
    }

    /// 采样矩形周围的平均颜色
    private func sampleSurroundingColor(cgImage: CGImage, rect: CGRect) -> CGColor {
        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return NSColor.white.cgColor
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        // 采样矩形边缘的像素
        let samplePoints = [
            CGPoint(x: rect.minX - 5, y: rect.midY),
            CGPoint(x: rect.maxX + 5, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.minY - 5),
            CGPoint(x: rect.midX, y: rect.maxY + 5)
        ]

        for point in samplePoints {
            let x = Int(point.x)
            let y = Int(point.y)

            if x >= 0 && x < width && y >= 0 && y < height {
                // CGImage 数据通常是 Top-Down 的，而 rect 是 Bottom-Left origin 的
                // 所以需要翻转 Y 轴以获取正确的数据行
                let actualY = height - 1 - y
                let offset = actualY * bytesPerRow + x * bytesPerPixel
                totalR += CGFloat(ptr[offset]) / 255.0
                totalG += CGFloat(ptr[offset + 1]) / 255.0
                totalB += CGFloat(ptr[offset + 2]) / 255.0
                count += 1
            }
        }

        if count > 0 {
            return CGColor(red: totalR / count, green: totalG / count, blue: totalB / count, alpha: 1.0)
        }

        return NSColor.white.cgColor
    }
}

enum InpaintingError: Error, LocalizedError {
    case modelNotLoaded
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Inpainting模型未加载"
        case .processingFailed(let message):
            return "图像处理失败: \(message)"
        }
    }
}
