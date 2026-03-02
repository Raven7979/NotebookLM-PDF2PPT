from sqlalchemy import Boolean, Column, Integer, String, DateTime, Float
from sqlalchemy.sql import func
from database import Base
import uuid

def generate_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True)
    credits = Column(Integer, default=5)  # New users get 5 credits
    invite_code = Column(String, unique=True, index=True)
    invited_by_code = Column(String, index=True, nullable=True)
    is_invite_rewarded = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

class FileRecord(Base):
    __tablename__ = "file_records"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, index=True, nullable=False) # Store phone number or user ID
    filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    page_count = Column(Integer, default=0)
    cost = Column(Integer, default=0)
    status = Column(String, default="uploaded") # uploaded, processing, completed, failed
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, index=True)
    code = Column(String)
    expires_at = Column(DateTime(timezone=True))
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Order(Base):
    __tablename__ = "orders"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, index=True, nullable=False)
    amount = Column(Float, nullable=False)
    credits = Column(Integer, nullable=False)
    status = Column(String, default="pending") # pending, completed, failed
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class CreditCode(Base):
    __tablename__ = "credit_codes"

    code = Column(String, primary_key=True, index=True)
    points = Column(Integer, nullable=False) # 15, 45, 150
    status = Column(String, default="unused") # unused, used
    used_by = Column(String, index=True, nullable=True) # User phone/id
    used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, index=True, nullable=False)
    type = Column(String, nullable=False) # redemption, conversion, gift, refund
    amount = Column(Integer, nullable=False) # +15, -1
    description = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class AppVersion(Base):
    __tablename__ = "app_versions"

    id = Column(Integer, primary_key=True, index=True)
    version = Column(String, index=True) # e.g. "1.0" - removed unique so same version can have multiple builds
    build = Column(Integer) # e.g. 28
    download_url = Column(String)
    local_file_path = Column(String)
    release_notes = Column(String)
    force_update = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
