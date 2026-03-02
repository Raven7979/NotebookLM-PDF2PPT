import Foundation
import Vision
import AppKit

class OCREngine {
    private struct OBBEstimate {
        let centerX: CGFloat
        let centerY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotationDegreesCW: CGFloat
    }

    /// 识别图片中的文字
    /// - Parameter image: 输入图片
    /// - Returns: 识别到的文字块数组
    func recognizeText(in image: NSImage) async throws -> [TextBlock] {
        // 1. 规范化图片数据：绘制到标准的 RGBA Context 中
        // 这解决了颜色通道错乱（BGRA vs RGBA）的问题，确保后续采样逻辑的正确性
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // 使用 PremultipliedLast (RGBA)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
             throw OCRError.invalidImage
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 获取标准化的 CGImage，用于传入 Vision 和后续采样
        guard let normalizedImage = context.makeImage() else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let textBlocks = observations.compactMap { observation -> TextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    
                    // 过滤置信度过低的文字
                    if candidate.confidence < 0.3 { return nil }

                    let visionBox = observation.boundingBox
                    
                    // 过滤过小的文字块 (比如噪点)
                    if visionBox.width < 0.01 || visionBox.height < 0.005 { return nil }
                    
                    // 提前计算 OBB (Oriented Bounding Box) 参数
                    // Vision坐标系：原点左下角 (0,0)，TopRight (1,1)
                    let topLeft = observation.topLeft
                    let topRight = observation.topRight
                    let bottomLeft = observation.bottomLeft
                    let bottomRight = observation.bottomRight
                    
                    // 计算高度 (Left边和Right边的平均值) - 这是真实的行高 (OBB Height)
                    let leftHeight = hypot(topLeft.x - bottomLeft.x, topLeft.y - bottomLeft.y)
                    let rightHeight = hypot(topRight.x - bottomRight.x, topRight.y - bottomRight.y)
                    let avgHeight = (leftHeight + rightHeight) / 2
                    
                    // 计算宽度 (Top边和Bottom边的平均值) - 这是真实的行宽 (OBB Width)
                    let topWidth = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
                    let bottomWidth = hypot(bottomRight.x - bottomLeft.x, bottomRight.y - bottomLeft.y)
                    let avgWidth = (topWidth + bottomWidth) / 2
            
                    let text = candidate.string
                    var weightedCount: CGFloat = 0
                    for char in text {
                        // 简单估算：ASCII字符算0.55宽，其他（主要是CJK）算1.0宽
                        if char.isASCII {
                            weightedCount += 0.55
                        } else {
                            weightedCount += 1.0
                        }
                    }
                    weightedCount = max(1.0, weightedCount)
                    
                    let _ = CGFloat(cgImage.width) / CGFloat(cgImage.height)
                    let rotationRadians = atan2(Double(topRight.y - topLeft.y), Double(topRight.x - topLeft.x))
                    let visionDegreesCCW = CGFloat(rotationRadians * 180 / .pi)
                    let obsRotationDegreesCW = self?.normalizeDegrees(-visionDegreesCCW) ?? -visionDegreesCCW
                    
                    let obsCenterX = (topLeft.x + bottomRight.x) / 2
                    let obsCenterY = (topLeft.y + bottomRight.y) / 2
                    let obbFromObservation = OBBEstimate(
                        centerX: obsCenterX,
                        centerY: obsCenterY,
                        width: avgWidth,
                        height: avgHeight,
                        rotationDegreesCW: obsRotationDegreesCW
                    )
                    
                    let pixelOBB = self?.estimateOBBFromPixels(in: normalizedImage, boundingBox: visionBox)
                    let chosenOBB: OBBEstimate
                    if let pixelOBB {
                        let obsMag = abs(obbFromObservation.rotationDegreesCW)
                        let pixMag = abs(pixelOBB.rotationDegreesCW)
                        if pixMag >= max(1.0, obsMag + 0.8) {
                            chosenOBB = pixelOBB
                        } else {
                            chosenOBB = obbFromObservation
                        }
                    } else {
                        chosenOBB = obbFromObservation
                    }
                    
                    // Vision 边界框高度包含行间距和上下padding
                    // 实际字符高度约为边界框的 70%（经验值）
                    let fontSizeRatio = chosenOBB.height * 0.70
                    
                    let rotationThreshold = self?.rotationThresholdDegrees(height: chosenOBB.height) ?? 0.5
                    let pptxRotation: CGFloat = abs(chosenOBB.rotationDegreesCW) >= rotationThreshold ? chosenOBB.rotationDegreesCW : 0

            
            // 3. 构造修正后的 Bounding Box (Normalized Top-Left 坐标系)
            // TextBlock.boundingBox 期望的是 Normalized Top-Left 格式 (x, y, w, h)
            // 其中 x, y 是矩形左上角。
            // 这里的 (centerX, centerY) 是 Normalized Bottom-Left。
            // 先计算 Bottom-Left 下的 rect:
            let blX = chosenOBB.centerX - chosenOBB.width / 2
            let blY = chosenOBB.centerY - chosenOBB.height / 2
            
            // 转换为 Top-Left:
            // x 不变
            // y = 1 - (blY + h) = 1 - blY - h
            let widthNorm = max(0, min(1, chosenOBB.width))
            let heightNorm = max(0, min(1, chosenOBB.height))
            
            let finalX = min(max(blX, 0), max(0, 1 - widthNorm))
            let finalY = min(max(1 - blY - heightNorm, 0), max(0, 1 - heightNorm))
            
            let correctedBoundingBox = CGRect(x: finalX, y: finalY, width: widthNorm, height: heightNorm)

            // 采样文字颜色和背景色
            // 注意：采样仍使用原始的 Vision Box (AABB)，因为我们没有简单的旋转采样方法
            // 使用 normalizedImage 进行采样，确保颜色通道正确
            let (textColor, bgColor, strokeColor, strokeWidth) = self?.sampleColors(from: normalizedImage, boundingBox: visionBox) ?? (.black, .white, nil, nil)
            
            // 改进的粗体检测：
            // 1. 字号较大（>4%高度）且文字较短（可能是标题）
            // 2. 或者有描边
            // 3. 或者文字颜色较深且字号中等以上
            let textLength = candidate.string.count
            let isLargeFont = fontSizeRatio > 0.04
            let isMediumOrLarge = fontSizeRatio > 0.025
            let isShortText = textLength <= 20
            let hasStroke = strokeColor != nil
            let isBold = (isLargeFont && isShortText) || hasStroke || (isMediumOrLarge && textLength <= 30)

            return TextBlock(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: correctedBoundingBox, // 使用修正后的 OBB
                fontSizeRatio: fontSizeRatio,
                textColor: textColor,
                backgroundColor: bgColor,
                isBold: isBold,
                rotation: pptxRotation,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth
            )
        }

        continuation.resume(returning: textBlocks)
            }

            // 配置OCR请求
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: normalizedImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func rotationThresholdDegrees(height: CGFloat) -> CGFloat {
        let small: CGFloat = 0.015
        let large: CGFloat = 0.06
        let t = min(1, max(0, (height - small) / (large - small)))
        return (1 - t) * 8.0 + t * 3.0
    }

    private func normalizeDegrees(_ degrees: CGFloat) -> CGFloat {
        var d = degrees
        while d > 90 { d -= 180 }
        while d < -90 { d += 180 }
        return d
    }

    private func estimateOBBFromPixels(in cgImage: CGImage, boundingBox: CGRect) -> OBBEstimate? {
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        
        let yTop = Int((1 - boundingBox.maxY) * CGFloat(imageHeight))
        let yBottom = Int((1 - boundingBox.minY) * CGFloat(imageHeight))
        let xLeft = Int(boundingBox.minX * CGFloat(imageWidth))
        let xRight = Int(boundingBox.maxX * CGFloat(imageWidth))
        
        let safeXLeft = max(0, xLeft)
        let safeXRight = min(imageWidth - 1, xRight)
        let safeYTop = max(0, yTop)
        let safeYBottom = min(imageHeight - 1, yBottom)
        
        guard safeXRight > safeXLeft, safeYBottom > safeYTop else { return nil }
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var bgR: CGFloat = 0, bgG: CGFloat = 0, bgB: CGFloat = 0
        var bgCount: CGFloat = 0
        
        let boundaryPoints = [
            (safeXLeft - 2, (safeYTop + safeYBottom) / 2),
            (safeXRight + 2, (safeYTop + safeYBottom) / 2),
            ((safeXLeft + safeXRight) / 2, safeYTop - 2),
            ((safeXLeft + safeXRight) / 2, safeYBottom + 2)
        ]
        
        for (bx, by) in boundaryPoints {
            let x = min(max(bx, 0), imageWidth - 1)
            let y = min(max(by, 0), imageHeight - 1)
            let offset = y * bytesPerRow + x * bytesPerPixel
            
            bgR += CGFloat(ptr[offset]) / 255.0
            bgG += CGFloat(ptr[offset + 1]) / 255.0
            bgB += CGFloat(ptr[offset + 2]) / 255.0
            bgCount += 1
        }
        
        let avgBgR = bgCount > 0 ? bgR / bgCount : 1.0
        let avgBgG = bgCount > 0 ? bgG / bgCount : 1.0
        let avgBgB = bgCount > 0 ? bgB / bgCount : 1.0
        
        struct PixelPoint {
            let x: CGFloat
            let y: CGFloat
            let diff: CGFloat
        }
        
        let scanLeft = safeXLeft + 1
        let scanRight = safeXRight - 1
        let scanTop = safeYTop + 1
        let scanBottom = safeYBottom - 1
        
        guard scanRight > scanLeft, scanBottom > scanTop else { return nil }
        
        let spanX = scanRight - scanLeft
        let spanY = scanBottom - scanTop
        let stepX = max(1, spanX / 60)
        let stepY = max(1, spanY / 30)
        
        var points: [PixelPoint] = []
        points.reserveCapacity(800)
        
        for y in stride(from: scanTop, to: scanBottom, by: stepY) {
            for x in stride(from: scanLeft, to: scanRight, by: stepX) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0
                
                let dr = r - avgBgR
                let dg = g - avgBgG
                let db = b - avgBgB
                let diff = sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114)
                
                points.append(PixelPoint(x: CGFloat(x), y: CGFloat(y), diff: diff))
            }
        }
        
        guard let maxDiff = points.map(\.diff).max(), maxDiff > 0 else { return nil }
        let threshold = max(0.12, maxDiff * 0.25)
        let fg = points.filter { $0.diff >= threshold }
        guard fg.count >= 40 else { return nil }
        
        var meanX: CGFloat = 0
        var meanY: CGFloat = 0
        for p in fg {
            meanX += p.x
            meanY += p.y
        }
        meanX /= CGFloat(fg.count)
        meanY /= CGFloat(fg.count)
        
        var covXX: CGFloat = 0
        var covXY: CGFloat = 0
        var covYY: CGFloat = 0
        for p in fg {
            let dx = p.x - meanX
            let dy = p.y - meanY
            covXX += dx * dx
            covXY += dx * dy
            covYY += dy * dy
        }
        covXX /= CGFloat(fg.count)
        covXY /= CGFloat(fg.count)
        covYY /= CGFloat(fg.count)
        
        let trace = covXX + covYY
        let delta = sqrt(max(0, (covXX - covYY) * (covXX - covYY) + 4 * covXY * covXY))
        let lambda1 = (trace + delta) / 2
        let lambda2 = (trace - delta) / 2
        
        guard lambda2 > 0, (lambda1 / lambda2) >= 1.2 else { return nil }
        
        let theta = 0.5 * atan2(Double(2 * covXY), Double(covXX - covYY))
        let degreesCW = normalizeDegrees(CGFloat(theta * 180 / .pi))
        
        let ux = cos(theta)
        let uy = sin(theta)
        let vx = -uy
        let vy = ux
        
        var minP = Double.greatestFiniteMagnitude
        var maxP = -Double.greatestFiniteMagnitude
        var minQ = Double.greatestFiniteMagnitude
        var maxQ = -Double.greatestFiniteMagnitude
        
        for p in fg {
            let x = Double(p.x)
            let y = Double(p.y)
            let projP = x * ux + y * uy
            let projQ = x * vx + y * vy
            minP = min(minP, projP)
            maxP = max(maxP, projP)
            minQ = min(minQ, projQ)
            maxQ = max(maxQ, projQ)
        }
        
        let widthPx = max(1, maxP - minP)
        let heightPx = max(1, maxQ - minQ)
        let centerPxX = ((minP + maxP) / 2) * ux + ((minQ + maxQ) / 2) * vx
        let centerPxY = ((minP + maxP) / 2) * uy + ((minQ + maxQ) / 2) * vy
        
        let centerXNorm = CGFloat(centerPxX / Double(imageWidth))
        let centerYNormBL = CGFloat(1 - (centerPxY / Double(imageHeight)))
        
        let widthNorm = CGFloat(widthPx / Double(imageWidth))
        let heightNorm = CGFloat(heightPx / Double(imageHeight))
        
        if widthNorm <= 0 || heightNorm <= 0 { return nil }
        
        return OBBEstimate(
            centerX: centerXNorm,
            centerY: centerYNormBL,
            width: widthNorm,
            height: heightNorm,
            rotationDegreesCW: degreesCW
        )
    }

    /// 从图像中采样文字颜色和背景色
    /// 返回：(文字颜色, 背景色, 描边颜色, 描边宽度)
    private func sampleColors(from cgImage: CGImage, boundingBox: CGRect) -> (textColor: NSColor, bgColor: NSColor, strokeColor: NSColor?, strokeWidth: CGFloat?) {
        let width = cgImage.width
        let height = cgImage.height
        
        // Vision boundingBox 是归一化的 Bottom-Left 坐标 (0,0 在左下角)
        // Image buffer 是 Top-Left 坐标 (0,0 在左上角)
        // 转换 Y 轴：pixelY = (1 - visionY) * height
        // vision.maxY (顶部) -> pixel.minY (顶部)
        // vision.minY (底部) -> pixel.maxY (底部)
        
        let yTop = Int((1 - boundingBox.maxY) * CGFloat(height))
        let yBottom = Int((1 - boundingBox.minY) * CGFloat(height))
        let xLeft = Int(boundingBox.minX * CGFloat(width))
        let xRight = Int(boundingBox.maxX * CGFloat(width))
        
        // 确保坐标在安全范围内
        let safeXLeft = max(0, xLeft)
        let safeXRight = min(width - 1, xRight)
        let safeYTop = max(0, yTop)
        let safeYBottom = min(height - 1, yBottom)
        
        guard safeXRight > safeXLeft, safeYBottom > safeYTop else {
            return (.black, .white, nil, nil)
        }
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return (.black, .white, nil, nil)
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        func readRGB(x: Int, y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
            let safeX = min(max(x, 0), width - 1)
            let safeY = min(max(y, 0), height - 1)
            let offset = safeY * bytesPerRow + safeX * bytesPerPixel
            return (
                r: CGFloat(ptr[offset]) / 255.0,
                g: CGFloat(ptr[offset + 1]) / 255.0,
                b: CGFloat(ptr[offset + 2]) / 255.0
            )
        }
        
        func median(_ values: [CGFloat]) -> CGFloat {
            guard !values.isEmpty else { return 0 }
            let sorted = values.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 1 { return sorted[mid] }
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        
        func saturation(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            return maxC == 0 ? 0 : (maxC - minC) / maxC
        }
        
        func luma(r: CGFloat, g: CGFloat, b: CGFloat) -> CGFloat {
            0.299 * r + 0.587 * g + 0.114 * b
        }
        
        let midX = (safeXLeft + safeXRight) / 2
        let midY = (safeYTop + safeYBottom) / 2
        
        var bgSamples: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        bgSamples.reserveCapacity(32)
        for ring in [6, 12] {
            let pts = [
                (safeXLeft - ring, midY),
                (safeXRight + ring, midY),
                (midX, safeYTop - ring),
                (midX, safeYBottom + ring),
                (safeXLeft - ring, safeYTop - ring),
                (safeXRight + ring, safeYTop - ring),
                (safeXLeft - ring, safeYBottom + ring),
                (safeXRight + ring, safeYBottom + ring)
            ]
            for (x, y) in pts {
                bgSamples.append(readRGB(x: x, y: y))
            }
        }
        
        let avgBgR = median(bgSamples.map(\.r))
        let avgBgG = median(bgSamples.map(\.g))
        let avgBgB = median(bgSamples.map(\.b))
        let bgColor = NSColor(red: avgBgR, green: avgBgG, blue: avgBgB, alpha: 1.0)
        let bgLuma = luma(r: avgBgR, g: avgBgG, b: avgBgB)
        
        // 2. 寻找文字颜色：在框内采样
        // 策略：全区域采样，过滤背景后，对前景像素进行聚类 (K-Means K=2)
        // 以分离 Fill Color (填充) 和 Stroke Color (描边)
        
        let sampleStepX = max(1, (safeXRight - safeXLeft) / 40)
        let sampleStepY = max(1, (safeYBottom - safeYTop) / 20)
        
        struct PixelSample {
            let x: Int
            let y: Int
            let r: CGFloat
            let g: CGFloat
            let b: CGFloat
            let luma: CGFloat
            let diff: CGFloat // 与背景的差异
        }
        
        var samples: [PixelSample] = []
        
        // 采样整个区域 (略微内缩 1px 防止插值误差)
        let scanLeft = safeXLeft + 1
        let scanRight = safeXRight - 1
        let scanTop = safeYTop + 1
        let scanBottom = safeYBottom - 1
        
        if scanRight > scanLeft && scanBottom > scanTop {
            for y in stride(from: scanTop, to: scanBottom, by: sampleStepY) {
                for x in stride(from: scanLeft, to: scanRight, by: sampleStepX) {
                    let (r, g, b) = readRGB(x: x, y: y)
                    
                    let dr = r - avgBgR
                    let dg = g - avgBgG
                    let db = b - avgBgB
                    let diff = sqrt(dr*dr*0.299 + dg*dg*0.587 + db*db*0.114)
                    
                    samples.append(PixelSample(x: x, y: y, r: r, g: g, b: b, luma: luma(r: r, g: g, b: b), diff: diff))
                }
            }
        }
        
        var finalTextR: CGFloat = 0
        var finalTextG: CGFloat = 0
        var finalTextB: CGFloat = 0
        var strokeColor: NSColor? = nil
        var strokeWidth: CGFloat? = nil
        let boxHPx = CGFloat(safeYBottom - safeYTop)
        
        if !samples.isEmpty {
            struct ColorBin {
                var sumR: CGFloat = 0
                var sumG: CGFloat = 0
                var sumB: CGFloat = 0
                var sumW: CGFloat = 0
            }
            
            let maxDiff = samples.map(\.diff).max() ?? 0
            var fgThreshold = max(0.06, maxDiff * 0.22)
            var fg = samples.filter { $0.diff >= fgThreshold }
            if fg.count < 10 {
                fgThreshold = max(0.04, maxDiff * 0.16)
                fg = samples.filter { $0.diff >= fgThreshold }
            }
            
            if fg.isEmpty, let best = samples.max(by: { $0.diff < $1.diff }) {
                finalTextR = best.r
                finalTextG = best.g
                finalTextB = best.b
            } else {
                let binsPerChannel = 20
                var bins: [Int: ColorBin] = [:]
                bins.reserveCapacity(64)
                
                for s in fg {
                    let qr = max(0, min(binsPerChannel - 1, Int((s.r * CGFloat(binsPerChannel)).rounded(.down))))
                    let qg = max(0, min(binsPerChannel - 1, Int((s.g * CGFloat(binsPerChannel)).rounded(.down))))
                    let qb = max(0, min(binsPerChannel - 1, Int((s.b * CGFloat(binsPerChannel)).rounded(.down))))
                    let key = (qr << 16) | (qg << 8) | qb
                    
                    let w = 1 + min(1.0, s.diff) * 2
                    var bin = bins[key] ?? ColorBin()
                    bin.sumR += s.r * w
                    bin.sumG += s.g * w
                    bin.sumB += s.b * w
                    bin.sumW += w
                    bins[key] = bin
                }
                
                if !bins.isEmpty {
                    let topBins = bins
                        .map { $0.value }
                        .filter { $0.sumW > 0 }
                        .sorted { $0.sumW > $1.sumW }
                    
                    let candidates = Array(topBins.prefix(min(10, topBins.count)))
                    if let best = candidates.max(by: { a, b in
                        let ar = a.sumR / a.sumW
                        let ag = a.sumG / a.sumW
                        let ab = a.sumB / a.sumW
                        let br = b.sumR / b.sumW
                        let bg = b.sumG / b.sumW
                        let bb = b.sumB / b.sumW
                        
                        let aL = luma(r: ar, g: ag, b: ab)
                        let bL = luma(r: br, g: bg, b: bb)
                        let aSat = saturation(r: ar, g: ag, b: ab)
                        let bSat = saturation(r: br, g: bg, b: bb)
                        
                        let aScore = abs(aL - bgLuma) + 0.10 * min(0.9, aSat)
                        let bScore = abs(bL - bgLuma) + 0.10 * min(0.9, bSat)
                        return aScore < bScore
                    }) {
                        finalTextR = best.sumR / best.sumW
                        finalTextG = best.sumG / best.sumW
                        finalTextB = best.sumB / best.sumW
                    }
                } else if let best = fg.max(by: { $0.diff < $1.diff }) {
                    finalTextR = best.r
                    finalTextG = best.g
                    finalTextB = best.b
                }
            }
            
            let fillLuma = luma(r: finalTextR, g: finalTextG, b: finalTextB)
            
            if fillLuma <= 0.70 {
                let neighborStep = max(1, min(4, Int((boxHPx / 60).rounded(.toNearestOrAwayFromZero))))
                
                let offsets = [
                    (-neighborStep, 0), (neighborStep, 0), (0, -neighborStep), (0, neighborStep),
                    (-neighborStep, -neighborStep), (neighborStep, neighborStep), (-neighborStep, neighborStep), (neighborStep, -neighborStep)
                ]
                
                let candidateTextPixels = fg.filter {
                    abs($0.r - finalTextR) + abs($0.g - finalTextG) + abs($0.b - finalTextB) <= 0.22
                }.sorted { $0.diff > $1.diff }
                
                let basePixels = candidateTextPixels.isEmpty ? fg.sorted { $0.diff > $1.diff } : candidateTextPixels
                let limitedBase = Array(basePixels.prefix(min(28, basePixels.count)))
                
                var strokeCandidates: [(r: CGFloat, g: CGFloat, b: CGFloat, score: CGFloat)] = []
                strokeCandidates.reserveCapacity(80)
                
                for p in limitedBase {
                    for (dx, dy) in offsets {
                        let nx = p.x + dx
                        let ny = p.y + dy
                        let (nr, ng, nb) = readRGB(x: nx, y: ny)
                        let nl = luma(r: nr, g: ng, b: nb)
                        let db = abs(nr - avgBgR) + abs(ng - avgBgG) + abs(nb - avgBgB)
                        let df = abs(nr - finalTextR) + abs(ng - finalTextG) + abs(nb - finalTextB)
                        let sat = saturation(r: nr, g: ng, b: nb)
                        let redness = max(0, nr - max(ng, nb))
                        let score = sat * (0.8 * df + 0.2 * db) + 0.35 * redness
                        if df >= 0.12, sat >= 0.18, nl >= min(0.95, fillLuma + 0.03), score >= 0.10 {
                            strokeCandidates.append((r: nr, g: ng, b: nb, score: score))
                        }
                    }
                }
                
                if strokeCandidates.count >= 6 {
                    let top = strokeCandidates.sorted { $0.score > $1.score }
                    let takeN = min(30, max(8, top.count / 2))
                    let chosen = Array(top.prefix(takeN))
                    let sr = median(chosen.map(\.r))
                    let sg = median(chosen.map(\.g))
                    let sb = median(chosen.map(\.b))
                    
                    strokeColor = NSColor(red: sr, green: sg, blue: sb, alpha: 1.0)
                    strokeWidth = min(8.0, max(4.0, boxHPx / 45.0))
                }
                
                if strokeColor == nil && fillLuma < 0.45 {
                    var globalStroke: [(r: CGFloat, g: CGFloat, b: CGFloat, score: CGFloat)] = []
                    globalStroke.reserveCapacity(120)
                    
                    for s in samples {
                        let sat = saturation(r: s.r, g: s.g, b: s.b)
                        if sat < 0.25 { continue }
                        if s.luma < min(0.95, fillLuma + 0.08) { continue }
                        
                        let df = abs(s.r - finalTextR) + abs(s.g - finalTextG) + abs(s.b - finalTextB)
                        let redness = max(0, s.r - max(s.g, s.b))
                        let score = sat * df + 0.25 * redness + 0.10 * s.luma
                        if df >= 0.12, score >= 0.12 {
                            globalStroke.append((r: s.r, g: s.g, b: s.b, score: score))
                        }
                    }
                    
                    if globalStroke.count >= 10 {
                        let top = globalStroke.sorted { $0.score > $1.score }
                        let takeN = min(40, max(10, top.count / 2))
                        let chosen = Array(top.prefix(takeN))
                        let sr = median(chosen.map(\.r))
                        let sg = median(chosen.map(\.g))
                        let sb = median(chosen.map(\.b))
                        
                        strokeColor = NSColor(red: sr, green: sg, blue: sb, alpha: 1.0)
                        strokeWidth = min(9.0, max(4.0, boxHPx / 35.0))
                    }
                }
            }
            
        } else {
            // 回退策略：如果采样区太小没采样到，尝试中心点
            let centerX = (safeXLeft + safeXRight) / 2
            let centerY = (safeYTop + safeYBottom) / 2
            let (r, g, b) = readRGB(x: centerX, y: centerY)
            finalTextR = r
            finalTextG = g
            finalTextB = b
        }

        if let stroke = strokeColor {
            let safeStroke = stroke.usingColorSpace(.sRGB) ?? stroke
            let sr = safeStroke.redComponent
            let sg = safeStroke.greenComponent
            let sb = safeStroke.blueComponent
            let sSat = saturation(r: sr, g: sg, b: sb)
            let redness = sr - max(sg, sb)
            
            let isLargeText = boxHPx >= 42
            let looksRedStroke = sr >= 0.28 && redness >= 0.10 && sSat >= 0.22
            if !isLargeText || !looksRedStroke {
                strokeColor = nil
                strokeWidth = nil
            }
        }
        
        let textLuma = luma(r: finalTextR, g: finalTextG, b: finalTextB)
        if textLuma < 0.22 {
            return (.black, bgColor, strokeColor, strokeWidth)
        }
        
        let textSat = saturation(r: finalTextR, g: finalTextG, b: finalTextB)
        if textLuma > 0.88, textSat < 0.20, bgLuma < 0.35 {
            return (.white, bgColor, strokeColor, strokeWidth)
        }
        
        let maxC = max(finalTextR, max(finalTextG, finalTextB))
        let minC = min(finalTextR, min(finalTextG, finalTextB))
        let delta = maxC - minC
        let saturation = maxC == 0 ? 0 : delta / maxC
        
        if saturation < 0.2 && textLuma < 0.8 {
            return (NSColor(white: textLuma, alpha: 1.0), bgColor, strokeColor, strokeWidth)
        }
        
        let textColor = NSColor(red: finalTextR, green: finalTextG, blue: finalTextB, alpha: 1.0)
        
        return (textColor, bgColor, strokeColor, strokeWidth)
    }

    /// 批量识别多张图片
    func recognizeText(in images: [NSImage], progressHandler: ((Int, Int) -> Void)? = nil) async throws -> [[TextBlock]] {
        var results: [[TextBlock]] = []

        for (index, image) in images.enumerated() {
            progressHandler?(index + 1, images.count)
            let blocks = try await recognizeText(in: image)
            results.append(blocks)
        }

        return results
    }
}

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .recognitionFailed(let message):
            return "文字识别失败: \(message)"
        }
    }
}
