import paramiko
import os

def deploy_setup(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        print("Uploading setup_server.sh...")
        sftp = client.open_sftp()
        sftp.put('setup_server.sh', '/root/setup_server.sh')
        sftp.chmod('/root/setup_server.sh', 0o755)
        sftp.close()
        
        print("Executing setup_server.sh (this may take a few minutes)...")
        stdin, stdout, stderr = client.exec_command("bash /root/setup_server.sh")
        
        # Stream the output
        for line in stdout:
            print(line.strip())
        
        err = stderr.read().decode()
        if err:
            print(f"STDERR: {err}")
            
        print("SUCCESS: ENVIRONMENT_INITIALIZED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
    deploy_setup(ip, password)
