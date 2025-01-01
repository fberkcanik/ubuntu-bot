#!/bin/bash

# Gerekli paketleri yükle
sudo apt update
sudo apt install -y git nodejs npm mysql-server


# app.js dosyasını oluştur
cat > app.js << EOF
require('dotenv').config();
const express = require('express');
const axios = require('axios');
const mysql = require('mysql2/promise');
const app = express();

app.use(express.json());

// Veritabanı bağlantı havuzu
const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '305507gold',
    database: 'bot_database'
});

const TOKEN = '7567212917:AAHeAtNVzR7LbsIj2G5JhBmPUfG0C0AGsxQ';
const TELEGRAM_API = \`https://api.telegram.org/bot\${TOKEN}\`;

// Webhook endpoint'i
app.post('/webhook', async (req, res) => {
    try {
        const { message } = req.body;
        
        if (!message) {
            return res.sendStatus(200);
        }

        const chatId = message.chat.id;
        const text = message.text;

        // Gelen mesaja göre yanıt oluştur
        let responseText = 'Mesajınız alındı!';
        
        if (text === '/start') {
            responseText = 'Hoş geldiniz! Size nasıl yardımcı olabilirim?';
        }

        // Telegram'a yanıt gönder
        await axios.post(\`\${TELEGRAM_API}/sendMessage\`, {
            chat_id: chatId,
            text: responseText
        });

        // Mesajı veritabanına kaydet
        const connection = await pool.getConnection();
        try {
            await connection.execute(
                'INSERT INTO messages (chat_id, message, response) VALUES (?, ?, ?)',
                [chatId, text, responseText]
            );
        } finally {
            connection.release();
        }

        res.sendStatus(200);
    } catch (error) {
        console.error('Hata:', error);
        res.sendStatus(500);
    }
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(\`Server \${PORT} portunda çalışıyor\`);
});
EOF

# setup.sql dosyasını oluştur
cat > setup.sql << EOF
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    chat_id BIGINT NOT NULL,
    message TEXT,
    response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
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

# MySQL root şifresini ayarla
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '305507gold';"

# Veritabanı ve tabloyu oluştur
mysql -u root -p305507gold << EOF
CREATE DATABASE IF NOT EXISTS bot_database;
USE bot_database;
$(cat setup.sql)
EOF

# Node.js bağımlılıklarını yükle
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
sudo certbot --nginx -d api.visionifobot.com --non-interactive --agree-tos --email your-email@example.com

# Webhook'u ayarla
node setup-webhook.js

echo "Kurulum tamamlandı!"
