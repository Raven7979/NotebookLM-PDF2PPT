import requests

url = "https://ehotapp.xyz/api/pay/create-order"
payload = {
  "amount": 0.01,
  "credits": 15,
  "status": "pending",
  "user_id": "18616683239"
}

response = requests.post(url, json=payload)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
