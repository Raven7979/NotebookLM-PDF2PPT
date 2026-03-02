import Foundation
import AppKit
import Compression

/// PPTX文件生成器
/// PPTX本质是ZIP压缩的Office Open XML文件集合
class PPTXGenerator {
    // 标准PPT尺寸 (16:9, 单位EMU: 1英寸=914400 EMU)
    private let slideWidth: Int = 12192000   // 约13.33英寸
    private let slideHeight: Int = 6858000   // 约7.5英寸

    /// 生成PPTX文件
    func generate(pages: [ProcessedPage], outputURL: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 创建PPTX目录结构
        try createDirectoryStructure(at: tempDir)

        // 创建基础XML文件
        try createContentTypes(at: tempDir, pageCount: pages.count)
        try createRels(at: tempDir)
        try createPresentation(at: tempDir, pageCount: pages.count)
        try createPresentationRels(at: tempDir, pageCount: pages.count)
        try createSlideMaster(at: tempDir)
        try createSlideLayout(at: tempDir)
        try createTheme(at: tempDir)

        // 为每页创建slide
        for (index, page) in pages.enumerated() {
            try createSlide(at: tempDir, index: index, page: page)
        }

        // 打包为ZIP
        try zipDirectory(tempDir, to: outputURL)
    }

    private func createDirectoryStructure(at dir: URL) throws {
        let directories = [
            "_rels",
            "docProps",
            "ppt",
            "ppt/_rels",
            "ppt/media",
            "ppt/slideLayouts",
            "ppt/slideLayouts/_rels",
            "ppt/slideMasters",
            "ppt/slideMasters/_rels",
            "ppt/slides",
            "ppt/slides/_rels",
            "ppt/theme"
        ]

        for subdir in directories {
            try FileManager.default.createDirectory(
                at: dir.appendingPathComponent(subdir),
                withIntermediateDirectories: true
            )
        }
    }

    private func createContentTypes(at dir: URL, pageCount: Int) throws {
        var slideOverrides = ""
        for i in 1...pageCount {
            slideOverrides += """
              <Override PartName="/ppt/slides/slide\(i).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>

            """
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Default Extension="jpeg" ContentType="image/jpeg"/>
          <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
          <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
          <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
          <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        \(slideOverrides)</Types>
        """

        try xml.write(to: dir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
    }

    private func createRels(at dir: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """

        try xml.write(to: dir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
    }

    private func createPresentation(at dir: URL, pageCount: Int) throws {
        var slideList = ""
        for i in 1...pageCount {
            slideList += "    <p:sldId id=\"\(255 + i)\" r:id=\"rId\(i + 2)\"/>\n"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                        saveSubsetFonts="1">
          <p:sldMasterIdLst>
            <p:sldMasterId id="2147483648" r:id="rId1"/>
          </p:sldMasterIdLst>
          <p:sldIdLst>
        \(slideList)  </p:sldIdLst>
          <p:sldSz cx="\(slideWidth)" cy="\(slideHeight)"/>
          <p:notesSz cx="\(slideHeight)" cy="\(slideWidth)"/>
        </p:presentation>
        """

        try xml.write(to: dir.appendingPathComponent("ppt/presentation.xml"), atomically: true, encoding: .utf8)
    }

    private func createPresentationRels(at dir: URL, pageCount: Int) throws {
        var slideRels = ""
        for i in 1...pageCount {
            slideRels += """
              <Relationship Id="rId\(i + 2)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\(i).xml"/>

            """
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
        \(slideRels)</Relationships>
        """

        try xml.write(to: dir.appendingPathComponent("ppt/_rels/presentation.xml.rels"), atomically: true, encoding: .utf8)
    }

    private func createSlideMaster(at dir: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                     xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr/>
            </p:spTree>
          </p:cSld>
          <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
          <p:sldLayoutIdLst>
            <p:sldLayoutId id="2147483649" r:id="rId1"/>
          </p:sldLayoutIdLst>
        </p:sldMaster>
        """

        try xml.write(to: dir.appendingPathComponent("ppt/slideMasters/slideMaster1.xml"), atomically: true, encoding: .utf8)

        let relsXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """

        try relsXml.write(to: dir.appendingPathComponent("ppt/slideMasters/_rels/slideMaster1.xml.rels"), atomically: true, encoding: .utf8)
    }

    private func createSlideLayout(at dir: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                     xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                     xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                     type="blank">
          <p:cSld name="Blank">
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr/>
            </p:spTree>
          </p:cSld>
        </p:sldLayout>
        """

        try xml.write(to: dir.appendingPathComponent("ppt/slideLayouts/slideLayout1.xml"), atomically: true, encoding: .utf8)

        let relsXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """

        try relsXml.write(to: dir.appendingPathComponent("ppt/slideLayouts/_rels/slideLayout1.xml.rels"), atomically: true, encoding: .utf8)
    }

    private func createTheme(at dir: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
          <a:themeElements>
            <a:clrScheme name="Office">
              <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
              <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
              <a:dk2><a:srgbClr val="44546A"/></a:dk2>
              <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
              <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
              <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
              <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
              <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
              <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
              <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
              <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
              <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
            </a:clrScheme>
            <a:fontScheme name="Office">
              <a:majorFont>
                <a:latin typeface="Calibri Light"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:majorFont>
              <a:minorFont>
                <a:latin typeface="Calibri"/>
                <a:ea typeface=""/>
                <a:cs typeface=""/>
              </a:minorFont>
            </a:fontScheme>
            <a:fmtScheme name="Office">
              <a:fillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
              </a:fillStyleLst>
              <a:lnStyleLst>
                <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
                <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
              </a:lnStyleLst>
              <a:effectStyleLst>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst/></a:effectStyle>
                <a:effectStyle><a:effectLst/></a:effectStyle>
              </a:effectStyleLst>
              <a:bgFillStyleLst>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
                <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
              </a:bgFillStyleLst>
            </a:fmtScheme>
          </a:themeElements>
        </a:theme>
        """

        try xml.write(to: dir.appendingPathComponent("ppt/theme/theme1.xml"), atomically: true, encoding: .utf8)
    }

    private func createSlide(at dir: URL, index: Int, page: ProcessedPage) throws {
        let slideNum = index + 1

        // 保存图片
        let imageFileName = "image\(slideNum).png"
        let imageURL = dir.appendingPathComponent("ppt/media/\(imageFileName)")
        if let tiffData = page.inpaintedImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try pngData.write(to: imageURL)
        }

        // 生成文字框XML
        let textBoxes = generateTextBoxes(page.textBlocks, imageSize: page.inpaintedImage.size)

        let slideXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
          <p:cSld>
            <p:spTree>
              <p:nvGrpSpPr>
                <p:cNvPr id="1" name=""/>
                <p:cNvGrpSpPr/>
                <p:nvPr/>
              </p:nvGrpSpPr>
              <p:grpSpPr/>
              <p:pic>
                <p:nvPicPr>
                  <p:cNvPr id="2" name="Background"/>
                  <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
                  <p:nvPr/>
                </p:nvPicPr>
                <p:blipFill>
                  <a:blip r:embed="rId2"/>
                  <a:stretch><a:fillRect/></a:stretch>
                </p:blipFill>
                <p:spPr>
                  <a:xfrm>
                    <a:off x="0" y="0"/>
                    <a:ext cx="\(slideWidth)" cy="\(slideHeight)"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                </p:spPr>
              </p:pic>
        \(textBoxes)
            </p:spTree>
          </p:cSld>
        </p:sld>
        """

        try slideXml.write(to: dir.appendingPathComponent("ppt/slides/slide\(slideNum).xml"), atomically: true, encoding: .utf8)

        // 创建slide关系文件
        let relsXml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(imageFileName)"/>
        </Relationships>
        """

        try relsXml.write(to: dir.appendingPathComponent("ppt/slides/_rels/slide\(slideNum).xml.rels"), atomically: true, encoding: .utf8)
    }

    private func generateTextBoxes(_ blocks: [TextBlock], imageSize: CGSize) -> String {
        var result = ""
        // 打印原始块信息以便调试
        print("PPTXGenerator: Original blocks count: \\(blocks.count)")
        
        let filteredBlocks = pruneSmallDuplicateTitles(blocks)
        print("PPTXGenerator: Generating \\(filteredBlocks.count) text boxes (after pruning) for slide size \\(imageSize)")
        
        // 调整垂直重叠的文本块，确保它们不会互相覆盖
        let adjustedBlocks = adjustVerticalOverlap(filteredBlocks)

        var shapeId = 100
        for (index, block) in adjustedBlocks.enumerated() {
            // 将归一化坐标转换为EMU
            // 千问返回的坐标：y从顶部开始（0在顶部）
            let x = Int(block.boundingBox.minX * CGFloat(slideWidth))
            let y = Int(block.boundingBox.minY * CGFloat(slideHeight))
            let cx = Int(block.boundingBox.width * CGFloat(slideWidth))
            // 使用调整后的高度
            let cy = Int(block.boundingBox.height * CGFloat(slideHeight))
            
            let colorHex = block.colorHex()
            
            if index < 3 {
                let strokeHex = block.strokeColor.map { block.colorHex(for: $0) } ?? "nil"
                let strokeW = block.strokeWidth.map { String(format: "%.2f", $0) } ?? "nil"
                print("  - Box \(index): rect=\(block.boundingBox) -> x=\(x), y=\(y), cx=\(cx), cy=\(cy) color=\(colorHex) stroke=\(strokeHex) w=\(strokeW)")
            }

            // 直接使用 fontSizeRatio 计算字号（不再吸附到标准字号）
            // slideHeight 对应 540 points (7.5英寸 * 72 DPI)
            let slideHeightPoints: CGFloat = 540
            
            // fontSizeRatio 是文字高度占图片高度的比例
            // 直接乘以幻灯片高度得到字号（单位：points）
            let rawFontSize = block.fontSizeRatio * slideHeightPoints
            
            // 不再使用 snapFontSize，保持原始精度
            let fontSizePoints = max(8.0, min(200.0, rawFontSize))
            let fontSize = min(20000, max(800, Int(fontSizePoints * 100)))
            
            // 加粗属性
            let boldAttr = block.isBold ? " b=\"1\"" : ""

            let escapedText = block.text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")

            let rotation = block.rotation.truncatingRemainder(dividingBy: 360)
            let normalizedRotation = rotation < 0 ? (rotation + 360) : rotation
            let rotValue = Int((normalizedRotation * 60000).rounded())
            let rotAttr = rotValue != 0 ? " rot=\"\(rotValue)\"" : ""
            
            // 描边属性
            var lnAttr = ""
            if let strokeColor = block.strokeColor, let strokeWidth = block.strokeWidth {
                let strokeHex = block.colorHex(for: strokeColor)
                // PPTX stroke width单位是 EMU (1 pt = 12700 EMU)
                let strokePt = max(2.0, min(10.0, strokeWidth))
                let strokeEmu = Int((strokePt * 12700).rounded())
                lnAttr = """
                <a:ln w="\(strokeEmu)" cap="rnd">
                  <a:solidFill><a:srgbClr val="\(strokeHex)"/></a:solidFill>
                </a:ln>
                """
            }

            func makeTextShapeXml(shapeId: Int, lnAttr: String, fillXml: String) -> String {
                """
                      <p:sp>
                        <p:nvSpPr>
                          <p:cNvPr id="\(shapeId)" name="TextBox \(shapeId)"/>
                          <p:cNvSpPr txBox="1"/>
                          <p:nvPr/>
                        </p:nvSpPr>
                        <p:spPr>
                          <a:xfrm\(rotAttr)>
                            <a:off x="\(x)" y="\(y)"/>
                            <a:ext cx="\(cx)" cy="\(cy)"/>
                          </a:xfrm>
                          <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                          <a:noFill/>
                        </p:spPr>
                        <p:txBody>
                          <a:bodyPr wrap="square" rtlCol="0" anchor="ctr" lIns="0" tIns="0" rIns="0" bIns="0">
                            <a:normAutofit/>
                          </a:bodyPr>
                          <a:lstStyle/>
                          <a:p>
                            <a:pPr algn="l"/>
                            <a:r>
                              <a:rPr lang="zh-CN" sz="\(fontSize)"\(boldAttr) dirty="0">
                                \(lnAttr)
                                \(fillXml)
                                <a:latin typeface="Source Han Sans SC" panose="020B0500000000000000"/>
                                <a:ea typeface="Source Han Sans SC" panose="020B0500000000000000"/>
                                <a:cs typeface="Source Han Sans SC" panose="020B0500000000000000"/>
                              </a:rPr>
                              <a:t>\(escapedText)</a:t>
                            </a:r>
                          </a:p>
                        </p:txBody>
                      </p:sp>

                """
            }

            let fillOnlyXml = """
                                <a:solidFill>
                                  <a:srgbClr val="\(colorHex)"/>
                                </a:solidFill>
            """
            let noFillXml = "<a:noFill/>"

            if !lnAttr.isEmpty {
                result += makeTextShapeXml(shapeId: shapeId, lnAttr: lnAttr, fillXml: noFillXml)
                shapeId += 1
                result += makeTextShapeXml(shapeId: shapeId, lnAttr: "", fillXml: fillOnlyXml)
                shapeId += 1
            } else {
                result += makeTextShapeXml(shapeId: shapeId, lnAttr: "", fillXml: fillOnlyXml)
                shapeId += 1
            }
        }

        return result
    }
    
    /// 合并垂直相邻的文本块为段落
    /// 如果多个块在同一列（X 轴重叠）且垂直相邻或重叠，则合并为一个块
    private func adjustVerticalOverlap(_ blocks: [TextBlock]) -> [TextBlock] {
        guard blocks.count > 1 else { return blocks }
        
        // 按 Y 坐标排序
        let sortedBlocks = blocks.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
        var mergedBlocks: [TextBlock] = []
        var usedIndices = Set<Int>()
        
        for i in 0..<sortedBlocks.count {
            if usedIndices.contains(i) { continue }
            
            var currentGroup: [TextBlock] = [sortedBlocks[i]]
            usedIndices.insert(i)
            
            // 如果当前块是短文本且字号较大，是标题，不参与合并
            // 标题定义：≤30字 + >3%高度的字号
            let isTitle = sortedBlocks[i].text.count <= 30 && sortedBlocks[i].fontSizeRatio > 0.03
            if isTitle {
                mergedBlocks.append(sortedBlocks[i])
                continue
            }
            
            // 查找所有与当前块垂直相邻且在同一列的块
            for j in (i + 1)..<sortedBlocks.count {
                if usedIndices.contains(j) { continue }
                
                let lastInGroup = currentGroup.last!
                let candidate = sortedBlocks[j]
                
                // 检查字号是否相近（相差不超过 50%）
                let fontRatio = lastInGroup.fontSizeRatio / max(candidate.fontSizeRatio, 0.001)
                guard fontRatio > 0.5 && fontRatio < 2.0 else { continue }
                
                // 检查 X 轴重叠
                let xOverlap = min(lastInGroup.boundingBox.maxX, candidate.boundingBox.maxX) - 
                               max(lastInGroup.boundingBox.minX, candidate.boundingBox.minX)
                let xOverlapRatio = xOverlap / min(lastInGroup.boundingBox.width, candidate.boundingBox.width)
                
                guard xOverlapRatio > 0.5 else { continue }
                
                // 检查 Y 轴是否相邻或重叠（间隙不超过一行高度）
                let gap = candidate.boundingBox.minY - lastInGroup.boundingBox.maxY
                let maxGap = lastInGroup.boundingBox.height * 1.2  // 更严格的间隙限制
                
                if gap < maxGap && gap > -lastInGroup.boundingBox.height * 0.5 {
                    currentGroup.append(candidate)
                    usedIndices.insert(j)
                }
            }
            
            // 合并当前组
            if currentGroup.count == 1 {
                mergedBlocks.append(currentGroup[0])
            } else {
                // 合并多个块为一个
                let mergedText = currentGroup.map { $0.text }.joined(separator: "")
                let minX = currentGroup.map { $0.boundingBox.minX }.min()!
                let minY = currentGroup.map { $0.boundingBox.minY }.min()!
                let maxX = currentGroup.map { $0.boundingBox.maxX }.max()!
                let maxY = currentGroup.map { $0.boundingBox.maxY }.max()!
                let mergedBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                
                // 使用最小的字号（正文通常字号最小，避免被大标题污染）
                let minFontSizeRatio = currentGroup.map { $0.fontSizeRatio }.min()!
                let first = currentGroup[0]
                let merged = TextBlock(
                    text: mergedText,
                    confidence: first.confidence,
                    boundingBox: mergedBox,
                    fontSizeRatio: minFontSizeRatio,  // 使用最小字号
                    textColor: first.textColor,
                    backgroundColor: first.backgroundColor,
                    isBold: false,  // 合并后的段落不设置粗体
                    rotation: first.rotation,
                    strokeColor: first.strokeColor,
                    strokeWidth: first.strokeWidth
                )
                mergedBlocks.append(merged)
                print("  MERGED \\(currentGroup.count) blocks into one: '\\(mergedText.prefix(30))...'")
            }
        }
        
        print("  Original: \\(blocks.count), After merge: \\(mergedBlocks.count)")
        return mergedBlocks
    }

    private func pruneSmallDuplicateTitles(_ blocks: [TextBlock]) -> [TextBlock] {
        // 1. 定义评分结构
        struct ScoredBlock {
            let index: Int
            let block: TextBlock
            let score: CGFloat
            let textClean: String
        }
        
        // 2. 辅助函数
        func cleanText(_ s: String) -> String {
            return s.components(separatedBy: .whitespacesAndNewlines).joined().lowercased()
        }
        
        func calculateScore(_ b: TextBlock) -> CGFloat {
            let area = b.boundingBox.width * b.boundingBox.height
            let h = b.boundingBox.height
            // 高度权重极大，保证大字排在前面
            return h * 10000.0 + area * 100.0 + CGFloat(b.confidence) * 10.0 + (b.isBold ? 5.0 : 0.0)
        }
        
        func isSpatialOverlap(_ r1: CGRect, _ r2: CGRect) -> Bool {
            let intersection = r1.intersection(r2)
            if intersection.isNull { return false }
            let area1 = r1.width * r1.height
            let area2 = r2.width * r2.height
            let interArea = intersection.width * intersection.height
            
            // IoU 超过 0.3 即视为重叠（对于文字块来说，这个阈值已经很高了，因为文字块通常很扁）
            let iou = interArea / (area1 + area2 - interArea)
            if iou > 0.3 { return true }
            
            // 包含关系：如果一个块包含另一个块的大部分 (>80%)
            if interArea / min(area1, area2) > 0.8 { return true }
            
            // 中心距离极近 (归一化距离 < 0.02)
            let c1 = CGPoint(x: r1.midX, y: r1.midY)
            let c2 = CGPoint(x: r2.midX, y: r2.midY)
            let dist = hypot(c1.x - c2.x, c1.y - c2.y)
            if dist < 0.02 { return true }
            
            return false
        }
        
        func isTextSimilar(_ s1: String, _ s2: String) -> Bool {
            if s1 == s2 { return true }
            if s1.contains(s2) || s2.contains(s1) { return true }
            // 简单的长度比较，如果长度差异不大且包含大部分字符，也算相似
            // 这里暂且只用包含关系，因为 OCR 识别通常是一个完整一个残缺
            return false
        }
        
        // 3. 准备数据并排序
        let scoredBlocks = blocks.enumerated().map { (i, b) in
            ScoredBlock(index: i, block: b, score: calculateScore(b), textClean: cleanText(b.text))
        }.sorted { $0.score > $1.score } // 分数高的（大字）在前
        
        print("DEBUG: Pruning duplicates (Fuzzy Logic). Total: \(blocks.count)")
        
        var keptIndices = Set<Int>()
        var droppedIndices = Set<Int>()
        
        // 4. 双重循环去重
        for candidate in scoredBlocks {
            // 如果已经被标记为删除了，跳过
            if droppedIndices.contains(candidate.index) { continue }
            
            var isDuplicate = false
            
            for keptIndex in keptIndices {
                // 找到对应的 ScoredBlock（这里效率略低但数量级小，无所谓）
                // 实际上我们可以维护一个 keptBlocks 数组
                guard let best = scoredBlocks.first(where: { $0.index == keptIndex }) else { continue }
                
                // 检查空间重叠
                if isSpatialOverlap(best.block.boundingBox, candidate.block.boundingBox) {
                    // 检查文本相似性
                    if isTextSimilar(best.textClean, candidate.textClean) {
                        // 既然 best 分数更高（排在前面），那 candidate 就是小弟
                        // 唯一的例外：如果 candidate 并不比 best 小多少（比如 > 90%），那可能是并列关系（虽然位置重叠很奇怪）
                        let ratio = candidate.block.boundingBox.height / max(best.block.boundingBox.height, 0.000001)
                        if ratio < 0.9 {
                            print("  DROP [\(candidate.index)] '\(candidate.textClean)' (overlaps [\(best.index)] '\(best.textClean)') Ratio: \(ratio)")
                            isDuplicate = true
                            break
                        } else {
                             print("  KEEP [\(candidate.index)] (overlaps but similar size to [\(best.index)])")
                        }
                    }
                }
                
                // 新增：检查 Y 坐标严重重叠（即使文字不同）
                // 这种情况通常是 OCR 把同一行识别成多个块
                let y1 = candidate.block.boundingBox.minY
                let y2 = candidate.block.boundingBox.maxY
                let by1 = best.block.boundingBox.minY
                let by2 = best.block.boundingBox.maxY
                let yOverlapMin = max(y1, by1)
                let yOverlapMax = min(y2, by2)
                let yOverlap = max(0, yOverlapMax - yOverlapMin)
                let candidateHeight = max(y2 - y1, 0.001)
                let yOverlapRatio = yOverlap / candidateHeight
                
                // 如果 Y 轴重叠超过 50%，且 candidate 明显小于 best
                if yOverlapRatio > 0.5 {
                    let sizeRatio = candidate.block.boundingBox.height / max(best.block.boundingBox.height, 0.000001)
                    if sizeRatio < 0.7 {
                        print("  DROP [\(candidate.index)] Y-overlap=\(String(format: "%.2f", yOverlapRatio)) sizeRatio=\(String(format: "%.2f", sizeRatio))")
                        isDuplicate = true
                        break
                    }
                }
            }
            
            if isDuplicate {
                droppedIndices.insert(candidate.index)
            } else {
                keptIndices.insert(candidate.index)
            }
        }
        
        print("DEBUG: Dropped \(droppedIndices.count) blocks.")
        
        // 5. 返回结果（保持原始顺序）
        return blocks.enumerated().compactMap { (i, b) in
            droppedIndices.contains(i) ? nil : b
        }
    }

    /// 将目录打包为ZIP文件
    private func zipDirectory(_ sourceDir: URL, to destinationURL: URL) throws {
        let tempZipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pptx")

        defer {
            try? FileManager.default.removeItem(at: tempZipURL)
        }

        // 使用zip命令创建ZIP（从目录内部打包，不包含父目录）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDir
        process.arguments = ["-r", "-q", tempZipURL.path, "."]

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            if let data = try? stderr.fileHandleForReading.readToEnd(),
               let text = String(data: data, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("zip stderr: \(text)")
            }
            throw PPTXError.zipFailed
        }

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: tempZipURL, to: destinationURL)
    }

    private func snapFontSize(_ points: CGFloat) -> CGFloat {
        // PPT 常用字号列表
        let standardSizes: [CGFloat] = [
            8, 9, 10, 10.5, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 44, 48, 54, 60, 66, 72, 80, 88, 96
        ]
        
        // 极值处理
        if points < 8 { return max(5, points) }
        if points > 96 { return points }
        
        var best = points
        var minDiff = CGFloat.greatestFiniteMagnitude
        
        for s in standardSizes {
            let diff = abs(s - points)
            if diff < minDiff {
                minDiff = diff
                best = s
            }
        }
        
        // 总是吸附到最近的标准字号，以保证最大程度的一致性
        return best
    }
}

enum PPTXError: Error, LocalizedError {
    case zipFailed
    case invalidPage

    var errorDescription: String? {
        switch self {
        case .zipFailed:
            return "创建PPTX文件失败"
        case .invalidPage:
            return "无效的页面数据"
        }
    }
}
