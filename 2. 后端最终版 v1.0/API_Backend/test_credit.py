import sqlite3

db = sqlite3.connect('sql_app.db')
cursor = db.cursor()

# Set all users' credits to 0
cursor.execute("UPDATE users SET credits = 0")
db.commit()

# Print users
cursor.execute("SELECT id, phone_number, credits FROM users")
print("Users:", cursor.fetchall())

db.close()
