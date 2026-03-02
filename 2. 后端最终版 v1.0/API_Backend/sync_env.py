import paramiko
import os
from pathlib import Path


def _local_env_path() -> str:
    script_dir = Path(__file__).resolve().parent
    env_path = script_dir / ".env"
    if not env_path.exists():
        raise FileNotFoundError(f"Local .env not found: {env_path}")
    return str(env_path)

def deploy_env(ip, password):
    print(f"Connecting to {ip}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port=22, username="root", password=password)
    
    print("Uploading .env...")
    sftp = ssh.open_sftp()
    sftp.put(_local_env_path(), "/var/www/note_pdf_to_ppt/.env")
    sftp.close()
    
    print("Restarting backend service...")
    stdin, stdout, stderr = ssh.exec_command("supervisorctl restart pdf_to_ppt")
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    if out: print(out)
    if err: print("Error:", err)
    
    print("SUCCESS: ENV UPDATED AND SERVICE RESTARTED")
    ssh.close()

if __name__ == "__main__":
    ip = os.getenv("SSH_IP", "SSH_IP_PLACEHOLDER")
    password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
    deploy_env(ip, password)
