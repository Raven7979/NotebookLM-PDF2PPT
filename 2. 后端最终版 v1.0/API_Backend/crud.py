from sqlalchemy.orm import Session
import models, schemas
import uuid
import random
import string
from datetime import datetime, timedelta
import bcrypt

def verify_password(plain_password, hashed_password):
    if not hashed_password:
        return False
    # hashed_password from DB is string, needs to be bytes
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password):
    # returns string
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def get_user_by_phone(db: Session, phone_number: str):
    return db.query(models.User).filter(models.User.phone_number == phone_number).first()

def get_user_by_invite_code(db: Session, invite_code: str):
    return db.query(models.User).filter(models.User.invite_code == invite_code).first()

def generate_invite_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

def create_user(db: Session, user: schemas.UserCreate):
    # Generate unique invite code
    while True:
        code = generate_invite_code()
        if not get_user_by_invite_code(db, code):
            break
            
    hashed_password = get_password_hash(user.password) if user.password else None
    
    db_user = models.User(
        phone_number=user.phone_number,
        invite_code=code,
        invited_by_code=user.invite_code, # store who invited this user
        credits=5, # Default 5 credits for new user
        hashed_password=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def create_verification_code(db: Session, phone_number: str):
    # Generate 6 digit code
    code = ''.join(random.choices(string.digits, k=6))
    # Expires in 5 minutes
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    
    db_code = models.VerificationCode(
        phone_number=phone_number,
        code=code,
        expires_at=expires_at
    )
    db.add(db_code)
    db.commit()
    db.refresh(db_code)
    return db_code

def get_valid_verification_code(db: Session, phone_number: str, code: str):
    return db.query(models.VerificationCode).filter(
        models.VerificationCode.phone_number == phone_number,
        models.VerificationCode.code == code,
        models.VerificationCode.is_used == False,
        models.VerificationCode.expires_at > datetime.utcnow()
    ).first()

def mark_code_used(db: Session, db_code: models.VerificationCode):
    db_code.is_used = True
    db.commit()

# File Record CRUD
def create_file_record(db: Session, file_record: schemas.FileRecordCreate):
    db_file = models.FileRecord(
        user_id=file_record.user_id,
        filename=file_record.filename,
        file_path=file_record.file_path,
        page_count=file_record.page_count,
        cost=file_record.cost,
        status=file_record.status
    )
    db.add(db_file)
    db.commit()
    db.refresh(db_file)
    return db_file

def get_file_record(db: Session, file_id: str):
    return db.query(models.FileRecord).filter(models.FileRecord.id == file_id).first()

def get_user_files(db: Session, user_id: str):
    return db.query(models.FileRecord).filter(models.FileRecord.user_id == user_id).order_by(models.FileRecord.created_at.desc()).all()

# Credit Code CRUD
def generate_unique_code():
    # 16 char random string
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=16))

def create_credit_codes(db: Session, points: int, count: int):
    codes = []
    for _ in range(count):
        while True:
            code_str = generate_unique_code()
            # specific check to ensure uniqueness
            if not db.query(models.CreditCode).filter(models.CreditCode.code == code_str).first():
                break
        
        db_code = models.CreditCode(
            code=code_str,
            points=points,
            status="unused"
        )
        db.add(db_code)
        codes.append(db_code)
    db.commit()
    # Refresh all to get created_at (optional, can skip for bulk)
    return codes

def get_credit_code(db: Session, code: str):
    return db.query(models.CreditCode).filter(models.CreditCode.code == code).first()

def redeem_credit_code(db: Session, code: str, user: models.User):
    db_code = get_credit_code(db, code)
    if not db_code:
        return None, "Invalid code"
    if db_code.status == "used":
        return None, "Code already used"
    
    # Mark as used
    db_code.status = "used"
    db_code.used_by = user.phone_number
    db_code.used_at = datetime.utcnow()
    
    # Add credits to user
    user.credits += db_code.points
    
    # Record Transaction
    transaction = models.Transaction(
        user_id=user.phone_number,
        type="redemption",
        amount=db_code.points,
        description=f"兑换 {db_code.points} 积分码" # Chinese description
    )
    db.add(transaction)
    
    # Invitation Reward Logic (V2)
    # Trigger: First successful redemption (implied by is_invite_rewarded=False check if we only reward once)
    # Condition: User has inviter AND hasn't been rewarded yet
    
    reward_message = "Success"
    
    if not user.is_invite_rewarded:
        if user.invited_by_code:
            inviter = get_user_by_invite_code(db, user.invited_by_code)
            if inviter:
                # Reward 15 points to both
                REWARD_POINTS = 15
                
                # 1. Reward Inviter
                inviter.credits += REWARD_POINTS
                inviter_tx = models.Transaction(
                    user_id=inviter.phone_number,
                    type="invitation_reward",
                    amount=REWARD_POINTS,
                    description=f"邀请用户 {user.phone_number} 兑换奖励"
                )
                db.add(inviter_tx)
                
                # 2. Reward Invitee (Current User)
                user.credits += REWARD_POINTS
                invitee_tx = models.Transaction(
                    user_id=user.phone_number,
                    type="invitation_reward",
                    amount=REWARD_POINTS,
                    description=f"邀请码 {user.invited_by_code} 绑定奖励"
                )
                db.add(invitee_tx)
                
                user.is_invite_rewarded = True
                reward_message = "Success (Reward Applied)"
        else:
            # User hasn't been rewarded and has no inviter -> Prompt them
            reward_message = "success_no_invite"

    db.commit()
    db.refresh(user)
    return db_code, reward_message

def bind_invite_code(db: Session, phone_number: str, invite_code: str):
    user = get_user_by_phone(db, phone_number)
    if not user:
        return False, "User not found"
        
    if user.invited_by_code:
        return False, "Already bound"
        
    inviter = get_user_by_invite_code(db, invite_code)
    if not inviter:
        return False, "Invalid invite code"
        
    if inviter.phone_number == user.phone_number:
        return False, "Cannot invite self"
        
    # Bind code
    user.invited_by_code = invite_code
    
    # Check if eligible for immediate reward (if they have already redeemed codes)
    # We check if they have any 'redemption' transactions
    has_redeemed = db.query(models.Transaction).filter(
        models.Transaction.user_id == user.phone_number,
        models.Transaction.type == 'redemption'
    ).first()
    
    msg = "Bound successfully"
    
    if has_redeemed and not user.is_invite_rewarded:
        # Trigger Reward Immediately
        REWARD_POINTS = 15
        
        # 1. Reward Inviter
        inviter.credits += REWARD_POINTS
        inviter_tx = models.Transaction(
            user_id=inviter.phone_number,
            type="invitation_reward",
            amount=REWARD_POINTS,
            description=f"邀请用户 {user.phone_number} 兑换奖励"
        )
        db.add(inviter_tx)
        
        # 2. Reward Invitee
        user.credits += REWARD_POINTS
        invitee_tx = models.Transaction(
            user_id=user.phone_number,
            type="invitation_reward",
            amount=REWARD_POINTS,
            description=f"邀请码 {invite_code} 绑定奖励"
        )
        db.add(invitee_tx)
        
        user.is_invite_rewarded = True
        msg = "Bound and rewarded"
        
    db.commit()
    return True, msg

# Transaction CRUD
def create_transaction(db: Session, user_id: str, type: str, amount: int, description: str):
    transaction = models.Transaction(
        user_id=user_id,
        type=type,
        amount=amount,
        description=description
    )
    db.add(transaction)
    db.commit()
    return transaction

def get_user_transactions(db: Session, user_id: str):
    return db.query(models.Transaction).filter(models.Transaction.user_id == user_id).order_by(models.Transaction.created_at.desc()).all()


def deduct_credits(db: Session, phone_number: str, amount: int, description: str = "消费"):
    """
    扣减用户积分
    
    Args:
        db: 数据库会话
        phone_number: 用户手机号
        amount: 扣减积分数量
        description: 消费描述
    
    Returns:
        bool: 是否成功
    """
    user = get_user_by_phone(db, phone_number)
    if not user or user.credits < amount:
        return False
    
    # 扣减积分
    user.credits -= amount
    
    # 记录交易
    transaction = models.Transaction(
        user_id=phone_number,
        type="consumption",
        amount=-amount,  # 负数表示消费
        description=description
    )
    db.add(transaction)
    db.commit()
    db.refresh(user)
    return True

def get_user_by_id(db: Session, user_id: str):
    return db.query(models.User).filter(models.User.id == user_id).first()

def add_credits(db: Session, phone_number: str, amount: int, description: str = "充值"):
    """
    增加用户积分
    """
    user = get_user_by_phone(db, phone_number)
    if not user:
        return False
    
    user.credits += amount
    
    transaction = models.Transaction(
        user_id=phone_number,
        type="deposit",
        amount=amount,
        description=description
    )
    db.add(transaction)
    db.commit()
    db.refresh(user)
    return True


# App Version CRUD

def _version_sort_key(version: str, build: int):
    parts = [int(p) if p.isdigit() else 0 for p in version.split(".")]
    normalized = (parts + [0, 0, 0, 0])[:4]
    return (*normalized, build)


def get_latest_app_version(db: Session):
    versions = db.query(models.AppVersion).all()
    if not versions:
        return None
    return max(versions, key=lambda v: _version_sort_key(v.version or "0", v.build or 0))

def get_app_versions(db: Session, skip: int = 0, limit: int = 100):
    versions = db.query(models.AppVersion).all()
    versions.sort(key=lambda v: _version_sort_key(v.version or "0", v.build or 0), reverse=True)
    return versions[skip:skip + limit]

def create_app_version(db: Session, version: schemas.AppVersionCreate, download_url: str, local_file_path: str):
    db_version = models.AppVersion(
        version=version.version,
        build=version.build,
        download_url=download_url,
        local_file_path=local_file_path,
        release_notes=version.release_notes,
        force_update=version.force_update
    )
    db.add(db_version)
    db.commit()
    db.refresh(db_version)
    return db_version

def delete_app_version(db: Session, version_id: int):
    db_version = db.query(models.AppVersion).filter(models.AppVersion.id == version_id).first()
    if db_version:
        db.delete(db_version)
        db.commit()
        return True
    return False
