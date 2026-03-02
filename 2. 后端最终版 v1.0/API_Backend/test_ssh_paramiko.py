import paramiko
import sys

def test_ssh(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        print("SUCCESS: LOGGED_IN")
        stdin, stdout, stderr = client.exec_command("whoami")
        print(f"Whoami result: {stdout.read().decode().strip()}")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    if not test_ssh(ip, password):
        # Try the other password just in case
        print("Retrying with alternative password...")
        alt_password = "SSH_PASSWORD_PLACEHOLDER"
        test_ssh(ip, alt_password)
