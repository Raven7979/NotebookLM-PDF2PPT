import sys
import os

# Add parent dir to sys.path to allow importing app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
import models

def check_user(phone):
    db = SessionLocal()
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if user:
        print(f"User: {user.phone_number}")
        print(f"ID: {user.id}")
        print(f"Is Superuser: {user.is_superuser}")
        print(f"Is Active: {user.is_active}")
        print(f"Credits: {user.credits}")
    else:
        print(f"User {phone} not found.")
    db.close()

if __name__ == "__main__":
    check_user("18616683239")
