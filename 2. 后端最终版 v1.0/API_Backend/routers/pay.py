import hashlib
import time
import httpx
import os
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List, Dict
import models, schemas, crud, database
import uuid

router = APIRouter(
    prefix="/api/pay",
    tags=["payment"],
    responses={404: {"description": "Not found"}},
)

# Load configuration from environment
HUPIJIAO_APPID = os.getenv("HUPIJIAO_APPID", "201906177160")
HUPIJIAO_APPSECRET = os.getenv("HUPIJIAO_APPSECRET", "")
API_BASE_URL = os.getenv("API_BASE_URL", "https://ehotapp.xyz")

PRICE_BY_CREDITS = {
    15: 4.9,
    45: 14.9,
    150: 49.0,
}

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

def generate_hupijiao_hash(params: Dict[str, str], appsecret: str) -> str:
    """
    Generate signature for Hupijiao payment.
    """
    # 1. Sort by key
    sorted_keys = sorted(params.keys())
    # 2. Build query string
    query_string = "&".join([f"{k}={params[k]}" for k in sorted_keys if params[k]])
    # 3. Add appsecret and md5
    sign_str = query_string + appsecret
    return hashlib.md5(sign_str.encode('utf-8')).hexdigest()

@router.post("/create-order", response_model=schemas.HupijiaoOrderResponse)
async def create_hupijiao_order(order_in: schemas.OrderCreate, db: Session = Depends(get_db)):
    """
    Create a payment order and redirect to Hupijiao.
    """
    # 1. Verify user exists
    user = crud.get_user_by_id(db, order_in.user_id)
    if not user:
        user = crud.get_user_by_phone(db, order_in.user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        order_in.user_id = user.phone_number

    if order_in.credits not in PRICE_BY_CREDITS:
        raise HTTPException(status_code=400, detail="Unsupported recharge plan")
    effective_amount = PRICE_BY_CREDITS[order_in.credits]

    order_id = str(uuid.uuid4()).replace("-", "")[:24] # Hupijiao has length limit
    db_order = models.Order(
        id=order_id,
        user_id=order_in.user_id,
        amount=effective_amount,
        credits=order_in.credits,
        status="pending"
    )
    db.add(db_order)
    db.commit()
    db.refresh(db_order)

    params = {
        "version": "1.1",
        "appid": HUPIJIAO_APPID,
        "trade_order_id": order_id,
        "total_fee": str(effective_amount),
        "title": f"充值{order_in.credits}积分",
        "time": str(int(time.time())),
        "notify_url": f"{API_BASE_URL}/api/pay/notify",
        "return_url": f"{API_BASE_URL}/payment/success", # Frontend success page
        "nonce_str": str(uuid.uuid4()).replace("-", "")[:32]
    }
    
    params["hash"] = generate_hupijiao_hash(params, HUPIJIAO_APPSECRET)

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post("https://api.xunhupay.com/payment/do.html", data=params)
            result = response.json()
            if result.get("openid") or result.get("url"): # Success returns openid (for JSAPI) or url
                return {
                    "order_id": order_id,
                    "payment_url": result.get("url"),
                    "hupijiao_data": result
                }
            else:
                raise HTTPException(status_code=400, detail=result.get("errmsg", "Payment gateway error"))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Request to payment gateway failed: {str(e)}")

@router.post("/notify")
async def hupijiao_notify(request: Request, db: Session = Depends(get_db)):
    """
    Handle Hupijiao payment status notification.
    """
    data = await request.form()
    # Convert form data to dict for hash verification
    params = dict(data)
    received_hash = params.pop("hash", "")
    
    # 1. Verify hash
    expected_hash = generate_hupijiao_hash(params, HUPIJIAO_APPSECRET)
    
    with open("payment_debug.log", "a") as f:
        f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] NOTIFY: params={params}, received_hash={received_hash}, expected={expected_hash}\n")

    if received_hash != expected_hash:
        return "fail" # Hupijiao expects 'success' or 'fail'
        
    # 2. Check status
    if params.get("status") == "OD": # OD means ordered/paid in Hupijiao
        order_id = params.get("trade_order_id")
        order = db.query(models.Order).filter(models.Order.id == order_id).first()
        
        if order and order.status != "completed":
            order.status = "completed"
            user = crud.get_user_by_phone(db, order.user_id)
            if not user:
                user = crud.get_user_by_id(db, order.user_id)
            
            if user:
                crud.add_credits(db, user.phone_number, order.credits, f"Order {order.id}")
            
            db.commit()
            
    return "success"

@router.get("/status/{order_id}")
async def check_order_status(order_id: str, db: Session = Depends(get_db)):
    """
    Check if a Hupijiao order has been completed.
    This endpoint checks the local DB first, then queries Hupijiao API for real-time status.
    """
    order = db.query(models.Order).filter(models.Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    
    # If already completed in local DB, return immediately
    if order.status == "completed":
        return {"status": "completed"}
        
    # If still pending, try querying Hupijiao API actively
    params = {
        "appid": HUPIJIAO_APPID,
        "trade_order_id": order_id,
        "time": str(int(time.time())),
        "nonce_str": str(uuid.uuid4()).replace("-", "")[:32]
    }
    params["hash"] = generate_hupijiao_hash(params, HUPIJIAO_APPSECRET)
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post("https://api.xunhupay.com/payment/query.html", data=params)
            result = response.json()
            
            with open("payment_debug.log", "a") as f:
                f.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] QUERY: order_id={order_id}, result={result}\n")

            # data.status ：OD(支付成功)，WP(待支付),CD(已取消)
            if result.get("errcode") == 0 and result.get("data", {}).get("status") == "OD":
                # Manual sync: update order and credits since Hupijiao confirms it's paid
                order.status = "completed"
                user = crud.get_user_by_phone(db, order.user_id)
                if not user:
                    user = crud.get_user_by_id(db, order.user_id)
                
                if user:
                    crud.add_credits(db, user.phone_number, order.credits, f"Order {order.id} (Queried)")
                
                db.commit()
                return {"status": "completed"}
                
        except Exception as e:
            # If query fails, just return current local status (don't error out)
            print(f"Hupijiao query failed: {str(e)}")
            
    return {"status": order.status}
