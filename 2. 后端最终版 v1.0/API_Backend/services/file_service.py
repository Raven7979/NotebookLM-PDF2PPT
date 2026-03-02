import os
from sqlalchemy.orm import Session
import models
import shutil
from datetime import datetime
import aiofiles
from PyPDF2 import PdfReader
from fastapi import UploadFile, HTTPException
from typing import Tuple

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

class FileService:
    @staticmethod
    async def save_upload_file(file: UploadFile) -> str:
        if not file.filename.lower().endswith('.pdf'):
            raise HTTPException(status_code=400, detail="Only PDF files are allowed")
        
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        
        # Save file
        async with aiofiles.open(file_path, 'wb') as out_file:
            content = await file.read()
            await out_file.write(content)
            
        return file_path

    @staticmethod
    def get_pdf_page_count(file_path: str) -> int:
        try:
            reader = PdfReader(file_path)
            return len(reader.pages)
        except Exception as e:
            # If PDF is invalid, remove it
            if os.path.exists(file_path):
                os.remove(file_path)
            raise HTTPException(status_code=400, detail=f"Invalid PDF file: {str(e)}")

    @staticmethod
    def calculate_cost(page_count: int) -> int:
        # Cost rules:
        # 1 page = 1 credit
        return page_count
