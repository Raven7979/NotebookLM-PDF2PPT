import os
from typing import List
from PIL import Image
from pdf2image import convert_from_path

class PDFProcessor:
    def __init__(self):
        pass

    def extract_images(self, pdf_path: str, dpi: int = 300) -> List[Image.Image]:
        """
        Convert PDF pages to images.
        """
        try:
            # convert_from_path requires poppler installed
            images = convert_from_path(pdf_path, dpi=dpi)
            return images
        except Exception as e:
            print(f"Error converting PDF to images: {e}")
            # Fallback or re-raise
            raise Exception("Failed to convert PDF. Ensure poppler is installed.")
