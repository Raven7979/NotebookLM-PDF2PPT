import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import numpy as np
from typing import List, Dict, Any
from PIL import Image
from paddleocr import PaddleOCR
import logging

# Initialize PaddleOCR globally
# use_angle_cls=True allows detecting rotated text
# lang='ch' supports both Chinese and English
ocr_engine = PaddleOCR(use_angle_cls=True, lang='ch') 

class OCRService:
    def __init__(self):
        self.ocr = ocr_engine

    def extract_text(self, image: Image.Image) -> List[Dict[str, Any]]:
        """
        Extract text from PIL Image using PaddleOCR.
        Returns a list of dictionaries compatible with the expected TextBlock format.
        Supports both PaddleOCR 2.x and 3.x output formats.
        """
        if image.mode != 'RGB':
            image = image.convert('RGB')
        img_np = np.array(image)
        img_h, img_w = img_np.shape[:2]
        
        # Perform OCR
        try:
            result = self.ocr.ocr(img_np)
            print(f"===== DEBUG OCR =====")
            print(f"result 类型: {type(result)}")
            if result is not None and len(result) > 0:
                first = result[0]
                print(f"result[0] 类型: {type(first)}")
                if hasattr(first, 'keys'):
                    print(f"result[0] 键: {list(first.keys())}")
                elif isinstance(first, dict):
                    print(f"result[0] 字典键: {list(first.keys())}")
            print(f"=====================")
        except Exception as e:
            print(f"PaddleOCR error: {e}")
            import traceback
            traceback.print_exc()
            return []
        
        blocks = []
        if not result or result[0] is None:
            print("PaddleOCR 返回空结果")
            return blocks

        ocr_result = result[0]
        
        # 检测是新版 3.x 字典格式还是旧版列表格式
        is_dict_format = isinstance(ocr_result, dict) or hasattr(ocr_result, 'get') or hasattr(ocr_result, 'rec_texts')
        
        if is_dict_format:
            # PaddleOCR 3.x 新格式
            print("检测到 PaddleOCR 3.x 字典格式")
            blocks = self._parse_v3_format(ocr_result, img_w, img_h)
        else:
            # PaddleOCR 2.x 旧格式 [[box, (text, score)], ...]
            print("检测到 PaddleOCR 2.x 列表格式")
            blocks = self._parse_v2_format(ocr_result, img_w, img_h)
        
        print(f"共解析 {len(blocks)} 个文本块")
        return blocks
    
    def _parse_v3_format(self, ocr_result, img_w: int, img_h: int) -> List[Dict[str, Any]]:
        """解析 PaddleOCR 3.x 字典格式结果"""
        blocks = []
        
        # 尝试获取各字段
        rec_texts = self._get_attr(ocr_result, 'rec_texts', [])
        rec_boxes = self._get_attr(ocr_result, 'rec_boxes', [])
        rec_scores = self._get_attr(ocr_result, 'rec_scores', [])
        
        # 如果 rec_boxes 为空，尝试用 rec_polys
        if self._is_empty(rec_boxes):
            rec_boxes = self._get_attr(ocr_result, 'rec_polys', [])
        
        print(f"rec_texts: {self._safe_len(rec_texts)}")
        print(f"rec_boxes: {self._safe_len(rec_boxes)}")
        print(f"rec_scores: {self._safe_len(rec_scores)}")
        
        if self._is_empty(rec_texts):
            print("未找到识别文本，尝试其他键名...")
            # 尝试其他可能的键名
            for key in ['texts', 'text', 'ocr_texts']:
                rec_texts = self._get_attr(ocr_result, key, [])
                if not self._is_empty(rec_texts):
                    print(f"在 '{key}' 中找到文本")
                    break
        
        if self._is_empty(rec_texts):
            print("仍未找到文本，返回空")
            return blocks
        
        for i, text in enumerate(rec_texts):
            try:
                confidence = rec_scores[i] if i < len(rec_scores) else 0.9
                
                # 获取边界框
                if i < len(rec_boxes):
                    box = rec_boxes[i]
                    min_x, max_x, min_y, max_y = self._parse_box(box)
                else:
                    continue
                
                # 归一化坐标
                x = min_x / img_w
                y = min_y / img_h
                w = (max_x - min_x) / img_w
                h = (max_y - min_y) / img_h
                
                # 样式估算
                font_size, is_bold = self._estimate_style(h, len(text))
                
                blocks.append({
                    "id": str(i),
                    "text": str(text),
                    "confidence": float(confidence),
                    "x": x,
                    "y": y,
                    "width": w,
                    "height": h,
                    "fontSize": font_size,
                    "color": "#000000",
                    "isBold": is_bold
                })
            except Exception as e:
                print(f"处理第 {i} 个文本时出错: {e}")
                continue
        
        return blocks
    
    def _parse_v2_format(self, ocr_result, img_w: int, img_h: int) -> List[Dict[str, Any]]:
        """解析 PaddleOCR 2.x 列表格式结果"""
        blocks = []
        
        for i, line in enumerate(ocr_result):
            try:
                points = line[0]  # [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                text_info = line[1]  # (text, confidence)
                text = text_info[0]
                confidence = text_info[1]
                
                # 计算边界框
                xs = [p[0] for p in points]
                ys = [p[1] for p in points]
                min_x, max_x = min(xs), max(xs)
                min_y, max_y = min(ys), max(ys)
                
                # 归一化
                x = min_x / img_w
                y = min_y / img_h
                w = (max_x - min_x) / img_w
                h = (max_y - min_y) / img_h
                
                # 样式估算
                font_size, is_bold = self._estimate_style(h, len(text))
                
                blocks.append({
                    "id": str(i),
                    "text": text,
                    "confidence": float(confidence),
                    "x": x,
                    "y": y,
                    "width": w,
                    "height": h,
                    "fontSize": font_size,
                    "color": "#000000",
                    "isBold": is_bold
                })
            except Exception as e:
                logging.warning(f"跳过格式错误的行 {i}: {e}")
                continue
        
        return blocks
    
    def _get_attr(self, obj, key: str, default):
        """安全获取对象属性或字典值"""
        if hasattr(obj, 'get'):
            return obj.get(key, default)
        elif hasattr(obj, key):
            return getattr(obj, key)
        elif isinstance(obj, dict):
            return obj.get(key, default)
        return default
    
    def _is_empty(self, arr) -> bool:
        """安全检查数组是否为空，兼容 NumPy 数组"""
        if arr is None:
            return True
        try:
            return len(arr) == 0
        except:
            return False
    
    def _safe_len(self, arr) -> int:
        """安全获取数组长度，兼容 NumPy 数组"""
        if arr is None:
            return 0
        try:
            return len(arr)
        except:
            return 0
    
    def _parse_box(self, box):
        """解析边界框，支持多种格式"""
        if isinstance(box, (list, np.ndarray)) and len(box) >= 4:
            if isinstance(box[0], (list, np.ndarray)):
                # 四点格式 [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                xs = [p[0] for p in box]
                ys = [p[1] for p in box]
                return min(xs), max(xs), min(ys), max(ys)
            else:
                # [x1, y1, x2, y2] 或 [x1, y1, x2, y2, ...] 格式
                return box[0], box[2], box[1], box[3]
        raise ValueError(f"无法解析 box 格式: {box}")
    
    def _estimate_style(self, h_ratio: float, text_len: int):
        """估算字体大小和粗体"""
        ppt_slide_height_pt = 540
        font_size_ratio = h_ratio * 0.70
        calc_size = int(font_size_ratio * ppt_slide_height_pt)
        font_size = max(10, calc_size)
        
        is_large_font = font_size_ratio > 0.04
        is_medium_or_large = font_size_ratio > 0.025
        is_short_text = text_len <= 20
        is_bold = (is_large_font and is_short_text) or (is_medium_or_large and text_len <= 30)
        
        return font_size, is_bold
