import os
import asyncio
from typing import Optional, Callable
from .pdf_processor import PDFProcessor
from .nano_service import NanoBananaService  # 恢复使用 Nano API
from .ocr_service import OCRService
from .pptx_generator import PPTXGenerator

class PDFToPPTConverter:
    def __init__(self, api_key: Optional[str] = None):
        self.pdf_processor = PDFProcessor()
        # 使用 Nano Banana Pro 服务进行文字擦除
        self.nano_service = NanoBananaService(api_key=api_key)
        self.ocr_service = OCRService()
        self.pptx_generator = PPTXGenerator()

    def convert(self, pdf_path: str, output_pptx_path: str, progress_callback: Optional[Callable[[int], None]] = None):
        """
        Orchestrates the conversion process using Local OCR and Nano Inpainting.
        """
        try:
            # 1. Convert PDF to Images
            if progress_callback: progress_callback(10)
            print("Extracting images from PDF...")
            images = self.pdf_processor.extract_images(pdf_path)
            
            # 2. Analyze and Process Pages
            processed_pages = []
            total_pages = len(images)
            
            for i, image in enumerate(images):
                print(f"Processing page {i+1}/{total_pages}...")
                
                # Step A: Local OCR (Extract Text & Layout)
                text_blocks = self.ocr_service.extract_text(image)
                print(f"  - OCR found {len(text_blocks)} blocks")
                
                # Step B: AI Inpainting (Remove Text) using Nano Banana Pro
                try:
                    default_prompt = "删除所有文字并自然补画背景；对话气泡内填充干净底色；线条连续不模糊；除文字区域外其他元素不变；删除右下角'NotebookLM'水印，保留其他彩色Logo"
                    prompt = os.getenv("NANO_PROMPT", default_prompt)
                    processed_image = self.nano_service.generate_image(image, prompt)
                    print(f"  - Inpainting complete (Nano)")
                except Exception as e:
                    print(f"  ⚠️ INPAINTING FAILED: {e}")
                    print(f"  -> Using original image as fallback.")
                    processed_image = image  # Fallback
                
                processed_pages.append({
                    "image": processed_image,
                    "text_blocks": text_blocks
                })
                
                if progress_callback:
                    # Progress from 10% to 90%
                    progress = 10 + int((i + 1) / total_pages * 80)
                    progress_callback(progress)

            # 3. Generate PPTX
            print("Generating PPTX...")
            self.pptx_generator.generate(processed_pages, output_pptx_path)
            
            if progress_callback: progress_callback(100)
            print("Conversion complete.")
            return True

        except Exception as e:
            print(f"Conversion failed: {e}")
            raise e
