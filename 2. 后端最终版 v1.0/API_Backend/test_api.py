import requests
import json

base_url = 'http://localhost:8000'

# List users to find a phone number
users = requests.get(f'{base_url}/api/admin/users').json()
if not users:
    print("No users found.")
    exit(1)

phone_number = users[0]['phone_number']
print(f"Testing with user {phone_number} (Credits: {users[0]['credits']})")

import requests
import sqlite3
import uuid

base_url = 'http://localhost:8000'

# List users to find a phone number
users = requests.get(f'{base_url}/api/admin/users').json()
phone_number = users[0]['phone_number']

# Create a file record for this user directly via sqlite
db = sqlite3.connect('sql_app.db')
cursor = db.cursor()
file_id = str(uuid.uuid4())
cursor.execute("INSERT INTO file_records (id, user_id, filename, file_path, page_count, status, cost, created_at) VALUES (?, ?, 'dummy.pdf', '/tmp/dummy.pdf', 10, 'uploaded', 10, datetime('now'))", (file_id, phone_number))
db.commit()
db.close()

# Now try to convert
res = requests.post(f'{base_url}/api/convert', json={"phone_number": phone_number, "file_id": file_id})
print(f"Web Convert API Response: {res.status_code}, {res.json()}")
