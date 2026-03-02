import requests
import sqlite3
import os

base_url = 'http://localhost:8000'
phone_number = "18616683239"

# Create a dummy PDF file
with open("test.pdf", "wb") as f:
    f.write(b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n188\n%%EOF")

# 1. Upload file
with open("test.pdf", "rb") as f:
    files = {"file": f}
    data = {"phone_number": phone_number}
    res = requests.post(f"{base_url}/api/upload", files=files, data=data)

print(f"Upload Response: {res.status_code}, {res.json()}")

if res.status_code == 200:
    file_id = res.json()["file_id"]
    # 2. Convert file
    res2 = requests.post(f"{base_url}/api/convert", json={"phone_number": phone_number, "file_id": file_id})
    print(f"Convert Response: {res2.status_code}, {res2.json()}")
