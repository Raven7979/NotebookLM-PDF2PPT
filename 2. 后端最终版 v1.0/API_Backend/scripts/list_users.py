import sys
import os

# Add parent dir to sys.path to allow importing app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
import models

def list_users():
    db = SessionLocal()
    users = db.query(models.User).all()
    print(f"Found {len(users)} users:")
    for u in users:
        print(f" - Phone: {u.phone_number}, Credits: {u.credits}, Admin: {u.is_superuser}, Created: {u.created_at}")
    db.close()

if __name__ == "__main__":
    list_users()
