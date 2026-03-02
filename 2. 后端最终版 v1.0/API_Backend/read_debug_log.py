import paramiko
import os

def read_debug_log(ip, password):
    print(f"Connecting to {ip}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port=22, username="root", password=password)
    
    print("Reading payment_debug.log...")
    stdin, stdout, stderr = ssh.exec_command("cat /var/www/note_pdf_to_ppt/payment_debug.log")
    print(stdout.read().decode())
    
    ssh.close()

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
    read_debug_log(ip, password)
