from sqlalchemy.orm import Session
import database
import models
import crud

def reset_all_passwords(db: Session, new_password: str):
    users = db.query(models.User).all()
    hashed_password = crud.get_password_hash(new_password)
    count = 0
    for user in users:
        user.hashed_password = hashed_password
        count += 1
    db.commit()
    print(f"Successfully reset passwords for {count} users to '{new_password}'.")

if __name__ == "__main__":
    db = database.SessionLocal()
    try:
        reset_all_passwords(db, "123456")
    finally:
        db.close()
