#!/bin/bash

# مسیر ذخیره گواهی
certPath="/root/cert"

# لاگ ساده
log() { echo -e "\033[1;32m[+] $1\033[0m"; }
err() { echo -e "\033[1;31m[-] $1\033[0m"; }

# بررسی و نصب acme.sh در صورت نیاز
install_acme() {
    if [ ! -f ~/.acme.sh/acme.sh ]; then
        log "Installing acme.sh..."
        curl https://get.acme.sh | sh
        source ~/.bashrc
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    fi
}

# ورودی اطلاعات کاربر
read -rp "Enter your domain (example.com): " CF_Domain
read -rp "Enter your Cloudflare API Key: " CF_GlobalKey
read -rp "Enter your Cloudflare Account Email: " CF_AccountEmail

# نصب acme.sh
install_acme

# ست کردن CA روی Let's Encrypt
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || { err "Failed to set default CA"; exit 1; }

# تنظیم متغیرهای محیطی برای Cloudflare DNS
export CF_Key="${CF_GlobalKey}"
export CF_Email="${CF_AccountEmail}"

# گرفتن گواهی SSL از کلادفلر
log "Issuing SSL certificate for $CF_Domain and *.$CF_Domain..."
~/.acme.sh/acme.sh --issue --dns dns_cf -d "${CF_Domain}" -d "*.${CF_Domain}" --log --force || { err "Certificate issuance failed"; exit 1; }

# نصب گواهی در مسیر مشخص
domainCertPath="${certPath}/${CF_Domain}"
mkdir -p "${domainCertPath}"
~/.acme.sh/acme.sh --install-cert -d "${CF_Domain}" -d "*.${CF_Domain}" \
    --key-file "${domainCertPath}/privkey.pem" \
    --fullchain-file "${domainCertPath}/fullchain.pem" \
    --reloadcmd "echo Certificate reloaded"

# بررسی موفقیت نصب
if [ $? -eq 0 ]; then
    log "Certificate installed at:"
    echo "  - Key: ${domainCertPath}/privkey.pem"
    echo "  - Full Chain: ${domainCertPath}/fullchain.pem"
else
    err "Certificate installation failed"
    exit 1
fi

# فعال‌سازی آپدیت خودکار
~/.acme.sh/acme.sh --upgrade --auto-upgrade
log "Auto renewal enabled"