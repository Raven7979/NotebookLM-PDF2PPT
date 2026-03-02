from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    phone_number: str

class UserCreate(UserBase):
    verification_code: Optional[str] = None
    password: Optional[str] = None
    invite_code: Optional[str] = None

class UserLogin(BaseModel):
    phone_number: str
    verification_code: Optional[str] = None
    password: Optional[str] = None
    invite_code: Optional[str] = None

class InviteBindRequest(BaseModel):
    phone_number: str
    invite_code: str

class User(UserBase):
    id: str
    credits: int
    invite_code: Optional[str] = None
    invited_by_code: Optional[str] = None
    is_active: bool
    is_superuser: bool = False
    created_at: datetime
    
    # Computed fields (optional, populated manually)
    is_new_user: Optional[bool] = False
    total_converted_pages: Optional[int] = 0
    total_payment_amount: Optional[float] = 0.0
    total_redeemed_points: Optional[int] = 0

    class Config:
        from_attributes = True

class UserDetail(User):
    file_records: List['FileRecord'] = []
    orders: List['Order'] = []

class VerificationCodeRequest(BaseModel):
    phone_number: str

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    phone_number: Optional[str] = None

# File Schemas
class FileRecordBase(BaseModel):
    filename: str
    page_count: int
    cost: int

class FileRecordCreate(FileRecordBase):
    file_path: str
    user_id: str
    status: str = "uploaded"

class FileRecord(FileRecordBase):
    id: str
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class ConvertRequest(BaseModel):
    file_id: str
    phone_number: str

class OrderBase(BaseModel):
    amount: float
    credits: int
    status: str

class OrderCreate(OrderBase):
    user_id: str

class Order(OrderBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True

# Credit Code Schemas
class CreditCodeBase(BaseModel):
    points: int
    status: str

class CreditCodeCreate(BaseModel):
    points: int
    count: int

class CreditCodeRedeem(BaseModel):
    code: str
    phone_number: str # In production, get user from token

class CreditCode(CreditCodeBase):
    code: str
    status: str
    created_at: datetime
    used_at: Optional[datetime] = None
    used_by: Optional[str] = None

    class Config:
        from_attributes = True

class RedemptionResponse(BaseModel):
    code: CreditCode
    message: str

# Transaction Schemas
class TransactionBase(BaseModel):
    type: str
    amount: int
    description: Optional[str] = None

class Transaction(TransactionBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True

class AppVersionBase(BaseModel):
    version: str
    build: int
    release_notes: Optional[str] = None
    force_update: Optional[bool] = False

class AppVersionCreate(AppVersionBase):
    pass

class AppVersion(AppVersionBase):
    id: int
    download_url: str
    local_file_path: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class HupijiaoOrderResponse(BaseModel):
    order_id: str
    payment_url: str
    hupijiao_data: dict
