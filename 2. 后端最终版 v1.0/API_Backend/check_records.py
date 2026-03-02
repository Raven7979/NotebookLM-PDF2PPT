
from database import SessionLocal
import models
from sqlalchemy import func

db = SessionLocal()
try:
    print("--- 检查所有 FileRecord ---")
    records = db.query(models.FileRecord).all()
    print(f"Total FileRecords: {len(records)}")
    for r in records:
        print(f"ID: {r.id}, User: {r.user_id}, Pages: {r.page_count}, Status: {r.status}, Type: {r.convert_type}, Created: {r.created_at}")
    
    print("\n--- 检查用户总页数统计 ---")
    users = db.query(models.User).all()
    for user in users:
        total = db.query(func.sum(models.FileRecord.page_count)).filter(
            models.FileRecord.user_id == user.phone_number
        ).scalar()
        print(f"User: {user.phone_number}, Total Pages (Calc): {total}")

finally:
    db.close()
