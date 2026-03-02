import paramiko
import os

def configure_nginx_and_ssl(ip, password, domain):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        nginx_config = f"""
server {{
    listen 80;
    server_name {domain};

    location / {{
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""
        print("Uploading Nginx configuration...")
        stdin, stdout, stderr = client.exec_command(f"echo '{nginx_config}' > /etc/nginx/sites-available/pdf_to_ppt")
        print(stderr.read().decode())
        
        print("Enabling site and restarting Nginx...")
        client.exec_command("ln -sf /etc/nginx/sites-available/pdf_to_ppt /etc/nginx/sites-enabled/")
        client.exec_command("rm -f /etc/nginx/sites-enabled/default")
        stdin, stdout, stderr = client.exec_command("nginx -t && systemctl restart nginx")
        print(stdout.read().decode())
        print(stderr.read().decode())
        
        print(f"Obtaining SSL certificate for {domain} (this requires DNS to be propagated)...")
        # Use --nginx for auto-configuration and -n for non-interactive
        stdin, stdout, stderr = client.exec_command(f"certbot --nginx -d {domain} --non-interactive --agree-tos --email admin@{domain}")
        
        for line in stdout:
            print(line.strip())
        print(stderr.read().decode())
        
        print("SUCCESS: NGINX_AND_SSL_CONFIGURED")
        client.close()
        return True
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return False

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
    domain = "ehotapp.xyz"
    configure_nginx_and_ssl(ip, password, domain)
