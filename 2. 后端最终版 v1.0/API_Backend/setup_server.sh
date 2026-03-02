#!/bin/bash
set -e

echo "--- Starting System Update ---"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

echo "--- Installing Basic Dependencies ---"
apt-get install -y software-properties-common curl git build-essential nginx sqlite3 supervisor

echo "--- Installing Python 3.12 ---"
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get install -y python3.12 python3.12-venv python3.12-dev

echo "--- Installing Certbot (SSL) ---"
apt-get install -y certbot python3-certbot-nginx

echo "--- Creating Web Directory ---"
mkdir -p /var/www/note_pdf_to_ppt
chown -R root:root /var/www/note_pdf_to_ppt

echo "--- Verification ---"
python3.12 --version
nginx -v
certbot --version

echo "--- Server Setup Complete ---"
