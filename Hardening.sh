#!/bin/bash

# Fonction pour afficher un message avec statut
log() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

# Vérification et installation des paquets requis
install_package() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii  $package "; then
        log "Installation du paquet $package..."
        apt install -y "$package" >> /var/log/config_script.log 2>&1
        if [[ $? -ne 0 ]]; then
            log "Erreur lors de l'installation de $package."
            echo "Échec de l'installation de $package. Vérifiez les logs pour plus de détails." >&2
        else
            log "Paquet $package installé avec succès."
        fi
    else
        log "Le paquet $package est déjà installé."
    fi
}

# Login def
configure_login_defs() {
    log "Configuration des paramètres de /etc/login.defs..."

    LOGIN_DEFS="/etc/login.defs"

    # Configuration des rounds de hachage de mot de passe
    if ! grep -q "^PASS_MIN_DAYS" "$LOGIN_DEFS"; then
        echo "PASS_MIN_DAYS    1" >> "$LOGIN_DEFS"
        log "PASS_MIN_DAYS défini à 1."
    fi

    if ! grep -q "^PASS_MAX_DAYS" "$LOGIN_DEFS"; then
        echo "PASS_MAX_DAYS    90" >> "$LOGIN_DEFS"
        log "PASS_MAX_DAYS défini à 90."
    fi

    if ! grep -q "^PASS_MIN_LEN" "$LOGIN_DEFS"; then
        echo "PASS_MIN_LEN     12" >> "$LOGIN_DEFS"
        log "PASS_MIN_LEN défini à 12."
    fi

    if ! grep -q "^PASS_HASHING_ALGO" "$LOGIN_DEFS"; then
        echo "PASS_HASHING_ALGO sha512" >> "$LOGIN_DEFS"
        log "PASS_HASHING_ALGO défini à sha512."
    fi

    if ! grep -q "^UMASK" "$LOGIN_DEFS"; then
        echo "UMASK            027" >> "$LOGIN_DEFS"
        log "UMASK défini à 027."
    fi

    log "Configuration de /etc/login.defs terminée."
}


# Fonction de hardening des compilateurs
harden_compilers() {
    log "Application du hardening des compilateurs si existant..."

    if [ -f /usr/bin/gcc ]; then
        chmod o-rx /usr/bin/gcc
    else
        log "Le fichier /usr/bin/gcc n'existe pas."
    fi

    if [ -f /usr/bin/g++ ]; then
        chmod o-rx /usr/bin/g++
    else
        log "Le fichier /usr/bin/g++ n'existe pas."
    fi

    # Création d'un script pour la configuration des compilateurs
    cat <<EOF > /etc/profile.d/compiler_hardening.sh
export CFLAGS='-Wall -Wextra -Werror -fstack-protector-strong -D_FORTIFY_SOURCE=2'
export CXXFLAGS='-Wall -Wextra -Werror -fstack-protector-strong -D_FORTIFY_SOURCE=2'
export LDFLAGS='-Wl,-z,relro,-z,now'
EOF

    chmod +x /etc/profile.d/compiler_hardening.sh
    log "Hardening des compilateurs appliqué."
}

# Fonction de configuration SSH
configure_ssh() {
    log "Configuration du service SSH..."
    SSHD_CONFIG="/etc/ssh/sshd_config"

    declare -A ssh_options=(
        [AllowTcpForwarding]="NO"
        [ClientAliveCountMax]="2"
        [Compression]="NO"
        [LogLevel]="VERBOSE"
        [MaxAuthTries]="3"
        [MaxSessions]="2"
        [TCPKeepAlive]="NO"
        [X11Forwarding]="NO"
        [AllowAgentForwarding]="NO"
        [Port]="2222"
    )

    # Modification de la configuration SSH
    for key in "${!ssh_options[@]}"; do
        if grep -q "^$key " "$SSHD_CONFIG"; then
            sed -i "s/^$key .*/$key ${ssh_options[$key]}/" "$SSHD_CONFIG"
        else
            echo "$key ${ssh_options[$key]}" >> "$SSHD_CONFIG"
        fi
    done

    # Sauvegarde et ajout de la bannière
    if [ ! -f /etc/issue.bak ]; then
        cp /etc/issue /etc/issue.bak
    fi

    cat <<EOF > /etc/issue
***************************************************************************
*                        Authorized Access Only                           *
***************************************************************************
This system is the property of $entity_name. Unauthorized  
access, use, or modification of this system or its data is strictly 
prohibited and may lead to legal action under applicable laws, including 
but not limited to the General Data Protection Regulation (GDPR) and 
other European cybersecurity regulations.

By accessing this system, you agree to the following conditions:
- Your activity is subject to monitoring and logging.

- Any unauthorized access or misuse will be reported to the appropriate 
  authorities.

- You must ensure that your actions comply with all applicable security 
  policies and regulations.

If you are not an authorized user, disconnect immediately. Use of this 
system by unauthorized persons or for unauthorized purposes may result 
in prosecution to the fullest extent of the law.

***************************************************************************
EOF

    unset entity_name

    # Vérification de la syntaxe de la configuration SSH
    if command -v sshd &> /dev/null; then
        sshd -t
        if [ $? -ne 0 ]; then
            log "Erreur dans la configuration SSH. Veuillez vérifier le fichier $SSHD_CONFIG."
            exit 1
        fi
    else
        log "Commande sshd non trouvée. Vérifiez l'installation de OpenSSH."
        exit 1
    fi

    # Redémarrage du service SSH
    systemctl restart sshd
    log "Service SSH configuré."
}

# Fonction de configuration des permissions
configure_permissions() {
    log "Configuration des permissions..."

    for file in /boot/grub/grub.cfg /etc/crontab /etc/ssh/sshd_config; do
        if [ -f "$file" ]; then
            chmod 0600 "$file"
        else
            log "Le fichier $file n'existe pas."
        fi
    done

    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$dir" ]; then
            chmod 0640 "$dir"
        else
            log "Le répertoire $dir n'existe pas."
        fi
    done

    log "Permissions configurées."
}

# Fonction de configuration de Fail2Ban
configure_fail2ban() {
    if ! command -v systemctl &> /dev/null; then
        log "systemctl non trouvé, impossible de configurer Fail2Ban."
        return
    fi

    log "Installation et configuration de Fail2Ban..."
    install_package fail2ban

    FAIL2BAN_CONFIG="/etc/fail2ban/jail.local"

    cat <<EOF > "$FAIL2BAN_CONFIG"
[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

    systemctl enable fail2ban > /dev/null
    systemctl start fail2ban > /dev/null
    log "Fail2Ban configuré et activé."
}

# Fonction de configuration des paquets installés
configure_installed_packages() {
    log "Configuration des paquets installés..."

    # ClamAV
    if systemctl is-active --quiet clamav-freshclam; then
        log "ClamAV est déjà actif."
    else
        systemctl enable clamav-freshclam > /dev/null
        systemctl start clamav-freshclam > /dev/null
        log "ClamAV configuré et mis à jour."
    fi

    # AppArmor
    if systemctl is-active --quiet apparmor; then
        log "AppArmor est déjà activé."
    else
        systemctl enable apparmor > /dev/null
        systemctl start apparmor > /dev/null
        log "AppArmor activé."
    fi

    # SELinux (vérification)
    if command -v selinuxenabled &> /dev/null && selinuxenabled; then
        log "SELinux est actif."
    else
        log "SELinux n'est pas actif ou pris en charge sur ce système."
    fi

    # RSyslog
    if systemctl is-active --quiet rsyslog; then
        log "RSyslog est déjà configuré."
    else
        systemctl enable rsyslog > /dev/null
        systemctl start rsyslog > /dev/null
        log "RSyslog configuré et activé."
    fi

    # Unattended-Upgrades
    if dpkg -l | grep -q "^ii  unattended-upgrades "; then
        dpkg-reconfigure -plow unattended-upgrades > /dev/null
        log "Unattended-Upgrades configuré pour les mises à jour automatiques."
    else
        log "Le paquet unattended-upgrades n'est pas installé."
    fi

    log "Tous les paquets installés ont été configurés."
}

# Fonction pour la configuration des paquets supplémentaires
install_extras() {
    log "Installation des paquets supplémentaires..."
    local packages=("apt-listchanges" "apt-listbugs" "clamav" "apparmor" "selinux-utils"
                    "rsyslog" "unattended-upgrades" "tripwire" "libpam-tmpdir" "libpam-pwquality")

    for package in "${packages[@]}"; do
        install_package "$package"
    done

    # Configurer Tripwire après l'installation
    log "Configuration de Tripwire..."
    dpkg --configure -a >> /var/log/config_script.log 2>&1
    log "Tripwire configuré."

    log "Paquets supplémentaires et frameworks de sécurité installés."
}

# Fonction pour la configuration de l'expiration des mots de passe
set_password_expiration_for_all() {
    local expiration_days="$1"
    if [ -z "$expiration_days" ]; then
        echo "Usage: set_password_expiration_for_all <days>"
        return 1
    fi

    while IFS=: read -r username _ _ _ _ shell; do
        if [ -n "$shell" ] && [ "$shell" != "/usr/sbin/nologin" ] && [ "$shell" != "/bin/false" ]; then
            chage -M "$expiration_days" "$username"
        fi
    done < /etc/passwd

    log "L'expiration des mots de passe a été définie sur $expiration_days jours pour tous les utilisateurs."
}

# Fonction pour désactiver la création de core dumps
disable_core_dumps() {
    log "Désactivation de la création de core dumps..."
    if ! grep -q "core" /etc/security/limits.conf; then
        echo "* soft core 0" >> /etc/security/limits.conf
        echo "* hard core 0" >> /etc/security/limits.conf
        log "Core dumps désactivés dans /etc/security/limits.conf."
    else
        log "Core dumps déjà désactivés dans /etc/security/limits.conf."
    fi
}

# Fonction pour configurer le hachage des mots de passe
configure_password_hashing() {
    log "Configuration des rounds de hachage des mots de passe..."
    LOGIN_DEFS="/etc/login.defs"

    if grep -q "^ENCRYPT_METHOD" "$LOGIN_DEFS"; then
        sed -i "s/^ENCRYPT_METHOD .*/ENCRYPT_METHOD SHA512/" "$LOGIN_DEFS"
    else
        echo "ENCRYPT_METHOD SHA512" >> "$LOGIN_DEFS"
    fi

    if grep -q "^PASS_MIN_DAYS" "$LOGIN_DEFS"; then
        sed -i "s/^PASS_MIN_DAYS .*/PASS_MIN_DAYS 1/" "$LOGIN_DEFS"
    else
        echo "PASS_MIN_DAYS 1" >> "$LOGIN_DEFS"
    fi

    if grep -q "^PASS_MAX_DAYS" "$LOGIN_DEFS"; then
        sed -i "s/^PASS_MAX_DAYS .*/PASS_MAX_DAYS 90/" "$LOGIN_DEFS"
    else
        echo "PASS_MAX_DAYS 90" >> "$LOGIN_DEFS"
    fi

    log "Configuration des mots de passe mise à jour dans /etc/login.defs."
}

# Appels des fonctions principales
install_extras
configure_installed_packages
logi
harden_compilers
configure_ssh
configure_permissions
configure_fail2ban
set_password_expiration_for_all 90
disable_core_dumps
configure_password_hashing

log "Toutes les configurations sont terminées."
