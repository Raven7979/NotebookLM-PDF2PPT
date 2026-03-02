import paramiko
import os

def list_logs(ip, password):
    print(f"Connecting to {ip}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port=22, username="root", password=password)
    
    print("Listing /var/log/supervisor/...")
    stdin, stdout, stderr = ssh.exec_command("ls -lh /var/log/supervisor/")
    print(stdout.read().decode())
    
    ssh.close()

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    list_logs(ip, password)
