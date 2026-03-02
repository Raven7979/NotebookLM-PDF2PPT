import pexpect
import sys

ip = "SSH_IP_PLACEHOLDER"
password = os.getenv("SSH_PASSWORD", "PLACEHOLDER")

print("Starting ping test...")
ping = pexpect.spawn(f"ping -c 5 {ip}")
ping.expect(pexpect.EOF)
print(ping.before.decode())

print("Attempting SSH connection...")
child = pexpect.spawn(f"ssh -o StrictHostKeyChecking=no root@{ip}", timeout=30)
try:
    i = child.expect(['password:', pexpect.EOF, pexpect.TIMEOUT])
    if i == 0:
        child.sendline(password)
        child.expect(['root@', '# '])
        print("Logged in successfully!")
        
        # Apply Nginx config directly via bash heredoc
        cmd = """
cat << 'EOF' > /etc/nginx/sites-available/pdf_to_ppt
server {
    listen 80;
    server_name ehotapp.xyz;
    root /var/www/pdf_to_ppt_frontend;
    index index.html;
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(?:css|js|woff2?)$ {
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
EOF
"""
        child.sendline(cmd)
        child.expect(['root@', '# '])
        
        child.sendline("nginx -t && systemctl reload nginx")
        child.expect(['root@', '# '])
        print("Nginx Output:", child.before.decode())
        
        child.sendline("certbot --nginx -d ehotapp.xyz --non-interactive --agree-tos -m admin@ehotapp.xyz")
        child.expect(['root@', '# '], timeout=60)
        print("Certbot Output:", child.before.decode())
        
        child.sendline("exit")
    elif i == 1:
        print("SSH Connection closed prematurely.")
        print(child.before.decode() if child.before else "No output")
    else:
        print("SSH Connection timed out.")
        print(child.before.decode() if child.before else "No output")
except Exception as e:
    print(f"Exception: {e}")
