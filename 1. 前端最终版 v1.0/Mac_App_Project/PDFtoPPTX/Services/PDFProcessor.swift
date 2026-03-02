import Foundation
import PDFKit
import AppKit

class PDFProcessor {
    /// 从PDF文件中提取每页为高分辨率图片
    /// - Parameters:
    ///   - pdfURL: PDF文件路径
    ///   - dpi: 输出图片DPI，默认300
    /// - Returns: 每页的内容数组
    func extractImages(from pdfURL: URL, dpi: CGFloat = 300) -> [PageContent] {
        guard let document = PDFDocument(url: pdfURL) else {
            print("无法打开PDF文件: \(pdfURL)")
            return []
        }

        var pages: [PageContent] = []
        let scale = dpi / 72.0  // PDF默认72 DPI

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }

            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(
                width: bounds.width * scale,
                height: bounds.height * scale
            )

            // 渲染PDF页面为图片
            if let image = renderPage(page, size: size) {
                pages.append(PageContent(
                    index: i,
                    image: image,
                    bounds: bounds
                ))
            }
        }

        return pages
    }

    /// 渲染单个PDF页面为NSImage
    private func renderPage(_ page: PDFPage, size: CGSize) -> NSImage? {
        let image = NSImage(size: size)

        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // 白色背景
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // 缩放到目标尺寸
        let bounds = page.bounds(for: .mediaBox)
        let scaleX = size.width / bounds.width
        let scaleY = size.height / bounds.height
        context.scaleBy(x: scaleX, y: scaleY)

        // 绘制PDF页面
        page.draw(with: .mediaBox, to: context)

        image.unlockFocus()

        return image
    }

    /// 获取PDF页数
    func pageCount(for pdfURL: URL) -> Int {
        guard let document = PDFDocument(url: pdfURL) else { return 0 }
        return document.pageCount
    }
}
