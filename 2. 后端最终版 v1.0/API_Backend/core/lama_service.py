"""
Replicate LaMa Inpainting Service
用于文字擦除和背景修复
"""
import os
import base64
import replicate
from PIL import Image, ImageDraw
from io import BytesIO
from typing import List, Dict, Any
import requests
import tempfile


class LamaService:
    """使用 Replicate 的 LaMa 模型进行图像修复"""
    
    # 使用模型名称，让 Replicate 自动选择最新版本
    # 也可以尝试其他 inpainting 模型如 "fofr/latent-consistency-model-inpaint"
    MODEL_NAME = "lucataco/lama"
    
    def __init__(self, api_token: str = None):
        self.api_token = api_token or os.getenv("REPLICATE_API_TOKEN")
        if not self.api_token:
            raise ValueError("REPLICATE_API_TOKEN is required")
        
        # 设置环境变量供 replicate 库使用
        os.environ["REPLICATE_API_TOKEN"] = self.api_token
    
    def _create_mask_from_text_blocks(
        self, 
        image_size: tuple, 
        text_blocks: List[Dict[str, Any]],
        padding: int = 5
    ) -> Image.Image:
        """
        根据 OCR 检测到的文字区域创建 mask
        
        Args:
            image_size: (width, height) 图片尺寸
            text_blocks: OCR 检测到的文字块列表，每个块包含 x, y, width, height（归一化坐标）
            padding: 额外扩展的像素数，确保完全覆盖文字
        
        Returns:
            mask 图像：白色区域为需要擦除的部分，黑色为保留部分
        """
        width, height = image_size
        # 创建全黑的 mask（黑色 = 保留区域）
        mask = Image.new("L", (width, height), 0)
        draw = ImageDraw.Draw(mask)
        
        for block in text_blocks:
            # 将归一化坐标转换为像素坐标
            x = int(block["x"] * width)
            y = int(block["y"] * height)
            w = int(block["width"] * width)
            h = int(block["height"] * height)
            
            # 添加 padding
            x1 = max(0, x - padding)
            y1 = max(0, y - padding)
            x2 = min(width, x + w + padding)
            y2 = min(height, y + h + padding)
            
            # 画白色矩形（白色 = 需要擦除的区域）
            draw.rectangle([x1, y1, x2, y2], fill=255)
        
        return mask
    
    def inpaint(
        self, 
        image: Image.Image, 
        text_blocks: List[Dict[str, Any]]
    ) -> Image.Image:
        """
        使用 LaMa 模型擦除图片中的文字
        
        Args:
            image: 原始图片
            text_blocks: OCR 检测到的文字块列表
        
        Returns:
            处理后的图片（文字已被擦除）
        """
        if not text_blocks:
            print("[LaMa] 没有文字块需要擦除，返回原图")
            return image
        
        # 确保图片是 RGB 模式
        if image.mode != "RGB":
            image = image.convert("RGB")
        
        print(f"[LaMa] 原始图片尺寸: {image.size}")
        
        # 如果图片太大，缩小到合理尺寸
        max_side = 1536  # 减小最大尺寸以加快上传
        original_size = image.size
        if image.width > max_side or image.height > max_side:
            ratio = min(max_side / image.width, max_side / image.height)
            new_size = (int(image.width * ratio), int(image.height * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
            print(f"[LaMa] 缩放后尺寸: {image.size}")
        
        # 创建 mask
        mask = self._create_mask_from_text_blocks(image.size, text_blocks)
        print(f"[LaMa] Mask 生成完成，覆盖 {len(text_blocks)} 个文字区域")
        
        # 保存为临时文件并使用文件上传方式
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as img_tmp:
            image.save(img_tmp.name, format="PNG", optimize=True)
            img_path = img_tmp.name
            
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as mask_tmp:
            mask.save(mask_tmp.name, format="PNG", optimize=True)
            mask_path = mask_tmp.name
        
        try:
            # 调用 Replicate API - 使用文件对象
            print("[LaMa] 调用 Replicate API（文件上传方式）...")
            
            with open(img_path, "rb") as img_file, open(mask_path, "rb") as mask_file:
                output = replicate.run(
                    self.MODEL_NAME,
                    input={
                        "image": img_file,
                        "mask": mask_file
                    }
                )
            
            # output 是一个 URL 或 FileOutput 对象
            if hasattr(output, 'url'):
                result_url = output.url
            elif isinstance(output, str):
                result_url = output
            else:
                result_url = str(output)
            
            print(f"[LaMa] 处理完成，下载结果: {result_url[:50]}...")
            
            # 下载结果图片
            response = requests.get(result_url, timeout=120)
            response.raise_for_status()
            result_image = Image.open(BytesIO(response.content))
            
            # 确保是 RGB 模式
            if result_image.mode != "RGB":
                result_image = result_image.convert("RGB")
            
            # 如果之前缩放过，恢复原始尺寸
            if result_image.size != original_size:
                result_image = result_image.resize(original_size, Image.Resampling.LANCZOS)
                print(f"[LaMa] 恢复到原始尺寸: {result_image.size}")
            
            return result_image
            
        except Exception as e:
            print(f"[LaMa] API 调用失败: {e}")
            import traceback
            traceback.print_exc()
            raise e
            
        finally:
            # 清理临时文件
            try:
                os.unlink(img_path)
                os.unlink(mask_path)
            except:
                pass
