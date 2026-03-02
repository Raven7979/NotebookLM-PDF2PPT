import paramiko
import os

def upload_directory(sftp, local_dir, remote_dir):
    """
    Recursively uploads a directory to the remote server using SFTP.
    """
    try:
        sftp.mkdir(remote_dir)
        print(f"Created remote dir: {remote_dir}")
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
        # Use absolute local path
        local_dist = "/Users/Ravenlei/Work/Vibe coding/Notebooklm 2 PPTX/NotePDF2PPT_v2/frontend/dist"
        remote_frontend = "/var/www/pdf_to_ppt_frontend"
        
        if not os.path.exists(local_dist):
            print(f"ERROR: Local dist folder not found at {local_dist}")
            return False

        print(f"Syncing frontend assets from {local_dist} to {remote_frontend}...")
        # Clear existing dist if any
        client.exec_command(f"rm -rf {remote_frontend} && mkdir -p {remote_frontend}")
        
        upload_directory(sftp, local_dist, remote_frontend)
        sftp.close()
        
        print("Updating Nginx configuration...")
        nginx_config = """
server {
    listen 80;
    server_name ehotapp.xyz;

    root /var/www/pdf_to_ppt_frontend;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static {
        proxy_pass http://127.0.0.1:8000/static;
    }
}
"""
        # Upload config and reload nginx
        stdin, stdout, stderr = client.exec_command(f"echo '{nginx_config}' > /etc/nginx/sites-available/pdf_to_ppt")
        print(stderr.read().decode())
        
        print("Testing and reloading Nginx...")
        stdin, stdout, stderr = client.exec_command("nginx -t && systemctl reload nginx")
        print(stdout.read().decode())
        print(stderr.read().decode())
        
        print("Re-running Certbot...")
        stdin, stdout, stderr = client.exec_command("certbot --nginx -d ehotapp.xyz --non-interactive --agree-tos --email admin@ehotapp.xyz")
        print(stdout.read().decode())
        print(stderr.read().decode())
        
        print("SUCCESS: FRONTEND_DEPLOYED_AND_NGINX_UPDATED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    deploy_frontend(ip, password)
