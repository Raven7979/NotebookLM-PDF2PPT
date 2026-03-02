import requests

BASE_URL = "http://localhost:8000/api/auth"

def test_login(phone, code="888888"):
    print(f"\nTesting login for {phone}...")
    try:
        response = requests.post(f"{BASE_URL}/login", json={
            "phone_number": phone,
            "code": code
        })
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    # 1. Allowed User (Should succeed if code valid, or fail with 400 if code invalid, but NOT 403)
    # Using 888888 for quick check if backdoor enabled, otherwise might fail with "Invalid code" which is GOOD (means passed security check)
    # The key is to NOT get "Access Denied" (403).
    test_login("18616683239", "888888") 
    
    # 2. Blocked User (Should fail with 403)
    test_login("13800138000", "888888")
