import sys
import os
import random
from datetime import datetime, timedelta

# Add current directory to path so we can import app modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal, engine, Base
import models
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def seed():
    db = SessionLocal()
    
    # Create Tables if not exist (just in case)
    Base.metadata.create_all(bind=engine)
    
    # Define Mock Users
    mock_users = [
        {
            "phone_number": "13800138001",
            "credits": 5000,
            "invite_code": "RICH01",
            "password": "password123",
            "files": [
                {"filename": "Company_Report_2023.pdf", "pages": 120, "cost": 1200, "status": "completed"},
                {"filename": "Q1_Financials.pdf", "pages": 45, "cost": 450, "status": "completed"},
                {"filename": "Marketing_Plan.pdf", "pages": 30, "cost": 300, "status": "completed"},
            ],
            "orders": [
                {"amount": 100.0, "credits": 10000, "status": "completed"},
                {"amount": 50.0, "credits": 5000, "status": "completed"},
            ]
        },
        {
            "phone_number": "13912345678",
            "credits": 200,
            "invite_code": "CASUAL",
            "password": "password123",
            "files": [
                {"filename": "Resume.pdf", "pages": 2, "cost": 20, "status": "completed"},
            ],
            "orders": []
        },
        {
            "phone_number": "15000000000",
            "credits": 800,
            "invite_code": "FAIL01",
            "password": "password123",
            "files": [
                {"filename": "Broken_Scan.pdf", "pages": 0, "cost": 0, "status": "failed"},
                {"filename": "Too_Large.pdf", "pages": 500, "cost": 0, "status": "failed"},
            ],
            "orders": [
                 {"amount": 10.0, "credits": 1000, "status": "pending"},
            ]
        },
        {
            "phone_number": "18888888888",
            "credits": 1000,
            "invite_code": "NEWBIE",
            "password": "password123",
            "files": [],
            "orders": []
        }
    ]

    print("Seeding data...")
    
    for u_data in mock_users:
        # Check if user exists
        existing_user = db.query(models.User).filter(models.User.phone_number == u_data["phone_number"]).first()
        if existing_user:
            print(f"User {u_data['phone_number']} already exists, adding records to existing user...")
            user = existing_user
        else:
            user = models.User(
                phone_number=u_data["phone_number"],
                hashed_password=get_password_hash(u_data["password"]),
                credits=u_data["credits"],
                invite_code=u_data["invite_code"],
                is_active=True,
                created_at=datetime.now() - timedelta(days=random.randint(1, 30))
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            print(f"Created user {u_data['phone_number']}")

        # Add Files
        for f_data in u_data["files"]:
            file_record = models.FileRecord(
                user_id=user.phone_number, # Using phone_number as user_id based on schema
                filename=f_data["filename"],
                file_path=f"/tmp/{f_data['filename']}", # Mock path
                page_count=f_data["pages"],
                cost=f_data["cost"],
                status=f_data["status"],
                created_at=datetime.now() - timedelta(hours=random.randint(1, 48))
            )
            db.add(file_record)
        
        # Add Orders
        for o_data in u_data["orders"]:
            order = models.Order(
                user_id=user.phone_number, # Using phone_number as user_id based on schema
                amount=o_data["amount"],
                credits=o_data["credits"],
                status=o_data["status"],
                created_at=datetime.now() - timedelta(days=random.randint(1, 10))
            )
            db.add(order)
            
        db.commit()

    print("Seeding complete!")
    db.close()

if __name__ == "__main__":
    seed()
