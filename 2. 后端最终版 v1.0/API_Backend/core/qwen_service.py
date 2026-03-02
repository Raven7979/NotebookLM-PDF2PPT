import os
import base64
import httpx
import json
import asyncio
from typing import List, Dict, Any, Optional
from io import BytesIO
from PIL import Image

class QwenService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("DASHSCOPE_API_KEY")
        self.base_url = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        self.inpainting_url = "https://dashscope.aliyuncs.com/api/v1/services/aigc/image2image/image-synthesis"
        
        if not self.api_key:
            print("Warning: DASHSCOPE_API_KEY is not set.")

    def _image_to_base64(self, image: Image.Image, format: str = "JPEG") -> str:
        buffered = BytesIO()
        image.save(buffered, format=format)
        return base64.b64encode(buffered.getvalue()).decode('utf-8')

    async def analyze_image(self, image: Image.Image) -> List[Dict[str, Any]]:
        """
        使用千问VL分析图片中的文字
        对应 Swift: analyzeImage(_ image: NSImage)
        """
        if not self.api_key:
            print("Warning: No API Key found. Returning MOCK data for analysis.")
            return [
                {"text": "MOCK TITLE", "x": 0.1, "y": 0.1, "width": 0.8, "height": 0.1, "fontSize": 40, "color": "000000", "bgColor": "FFFFFF", "isBold": True},
                {"text": "This is a mock paragraph generated because no API key was provided.", "x": 0.1, "y": 0.3, "width": 0.8, "height": 0.2, "fontSize": 20, "color": "000000", "bgColor": "FFFFFF", "isBold": False}
            ]

        # Resize logic similar to Swift (max 1400)
        max_dimension = 1400
        if max(image.size) > max_dimension:
            image.thumbnail((max_dimension, max_dimension))

        base64_image = self._image_to_base64(image)
        
        prompt = """
        请分析这张图片中的所有文字，每个独立的文字行作为一个文字块，返回JSON格式的数组。每个文字块包含：
        - text: 文字内容（单行，不要合并多行）
        - x: 左上角x坐标（相对于图片宽度的比例，0-1）
        - y: 左上角y坐标（相对于图片高度的比例，0-1）
        - width: 宽度（相对于图片宽度的比例，0-1）
        - height: 高度（相对于图片高度的比例，0-1）
        - fontSize: 估计的字体大小（像素）
        - color: 文字颜色（十六进制，如"000000"）
        - bgColor: 背景颜色（十六进制，如"FFFFFF"）
        - isBold: 是否为粗体或标题（true/false）

        重要：每行文字单独作为一个文字块，不要把多行合并成一段。标题、大字通常是粗体。
        只返回JSON数组，不要其他内容。示例格式：
        [{"text":"标题","x":0.1,"y":0.05,"width":0.8,"height":0.05,"fontSize":48,"color":"000000","bgColor":"FFFFFF","isBold":true}]
        """

        payload = {
            "model": "qwen-vl-max",
            "input": {
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"image": f"data:image/jpeg;base64,{base64_image}"},
                            {"text": prompt}
                        ]
                    }
                ]
            }
        }

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(self.base_url, json=payload, headers=headers)
            
            if response.status_code != 200:
                raise Exception(f"Qwen API failed: {response.text}")
            
            result = response.json()
            
            # Parse the text response which should be JSON
            try:
                # Qwen response structure: output.choices[0].message.content[0].text
                # Note: Structure might vary slightly based on exact API version, checking standard Qwen VL response
                if 'output' in result and 'choices' in result['output']:
                    content = result['output']['choices'][0]['message']['content']
                    # content is a list, find the text part
                    text_response = ""
                    for item in content:
                        if 'text' in item:
                            text_response = item['text']
                            break
                    
                    # Clean up markdown code blocks if present
                    text_response = text_response.replace("```json", "").replace("```", "").strip()
                    return json.loads(text_response)
                else:
                    raise Exception("Unexpected API response structure")
            except Exception as e:
                print(f"Failed to parse Qwen response: {e}")
                return []

    async def inpaint_image(self, image: Image.Image, text_blocks: List[Dict[str, Any]]) -> Image.Image:
        """
        使用通义万相进行图像修复 - 去除文字 (暂未实现完整逻辑，仅返回原图作为占位)
        对应 Swift: inpaintImage
        """
        # TODO: Implement actual inpainting API call
        # Swift logic creates a mask from text_blocks and calls the API.
        # For now, return original image to ensure pipeline works.
        return image
