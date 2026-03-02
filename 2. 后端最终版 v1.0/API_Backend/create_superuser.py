from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
import crud
import sys

def create_superuser(phone_number: str):
    db = SessionLocal()
    try:
        user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
        hashed_password = crud.get_password_hash("123456")
        
        if not user:
            print(f"User with phone number {phone_number} not found.")
            print("Creating new superuser...")
            user = models.User(
                phone_number=phone_number, 
                is_superuser=True,
                hashed_password=hashed_password
            )
            db.add(user)
        else:
            print(f"Found user {phone_number}. Promoting to superuser and resetting password.")
            user.is_superuser = True
            user.hashed_password = hashed_password
        
        db.commit()
        print(f"User {phone_number} is now a superuser. Password set to: 123456")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python create_superuser.py <phone_number>")
        sys.exit(1)
    
    create_superuser(sys.argv[1])
