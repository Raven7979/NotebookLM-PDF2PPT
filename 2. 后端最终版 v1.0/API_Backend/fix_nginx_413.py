import paramiko

ip = "SSH_IP_PLACEHOLDER"
password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")
domain = "ehotapp.xyz"

def fix_nginx_timeout():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        # Read current config
        stdin, stdout, stderr = client.exec_command("cat /etc/nginx/sites-available/pdf_to_ppt")
        current_config = stdout.read().decode()
        print("Current Config:\n", current_config)
        
        # New config with 100M limit AND extended timeouts
        nginx_config = f"""
server {{
    server_name {domain};

    client_max_body_size 100M;

    # Extended timeouts for large file processing
    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    proxy_read_timeout 300;
    send_timeout 300;

    location / {{
        try_files $uri $uri/ /index.html;
    }}

    location /api {{
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Per-location extended timeouts
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }}

    location /static {{
        proxy_pass http://127.0.0.1:8000/static;
    }}

    root /var/www/pdf_to_ppt_frontend;
    index index.html;

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/{domain}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/{domain}/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}}

server {{
    if ($host = {domain}) {{
        return 301 https://$host$request_uri;
    }} # managed by Certbot

    listen 80;
    server_name {domain};
    return 404; # managed by Certbot
}}
"""
        print("Updating Nginx configuration with timeouts and body size limit...")
        
        # Write config using heredoc to avoid shell quoting issues
        sftp = client.open_sftp()
        with sftp.file('/etc/nginx/sites-available/pdf_to_ppt', 'w') as f:
            f.write(nginx_config)
        sftp.close()
        
        print("Testing and restarting Nginx...")
        stdin, stdout, stderr = client.exec_command("nginx -t && systemctl restart nginx")
        
        out = stdout.read().decode()
        err = stderr.read().decode()
        print("Stdout:", out)
        print("Stderr:", err)
        
        if "test is successful" in err or "test is successful" in out:
            print("SUCCESS: Nginx updated with 300s timeouts and 100M body size.")
        else:
            print("WARNING: Nginx test might have failed. Please check.")
            
        client.close()
    except Exception as e:
        print(f"ERROR: {str(e)}")

if __name__ == "__main__":
    fix_nginx_timeout()
