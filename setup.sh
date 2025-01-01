#!/bin/bash

# Gerekli paketleri yükle
sudo apt update
sudo apt install -y nodejs npm mysql-server

# MySQL root şifresini ayarla
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '305507gold';"

# Veritabanı ve tabloyu oluştur
mysql -u root -p305507gold << EOF
CREATE DATABASE IF NOT EXISTS bot_database;
USE bot_database;
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_id BIGINT NOT NULL,
    message TEXT,
    response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# Proje klasörünü oluştur
mkdir -p ~/telegram-bot
cd ~/telegram-bot

# package.json oluştur
cat > package.json << EOF
{
  "name": "telegram-bot",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.2",
    "mysql2": "^3.6.5",
    "dotenv": "^16.3.1"
  }
}
EOF

# setup-webhook.js dosyasını oluştur
cat > setup-webhook.js << EOF
const axios = require('axios');

const TOKEN = '7567212917:AAHeAtNVzR7LbsIj2G5JhBmPUfG0C0AGsxQ';
const url = 'https://api.visionifobot.com/webhook';

async function setupWebhook() {
    try {
        const response = await axios.post(\`https://api.telegram.org/bot\${TOKEN}/setWebhook\`, {
            url: url
        });
        console.log('Webhook kurulumu başarılı:', response.data);
    } catch (error) {
        console.error('Webhook kurulum hatası:', error);
    }
}

setupWebhook();
EOF

# Bağımlılıkları yükle
npm install

# PM2'yi global olarak yükle
sudo npm install -g pm2

# Uygulamayı PM2 ile başlat
pm2 start app.js

# PM2'yi sistem başlangıcında otomatik başlatmak için
pm2 startup
pm2 save

# Nginx yükle ve yapılandır
sudo apt install -y nginx
sudo apt install -y certbot python3-certbot-nginx

# Nginx yapılandırması
sudo tee /etc/nginx/sites-available/telegram-bot << EOF
server {
    server_name api.visionifobot.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Nginx sitesini etkinleştir
sudo ln -s /etc/nginx/sites-available/telegram-bot /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# SSL sertifikası al
sudo certbot --nginx -d api.visionifobot.com --non-interactive --agree-tos --email bedosom@gmail.com

# Webhook'u ayarla
node setup-webhook.js

echo "Kurulum tamamlandı!"
