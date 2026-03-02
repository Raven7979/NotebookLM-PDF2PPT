from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import models, schemas, crud, database

router = APIRouter(
    prefix="/api/users",
    tags=["users"],
    responses={404: {"description": "Not found"}},
)

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/history", response_model=List[schemas.Transaction])
def read_history(phone_number: str, db: Session = Depends(get_db)):
    """
    Get all transactions for the current user.
    """
    # In production, get user from token. For MVP, query param.
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    transactions = crud.get_user_transactions(db, user.phone_number)
    return transactions

@router.get("/files", response_model=List[schemas.FileRecord])
def read_user_files(phone_number: str, db: Session = Depends(get_db)):
    """
    Get all file records for the current user.
    """
    user = crud.get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    files = crud.get_user_files(db, user.phone_number)
    return files

@router.get("/me", response_model=schemas.User)
def read_users_me(phone_number: str, db: Session = Depends(get_db)):
    """
    Get current user info by phone number.
    Note: In production, use Bearer token instead of query param.
    """
    user = crud.get_user_by_phone(db, phone_number)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@router.post("/bind-invite")
def bind_invite_code(request: schemas.InviteBindRequest, db: Session = Depends(get_db)):
    """
    Bind an invite code to the current user and trigger rewards.
    """
    success, message = crud.bind_invite_code(db, request.phone_number, request.invite_code)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    
    # Refresh user to get updated credits
    user = crud.get_user_by_phone(db, request.phone_number)
    return {"message": message, "credits": user.credits if user else 0}
