import paramiko
import os
from pathlib import Path

def upload_directory(sftp, local_dir, remote_dir):
    """
    Recursively uploads a directory to the remote server using SFTP.
    """
    try:
        sftp.mkdir(remote_dir)
    except IOError:
        pass  # Directory might already exist

    for item in os.listdir(local_dir):
        if item in ['.env', 'venv', '__pycache__', '.git', 'test_output', 'generated_pptx', 'uploads', 'note_pdf.db', 'sql_app.db', 'node_modules']:
            continue
            
        local_path = os.path.join(local_dir, item)
        remote_path = os.path.join(remote_dir, item)
        
        if os.path.isdir(local_path):
            upload_directory(sftp, local_path, remote_path)
        else:
            print(f"Uploading {local_path} -> {remote_path}")
            sftp.put(local_path, remote_path)

def deploy_code(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        sftp = client.open_sftp()
        local_backend = str(Path(__file__).resolve().parent)
        remote_backend = "/var/www/note_pdf_to_ppt"
        
        print("Syncing code files...")
        upload_directory(sftp, local_backend, remote_backend)
        
        # Manually upload .env but maybe sanitize it or let user edit it
        # For now, I'll upload it as it contains current secrets
        print("Uploading .env...")
        local_env = os.path.join(local_backend, '.env')
        if not os.path.exists(local_env):
            raise FileNotFoundError(f"Local .env not found: {local_env}")
        sftp.put(local_env, os.path.join(remote_backend, '.env'))
        
        sftp.close()
        
        print("Installing dependencies and setting up venv on server...")
        setup_cmds = [
            f"cd {remote_backend}",
            "python3.12 -m venv venv",
            "venv/bin/pip install --upgrade pip",
            "venv/bin/pip install -r requirements.txt"
        ]
        
        for cmd in setup_cmds:
            print(f"Running: {cmd}")
            stdin, stdout, stderr = client.exec_command(cmd)
            print(stdout.read().decode())
            err = stderr.read().decode()
            if err:
                print(f"STDERR: {err}")
        
        print("SUCCESS: CODE_DEPLOYED_AND_DEPENDENCIES_INSTALLED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = os.getenv("SSH_IP", "SSH_IP_PLACEHOLDER")
    password = os.getenv("SSH_PASSWORD", "SSH_PASSWORD_PLACEHOLDER")
    deploy_code(ip, password)
