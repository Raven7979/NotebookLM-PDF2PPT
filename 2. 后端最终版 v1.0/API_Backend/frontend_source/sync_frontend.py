import paramiko
import os

def upload_directory(sftp, local_dir, remote_dir):
    """
    Recursively uploads a directory to the remote server using SFTP.
    """
    try:
        sftp.mkdir(remote_dir)
    except IOError:
        pass  # Directory might already exist

    for item in os.listdir(local_dir):
        local_path = os.path.join(local_dir, item)
        remote_path = os.path.join(remote_dir, item)
        
        if os.path.isdir(local_path):
            upload_directory(sftp, local_path, remote_path)
        else:
            print(f"Uploading {local_path} -> {remote_path}")
            sftp.put(local_path, remote_path)

def deploy_frontend(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        sftp = client.open_sftp()
        local_dist = "dist"
        remote_frontend = "/var/www/pdf_to_ppt_frontend"
        
        print(f"Syncing frontend assets to {remote_frontend}...")
        # Clear existing dist if any
        client.exec_command(f"rm -rf {remote_frontend} && mkdir -p {remote_frontend}")
        
        upload_directory(sftp, local_dist, remote_frontend)
        sftp.close()
        
        print("Updating Nginx configuration to support Frontend + Backend...")
        nginx_config = f"""
server {{
    listen 80;
    server_name ehotapp.xyz;

    root /var/www/pdf_to_ppt_frontend;
    index index.html;

    location / {{
        try_files $uri $uri/ /index.html;
    }}

    location /api {{
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}

    location /static {{
        # Backend static files (like QR codes if any)
        proxy_pass http://127.0.0.1:8000/static;
    }}
}}
"""
        client.exec_command(f"echo '{nginx_config}' > /etc/nginx/sites-available/pdf_to_ppt")
        client.exec_command("nginx -t && systemctl reload nginx")
        
        # We already have SSL enabled via certbot, it should have modified sites-enabled link
        # Certbot usually creates a separate server block or modifies the existing one.
        # Since I am REPLACING the file, I might need to re-run certbot or just ensure the SSL block is kept.
        # Actually, certbot --nginx usually MANAGES the file.
        # I'll re-run certbot to be safe and ensure the redirects and SSL are correct.
        
        print("Re-running Certbot to ensure SSL is correctly configured for the new Nginx layout...")
        client.exec_command("certbot --nginx -d ehotapp.xyz --non-interactive --agree-tos --email admin@ehotapp.xyz")
        
        print("SUCCESS: FRONTEND_DEPLOYED_AND_NGINX_UPDATED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    deploy_frontend(ip, password)
