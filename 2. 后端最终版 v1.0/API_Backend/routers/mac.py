"""
Mac App Inpaint Router
为 Mac App 提供 Nano API 代理服务
确保 API Key 安全存储在服务器端
"""
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session
from PIL import Image
from io import BytesIO
import base64
import crud
from database import get_db
from core.nano_service import NanoBananaService
import os
import models
import uuid

router = APIRouter(prefix="/api/v1/mac", tags=["Mac App v1"])

# API 版本说明：
# v1 - 初始版本，2026-01-30
# 保证向后兼容：更新 App 时不会破坏现有接口

# 延迟初始化 Nano 服务（在首次调用时初始化）
_nano_service = None

def get_nano_service():
    global _nano_service
    if _nano_service is None:
        _nano_service = NanoBananaService()
    return _nano_service


@router.post("/inpaint")
async def inpaint_image(
    image: UploadFile = File(..., description="原始图片"),
    mask: UploadFile = File(..., description="Mask 图片（白色区域为需要擦除的部分）"),
    phone_number: str = Form(..., description="用户手机号"),
    db: Session = Depends(get_db)
):
    """
    代理调用 Nano API 进行图片修复
    
    - 验证用户身份
    - 检查用户积分（每次调用消耗 1 积分）
    - 调用 Nano API
    - 返回处理后的图片
    """
    # 1. 验证用户
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # 2. 检查积分（每次修图消耗 1 积分）
    cost = 1
    if user.credits < cost:
        raise HTTPException(status_code=402, detail=f"Insufficient credits. Required: {cost}, Available: {user.credits}")
    
    # 3. 读取上传的图片
    try:
        image_bytes = await image.read()
        pil_image = Image.open(BytesIO(image_bytes))
        
        # mask 暂时不使用（Nano API 使用 prompt 而不是 mask）
        # 如果将来需要，可以传递给更新后的 nano_service
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {str(e)}")
    
    # 4. 调用 Nano API
    try:
        prompt = os.getenv(
            "NANO_PROMPT", 
            "清理图片中的所有文字内容，填补被遮挡的背景。对于右下角的标识文字，也一并清理干净。保持画面整洁，无边框无杂物。"
        )
        result_image = get_nano_service().generate_image(pil_image, prompt)
    except Exception as e:
        import traceback
        print(f"[Nano API Error] {type(e).__name__}: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Inpainting failed: {str(e)}")
    
    # 6. 将结果图片转为 Base64 返回 (使用 JPEG 压缩减少传输大小)
    try:
        buffered = BytesIO()
        # Convert to RGB if necessary (JPEG doesn't support alpha)
        if result_image.mode in ('RGBA', 'LA', 'P'):
            result_image = result_image.convert('RGB')
        result_image.save(buffered, format="JPEG", quality=85)
        img_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
        
        # 5. 扣减积分 (放在响应准备好之后，确保能成功返回)
        crud.deduct_credits(db, user.phone_number, cost, "Mac App 修图")
        
        # 记录转换历史
        try:
            from datetime import datetime
            file_record = models.FileRecord(
                id=str(uuid.uuid4()),
                user_id=user.phone_number,
                filename="Mac App Inpaint",
                file_path="",
                page_count=1,
                status="completed",
                cost=cost,
                created_at=datetime.utcnow()
            )
            db.add(file_record)
            db.commit()
        except Exception as e:
            print(f"Failed to record history: {e}")
        
        # 刷新用户对象获取最新积分
        db.refresh(user)
        
        return {
            "success": True,
            "image_base64": img_base64,
            "credits_used": cost,
            "remaining_credits": user.credits
        }
    except Exception as e:
        print(f"[Response Error] Failed to encode/send response: {e}")
        raise HTTPException(status_code=500, detail=f"响应编码失败: {str(e)}")


@router.get("/credits")
def get_credits(phone_number: str, db: Session = Depends(get_db)):
    """
    查询用户积分余额
    """
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "phone_number": user.phone_number,
        "credits": user.credits
    }


@router.post("/verify-token")
def verify_token(phone_number: str, db: Session = Depends(get_db)):
    """
    验证用户 Token（简化版，实际应使用 JWT）
    """
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "valid": True,
        "phone_number": user.phone_number,
        "credits": user.credits
    }
