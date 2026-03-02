import os
import time
import json
import base64
import requests
from PIL import Image
from io import BytesIO
from typing import Optional

class NanoBananaService:
    BASE_URL = "https://grsai.dakka.com.cn/v1/draw/nano-banana"
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("NANO_API_KEY")
        if not self.api_key:
            raise ValueError("Nano Banana Pro API Key is required")
        self.initial_timeout = int(os.getenv("NANO_INITIAL_TIMEOUT", "150"))
        self.poll_timeout = int(os.getenv("NANO_POLL_TIMEOUT", "270"))
        self.max_retries = int(os.getenv("NANO_REQUEST_RETRIES", "2"))
        self.retry_backoff_seconds = float(os.getenv("NANO_RETRY_BACKOFF_SECONDS", "2"))
            
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

    def _encode_image(self, image: Image.Image) -> str:
        """Convert PIL Image to Base64 string"""
        # 如果是 RGBA 模式，转换为 RGB（JPEG 不支持透明通道）
        if image.mode == 'RGBA':
            image = image.convert('RGB')
        buffered = BytesIO()
        image.save(buffered, format="JPEG", quality=90)
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
        return f"data:image/jpeg;base64,{img_str}"

    def _download_image(self, url: str) -> Image.Image:
        """Download image from URL"""
        resp = requests.get(url, timeout=60)
        resp.raise_for_status()
        return Image.open(BytesIO(resp.content))

    def generate_image(self, image: Image.Image, prompt: str) -> Image.Image:
        """
        Generate/Inpaint image using Nano Banana Pro.
        Synchronous wrapper that handles polling.
        """
        print(f"[Nano] 输入图片尺寸: {image.size}, 模式: {image.mode}")
        
        # 如果图片太大，缩小到合理尺寸
        max_side = 2048
        if image.width > max_side or image.height > max_side:
            ratio = min(max_side / image.width, max_side / image.height)
            new_size = (int(image.width * ratio), int(image.height * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)
            print(f"[Nano] 缩放后尺寸: {image.size}")
        
        base64_img = self._encode_image(image)
        
        payload = {
            "model": "nano-banana-pro",
            "prompt": prompt,
            "aspectRatio": "auto",
            "imageSize": "1K",
            "urls": [base64_img],
            "webHook": "-1",
            "shutProgress": True
        }
        
        # 1. Initiate Request
        data = None
        for attempt in range(self.max_retries + 1):
            try:
                response = requests.post(
                    self.BASE_URL,
                    headers=self.headers,
                    json=payload,
                    timeout=self.initial_timeout
                )
                response.raise_for_status()
                data = response.json()
                break
            except requests.Timeout as e:
                if attempt >= self.max_retries:
                    raise e
                wait_seconds = self.retry_backoff_seconds * (attempt + 1)
                print(f"Nano initial request timeout, retrying in {wait_seconds}s (attempt {attempt + 1}/{self.max_retries})")
                time.sleep(wait_seconds)
            except requests.RequestException as e:
                if isinstance(e, requests.HTTPError):
                    body = e.response.text if e.response is not None else ""
                    print(f"Nano API HTTP Error: {body}")
                raise e

        if data is None:
            raise Exception("Nano API initial request failed after retries")

        data_map = data

        if data_map.get("code", -1) != 0:
            msg = data_map.get("msg", "Unknown Error")
            raise Exception(f"Nano API Error (Code {data_map.get('code')}): {msg}")
            
        result_data = data_map.get("data", data_map)
        
        # Check for immediate result
        if "results" in result_data and result_data["results"]:
            first_result = result_data["results"][0]
            if "url" in first_result:
                return self._download_image(first_result["url"])
                
        # 2. Get Task ID and Poll
        task_id = result_data.get("id")
        if not task_id:
             raise Exception("No Task ID returned from Nano API")
             
        return self._poll_result(task_id, timeout=self.poll_timeout)

    def _poll_result(self, task_id: str, timeout: int = 180) -> Image.Image:
        """Poll for task result"""
        poll_url = "https://grsai.dakka.com.cn/v1/draw/result"
        start_time = time.time()
        
        while (time.time() - start_time) < timeout:
            try:
                resp = requests.post(
                    poll_url, 
                    headers=self.headers, 
                    json={"id": task_id}, 
                    timeout=30
                )
                
                if resp.status_code != 200:
                    print(f"Poll warning: {resp.status_code} - {resp.text}")
                    time.sleep(2)
                    continue
                    
                data = resp.json()
                
                # Check business logic code
                if data.get("code", 0) != 0:
                     # Some APIs return code != 0 for pending? Usually 0 is success. 
                     # Let's check status inside data
                     pass

                payload = data.get("data", data)
                status = payload.get("status", "").lower()
                
                if status == "failed":
                    reason = payload.get("failure_reason", "Unknown failure")
                    raise Exception(f"Nano API 任务失败: {reason}")
                
                if "results" in payload and payload["results"]:
                     first_result = payload["results"][0]
                     if "url" in first_result:
                         return self._download_image(first_result["url"])
                         
            except Exception as e:
                error_str = str(e)
                # 如果是明确的任务失败，直接抛出，不继续轮询
                if "任务失败" in error_str or "Task Failed" in error_str:
                    raise
                print(f"Polling error: {e}")
                
            time.sleep(2)
            
        raise Exception("Nano API Timeout")
