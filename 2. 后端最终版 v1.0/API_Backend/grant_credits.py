import sqlite3
import sys

def grant_credits(credits=1000):
    try:
        conn = sqlite3.connect('sql_app.db')
        cursor = conn.cursor()
        
        # Get all users
        cursor.execute("SELECT phone_number, credits FROM users")
        users = cursor.fetchall()
        
        if not users:
            print("No users found.")
            return

        print(f"Found {len(users)} users. Granting {credits} credits to all.")
        
        cursor.execute("UPDATE users SET credits = ?", (credits,))
        conn.commit()
        
        print("Success!")
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    grant_credits()
