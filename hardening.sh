#!/bin/bash
# ============================================
# Astra Hardening Script
# Безопасная настройка Astra Linux
# ============================================

set -e

# --- Конфигурация ---
LOG_FILE="/var/log/hardening.log"
DATE=$(date "+%Y-%m-%d %H:%M:%S")

# --- Функция логирования ---
log() {
    echo "[$DATE] $1" | tee -a $LOG_FILE
}

log "=============================="
log "Начало настройки безопасности"

# --- 1. Обновление системы ---
log "Обновление системы..."
apt update && apt upgrade -y

# --- 2. Настройка файрвола (ufw) ---
log "Настройка файрвола..."
apt install ufw -y
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
log "Файрвол включён. Разрешены: SSH"

# --- 3. Отключение ненужных служб ---
log "Отключение ненужных служб..."
systemctl stop cups 2>/dev/null || true
systemctl disable cups 2>/dev/null || true
systemctl stop bluetooth 2>/dev/null || true
systemctl disable bluetooth 2>/dev/null || true
systemctl stop avahi-daemon 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true
log "Отключены: cups, bluetooth, avahi-daemon"

# --- 4. Политика паролей ---
log "Настройка политики паролей..."
apt install libpam-pwquality -y
sed -i 's/.*password.*requisite.*pam_pwquality.so.*/password requisite pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 reject_username enforce_for_root/' /etc/pam.d/common-password

# --- 5. Автоматические обновления безопасности ---
log "Настройка автоматических обновлений..."
apt install unattended-upgrades -y
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl restart unattended-upgrades 2>/dev/null || true
log "Автообновления включены"

# --- 6. Настройка логирования ---
log "Настройка логирования..."
apt install auditd -y
auditctl -e 1 2>/dev/null || true
systemctl enable auditd 2>/dev/null || true
systemctl start auditd 2>/dev/null || true
log "Аудит включён"

# --- 7. Защита SSH ---
log "Настройка SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
log "SSH настроен: root-вход только по ключам, парольная аутентификация отключена"

# --- 8. Итог ---
log "=============================="
log "Настройка безопасности завершена!"
log "Лог сохранён в $LOG_FILE"
log "Не забудьте перезагрузить систему: sudo reboot"
