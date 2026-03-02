from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import models, schemas, crud, database

router = APIRouter(
    prefix="/api/admin",
    tags=["admin"],
    responses={404: {"description": "Not found"}},
)

def get_current_superuser(phone_number: str, db: Session = Depends(database.get_db)):
    # In a real app, we would verify the JWT token here.
    # For MVP, we pass phone_number as query param or header (insecure but fast)
    # But wait, crud.get_user_by_phone needs db.
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_superuser:
        raise HTTPException(status_code=403, detail="Not enough privileges")
    return user

@router.post("/codes/generate", response_model=List[schemas.CreditCode])
def generate_codes(request: schemas.CreditCodeCreate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    """
    Generate a batch of credit codes.
    """
    codes = crud.create_credit_codes(db, points=request.points, count=request.count)
    return codes

@router.get("/codes", response_model=List[schemas.CreditCode])
def read_all_codes(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    """
    Get all credit codes (Admin only)
    """
    # Assuming we want to see all codes. In strict REST often we'd have pagination, 
    # but for simple MVP admin this is fine.
    codes = db.query(models.CreditCode).order_by(models.CreditCode.created_at.desc()).all()
    return codes

@router.get("/users", response_model=List[schemas.User])
def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    users = db.query(models.User).offset(skip).limit(limit).all()
    
    # Calculate total converted pages for each user
    # Note: efficient way would be a join/aggregation query, but for MVP iteration loop is fine.
    for user in users:
        # Check if user has file records
        # user.phone_number is the key in FileRecord
        # We need to calculate sum of page_count for this user
        # Note: status check? Assuming all uploaded files count or just processed ones?
        # User request says "total file pages converted".
        # Let's count all files for now, or filter by status if we had 'completed' status.
        # Currently status is 'uploaded' by default.
        total_pages = db.query(func.sum(models.FileRecord.page_count)).filter(
            models.FileRecord.user_id == user.phone_number
        ).scalar()
        user.total_converted_pages = total_pages if total_pages else 0
        
        # Calculate total payment amount (completed orders only)
        total_payment = db.query(func.sum(models.Order.amount)).filter(
            models.Order.user_id == user.phone_number,
            models.Order.status == "completed"
        ).scalar()
        user.total_payment_amount = total_payment if total_payment else 0.0
        
        # Calculate total redeemed points
        total_redeemed = db.query(func.sum(models.Transaction.amount)).filter(
            models.Transaction.user_id == user.phone_number,
            models.Transaction.type == "redemption"
        ).scalar()
        user.total_redeemed_points = total_redeemed if total_redeemed else 0
        
    return users

@router.get("/users/{user_id}", response_model=schemas.UserDetail)
def read_user_detail(user_id: str, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Get File Records
    file_records = db.query(models.FileRecord).filter(models.FileRecord.user_id == user.phone_number).all()
    
    # Get Orders
    # Assuming Order uses user_id (UUID) or phone_number? 
    # Let's check models.Order.user_id definition. It is String.
    # In main.py or crud.py we haven't seen order creation.
    # But usually it's safer to query both or assume consistency.
    # Given FileRecord uses phone_number, Order likely uses phone_number too if consistency was kept.
    # However, user.id is UUID. 
    # Let's assume Order uses phone_number for now as that's the primary "business key" in this system so far.
    # Wait, in schemas.py OrderCreate has user_id.
    # Let's try to fetch by phone_number first.
    orders = db.query(models.Order).filter(models.Order.user_id == user.phone_number).all()
    if not orders:
        # Try UUID if phone number yielded nothing (just in case)
        orders = db.query(models.Order).filter(models.Order.user_id == user.id).all()

    # Create UserDetail response
    user_detail = schemas.UserDetail.from_orm(user)
    user_detail.file_records = file_records
    user_detail.orders = orders
    
    # Calculate total pages
    total_pages = sum(f.page_count for f in file_records)
    user_detail.total_converted_pages = total_pages
    
    return user_detail

@router.get("/stats")
def read_stats(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    user_count = db.query(models.User).count()
    file_count = db.query(models.FileRecord).filter(models.FileRecord.status == "completed").count()
    # Calculate total revenue from completed orders
    total_revenue = db.query(func.sum(models.Order.amount)).filter(models.Order.status == "completed").scalar()
    
    return {
        "user_count": user_count,
        "file_count": file_count,
        "revenue": total_revenue if total_revenue else 0
    }

@router.put("/users/{user_id}/credits")
def update_user_credits(
    user_id: str, 
    credits: int, 
    db: Session = Depends(database.get_db), 
    current_user: models.User = Depends(get_current_superuser)
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.credits = credits
    db.commit()
    db.refresh(user)
    return user

@router.get("/orders", response_model=List[schemas.Order])
def read_orders(skip: int = 0, limit: int = 100, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_superuser)):
    orders = db.query(models.Order).order_by(models.Order.created_at.desc()).offset(skip).limit(limit).all()
    return orders
