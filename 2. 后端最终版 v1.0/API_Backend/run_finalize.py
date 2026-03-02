import paramiko
import os

def finalize_server_setup(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        remote_backend = "/var/www/note_pdf_to_ppt"
        
        print("Finishing dependency install and creating directories...")
        setup_cmd = f"cd {remote_backend} && mkdir -p uploads generated_pptx static && venv/bin/pip install -r requirements.txt"
        stdin, stdout, stderr = client.exec_command(setup_cmd)
        print(stdout.read().decode())
        print(stderr.read().decode())
        
        supervisor_config = f"""
[program:pdf_to_ppt]
directory={remote_backend}
command={remote_backend}/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
autostart=true
autorestart=true
stderr_logfile=/var/log/pdf_to_ppt.err.log
stdout_logfile=/var/log/pdf_to_ppt.out.log
user=root
"""
        print("Configuring Supervisor...")
        client.exec_command(f"echo '{supervisor_config}' > /etc/supervisor/conf.d/pdf_to_ppt.conf")
        client.exec_command("supervisorctl reread && supervisorctl update && supervisorctl restart pdf_to_ppt")
        
        print("Verifying service status...")
        stdin, stdout, stderr = client.exec_command("supervisorctl status pdf_to_ppt")
        print(stdout.read().decode())
        
        print("SUCCESS: SERVER_FINALIZED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    finalize_server_setup(ip, password)
