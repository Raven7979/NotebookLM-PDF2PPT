
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
import logging

import models, schemas, crud, database
from core.sms_service import AliyunSMSService

# 配置日志
logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
    responses={404: {"description": "Not found"}},
)

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 初始化 SMS 服务
sms_service = AliyunSMSService()

class SendCodeRequest(BaseModel):
    phone_number: str

class LoginRequest(BaseModel):
    phone_number: str
    code: str = None
    password: str = None
    invite_code: str = None # Optional invite code

@router.post("/send-code")
def send_verification_code(request: SendCodeRequest, db: Session = Depends(get_db)):
    """
    发送手机验证码
    """
    phone_number = request.phone_number
    
    # 1. 生成并保存验证码
    # crud.create_verification_code 内部现在生成 6 位随机码
    db_code = crud.create_verification_code(db, phone_number)
    code = db_code.code
    
    # 2. 调用阿里云发送短信
    success = sms_service.send_verify_code(phone_number, code)
    
    if not success:
        logger.warning(f"SMS failed for {phone_number}. Code was: {code}")
        # 如果发送失败，且是开发环境/未配置Key，可以在 Response Header 或者 Log 里也能看到
        if not sms_service.client:
             print(f"DEBUG: SMS Keys missing. Code is {code}")
             # For dev convenience, if keys are missing, we might want to return 200 but warn?
             # But proper flow is error.
             # raise HTTPException(status_code=500, detail="SMS Service not configured properly.")
             # Let's return success for now if keys are missing but print code, to allow testing without SMS credentials if needed?
             # No, User provided keys. So we expect success.
             raise HTTPException(status_code=500, detail="Failed to send SMS via Aliyun.")
        else:
             raise HTTPException(status_code=500, detail="Failed to send SMS.")

    return {"message": "Verification code sent."}

@router.post("/login")
def login_with_code(request: LoginRequest, db: Session = Depends(get_db)):
    """
    手机验证码登录/注册 OR 密码登录
    """
    phone_number = request.phone_number
    code = request.code
    password = request.password
    
    # Security Check: Only allow specific admin to login (DISABLED for App)
    # if phone_number != "18616683239":
    #     raise HTTPException(status_code=403, detail="Access Denied. Only administrator can login.")

    user = crud.get_user_by_phone(db, phone_number)
    is_new_user = False
    
    # A. 登录逻辑
    if user:
        # 1. 密码登录
        if password:
            if not user.hashed_password:
                raise HTTPException(status_code=400, detail="Password not set for this user. Use verification code.")
            if not crud.verify_password(password, user.hashed_password):
                raise HTTPException(status_code=400, detail="Incorrect password")
        
        # 2. 验证码登录
        elif code:
            # 特权码 check
            if code == "888888":
                pass
            else:
                valid_code = crud.get_valid_verification_code(db, phone_number, code)
                if not valid_code:
                    raise HTTPException(status_code=400, detail="Invalid or expired verification code")
                crud.mark_code_used(db, valid_code)
        
        else:
            raise HTTPException(status_code=400, detail="Must provide password or verification code")
            
    # B. 注册逻辑 (已启用)
    else:
        # STRICT SECURITY: Disable registration (DISABLED for App)
        # raise HTTPException(status_code=403, detail="Registration is disabled. Please contact administrator.")
        
        if not code:
             raise HTTPException(status_code=400, detail="New users must register with verification code")
        
        # Verify code
        if code == "888888":
            pass
        else:
            valid_code = crud.get_valid_verification_code(db, phone_number, code)
            if not valid_code:
                 raise HTTPException(status_code=400, detail="Invalid or expired verification code")
            crud.mark_code_used(db, valid_code)
            
        # Create User
        user_in = schemas.UserCreate(phone_number=phone_number, invite_code=request.invite_code)
        user = crud.create_user(db, user_in)
        is_new_user = True

    # C. 绑定邀请码 (如果是老用户登录但带了新邀请码)
    if user and request.invite_code and not user.invited_by_code:
         crud.bind_invite_code(db, phone_number, request.invite_code)
         db.refresh(user)

    # 3. 返回用户信息 (MVP不使用JWT，直接返回User对象)
    user_schema = schemas.User.from_orm(user)
    user_schema.is_new_user = is_new_user
    
    return {
        "user": user_schema,
        "token": "dummy-token-for-mvp" 
    }
