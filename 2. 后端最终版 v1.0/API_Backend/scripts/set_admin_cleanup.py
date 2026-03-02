import sys
import os

# Add parent dir to sys.path to allow importing app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
import models

def set_admin_and_cleanup(admin_phone):
    db = SessionLocal()
    try:
        # 1. Get the target admin user
        admin_user = db.query(models.User).filter(models.User.phone_number == admin_phone).first()
        if not admin_user:
            print(f"Error: User {admin_phone} not found!")
            return

        print(f"Found user {admin_phone}. Promoting to admin...")
        admin_user.is_superuser = True
        
        # 2. Delete all other users
        # We need to be careful about foreign key constraints (e.g., FileRecord, Transaction, etc.)
        # Ideally, we should delete related data too, or just delete users and let cascade handle it if configured (or fail if not).
        # Let's try deleting users and see.
        
        users_to_delete = db.query(models.User).filter(models.User.phone_number != admin_phone).all()
        count = len(users_to_delete)
        print(f"Found {count} other users to delete.")
        
        for u in users_to_delete:
            print(f"Deleting user {u.phone_number}...")
            # Manually delete related records if no cascade (assuming constraints might exist)
            # For MVP, let's just try deleting the user.
            db.delete(u)
            
        db.commit()
        print(f"Successfully set {admin_phone} as admin and deleted {count} other users.")
        
    except Exception as e:
        db.rollback()
        print(f"An error occurred: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    set_admin_and_cleanup("18616683239")
