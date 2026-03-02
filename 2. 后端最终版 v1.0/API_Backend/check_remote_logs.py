import paramiko
import os

def read_logs(ip, password):
    print(f"Connecting to {ip}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port=22, username="root", password=password)
    
    print("Reading stdout logs...")
    stdin, stdout, stderr = ssh.exec_command("tail -n 100 /var/log/supervisor/pdf_to_ppt-stdout*.log")
    print(stdout.read().decode())
    
    print("Reading stderr logs...")
    stdin, stdout, stderr = ssh.exec_command("tail -n 100 /var/log/supervisor/pdf_to_ppt-stderr*.log")
    print(stdout.read().decode())
    
    ssh.close()

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
    read_logs(ip, password)
