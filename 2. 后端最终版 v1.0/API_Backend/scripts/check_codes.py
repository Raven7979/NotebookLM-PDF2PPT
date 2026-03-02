import sys
import os
from datetime import datetime

# Add parent dir to sys.path to allow importing app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
import models

def check_codes(phone):
    db = SessionLocal()
    codes = db.query(models.VerificationCode).filter(
        models.VerificationCode.phone_number == phone
    ).order_by(models.VerificationCode.created_at.desc()).limit(5).all()
    
    print(f"Recent codes for {phone}:")
    for c in codes:
        print(f" - Code: {c.code}, Used: {c.is_used}, Expires: {c.expires_at}, Now: {datetime.utcnow()}")
    db.close()

if __name__ == "__main__":
    check_codes("18616683239")
