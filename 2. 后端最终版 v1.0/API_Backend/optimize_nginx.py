import paramiko

def optimize_nginx(ip, password):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {ip}...")
        client.connect(hostname=ip, port=22, username='root', password=password, timeout=10)
        
        nginx_config = """
server {
    listen 80;
    server_name ehotapp.xyz;

    root /var/www/pdf_to_ppt_frontend;
    index index.html;

    # Gzip settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(?:css|js)$ {
        try_files $uri =404;
        expires 1y;
        access_log off;
        add_header Cache-Control "public";
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
        # Upload config
        stdin, stdout, stderr = client.exec_command(f"cat << 'EOF' > /etc/nginx/sites-available/pdf_to_ppt\n{nginx_config}\nEOF\n")
        print(stderr.read().decode())
        
        # Test and reload
        client.exec_command("nginx -t && systemctl reload nginx")
        
        # Re-apply SSL
        print("Re-applying SSL...")
        stdin, stdout, stderr = client.exec_command("certbot --nginx -d ehotapp.xyz --non-interactive --agree-tos --email admin@ehotapp.xyz")
        print(stdout.read().decode())
        
        print("SUCCESS: NGINX_OPTIMIZED")
        client.close()
    except Exception as e:
        print(f"ERROR: {str(e)}")

if __name__ == "__main__":
    ip = "SSH_IP_PLACEHOLDER"
    password = "SSH_PASSWORD_PLACEHOLDER"
    optimize_nginx(ip, password)
