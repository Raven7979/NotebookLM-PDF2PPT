from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import schemas, crud, database

router = APIRouter(
    prefix="/api/codes",
    tags=["codes"],
    responses={404: {"description": "Not found"}},
)

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/redeem", response_model=schemas.RedemptionResponse)
def redeem_code(request: schemas.CreditCodeRedeem, db: Session = Depends(get_db)):
    """
    Redeem a credit code for points.
    """
    user = crud.get_user_by_phone(db, request.phone_number)
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
        
    code, message = crud.redeem_credit_code(db, request.code, user)
    
    if not code:
        # Determine status code based on message
        if message == "Invalid code":
            raise HTTPException(status_code=404, detail="无效的兑换码")
        elif message == "Code already used":
            raise HTTPException(status_code=400, detail="兑换码已被使用")
        else:
            raise HTTPException(status_code=400, detail=message)
            
    return {"code": code, "message": message}
