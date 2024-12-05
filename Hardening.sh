#!/bin/bash

# Verify if started with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[ERROR] This script must be run as root (with sudo).\033[0m"
    exit 1
fi


sudo apt update -y
sudo apt upgrade -y
# Function to display a status message
log() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

# Check and install required packages
install_package() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii  $package "; then
        log "$package is being installed..."
        sudo apt install -y "$package" >> /var/log/config_script.log 2>&1
        if [[ $? -ne 0 ]]; then
            log "Error while installing $package."
            echo "Failure while installing $package. Please check logs for more details." >&2
        else
            log "$package installation was successful."
        fi
    else
        log "$package is already installed."
    fi
}

# Configure login.defs
configure_login_defs() {
    log "Setting parameters in /etc/login.defs..."

    LOGIN_DEFS="/etc/login.defs"

    # Configurer PASS_MIN_DAYS et PASS_MAX_DAYS
    sed -i 's/^PASS_MIN_DAYS\s\+[0-9]\+/PASS_MIN_DAYS 7/' "$LOGIN_DEFS"
    sed -i 's/^PASS_MAX_DAYS\s\+[0-9]\+/PASS_MAX_DAYS 90/' "$LOGIN_DEFS"
    
    # Configurer PASS_MIN_LEN (ajouter si absent)
    if grep -q "^PASS_MIN_LEN" "$LOGIN_DEFS"; then
        sed -i 's/^PASS_MIN_LEN\s\+[0-9]\+/PASS_MIN_LEN 12/' "$LOGIN_DEFS"
    else
        echo "PASS_MIN_LEN 12" >> "$LOGIN_DEFS"
    fi

    # Configurer PASS_MAX_LEN (ajouter si absent)
    if grep -q "^PASS_MAX_LEN" "$LOGIN_DEFS"; then
        sed -i 's/^PASS_MAX_LEN\s\+[0-9]\+/PASS_MAX_LEN 20/' "$LOGIN_DEFS"
    else
        echo "PASS_MAX_LEN 20" >> "$LOGIN_DEFS"
    fi
    
    # Ajouter ou mettre à jour umask dans /etc/profile
    if grep -q '^UMASK' "$LOGIN_DEFS"; then
        # Mise à jour de la ligne UMASK existante
        sed -i "s/^UMASK.*/UMASK 027/" "$LOGIN_DEFS"
    else
        echo 'UMASK 027' >> "$LOGIN_DEFS"
    fi

    # Mettre à jour umask dans /etc/profile
    if grep -q '^umask' /etc/profile; then
        sed -i 's/^umask.*/umask 027/' /etc/profile
    else
        echo 'umask 027' >> /etc/profile
    fi

    # Mettre à jour umask dans /etc/bash.bashrc
    if grep -q '^umask' /etc/bash.bashrc; then
        sed -i 's/^umask.*/umask 027/' /etc/bash.bashrc
    else
        echo 'umask 027' >> /etc/bash.bashrc
    fi
}


# Compiler hardening
harden_compilers() {
    log "Applying compiler hardening if present..."

    if [ -f /usr/bin/gcc ]; then
        sudo chmod o-rx /usr/bin/gcc
    else
    
        log "File /usr/bin/gcc does not exist."
    fi

        if [ -f /usr/bin/as ]; then
        sudo chmod o-rx /usr/bin/as
    else
    
        log "File /usr/bin/as does not exist."
    fi

    if [ -f /usr/bin/g++ ]; then
        sudo chmod o-rx /usr/bin/g++
    else
        log "File /usr/bin/g++ does not exist."
    fi

    # Create a script for compiler hardening
    cat <<EOF > /etc/profile.d/compiler_hardening.sh
export CFLAGS='-Wall -Wextra -Werror -fstack-protector-strong -D_FORTIFY_SOURCE=2'
export CXXFLAGS='-Wall -Wextra -Werror -fstack-protector-strong -D_FORTIFY_SOURCE=2'
export LDFLAGS='-Wl,-z,relro,-z,now'
EOF

    chmod +x /etc/profile.d/compiler_hardening.sh
    log "Compiler hardening is complete."
}

# SSH configuration
configure_ssh() {
    log "SSH hardening..."
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Demander le nom de l'entreprise à l'utilisateur
    read -p "Enter company name: " entity_name

    # Vérifier si l'utilisateur a entré une valeur
    if [[ -z "$entity_name" ]]; then
        log "Error: No company name provided. Exiting SSH configuration."
        exit 1
    fi

    log "Company name entered: $entity_name"

    # Backup de la configuration SSH si nécessaire
    if [ ! -f /etc/ssh/sshd_config.bak ]; then
        cp "$SSHD_CONFIG" /etc/ssh/sshd_config.bak
    fi

    # Configuration des options SSH
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
        [Banner]="/etc/issue"
        [PermitRootLogin]="no"
    )

    for key in "${!ssh_options[@]}"; do
        if grep -q "^$key " "$SSHD_CONFIG"; then
            # Utiliser un délimiteur qui ne risque pas d'apparaître dans le nom de l'entreprise
            sed -i "s#$key .*#$key ${ssh_options[$key]}#" "$SSHD_CONFIG"
        else
            echo "$key ${ssh_options[$key]}" >> "$SSHD_CONFIG"
        fi
    done

    # Création de la bannière SSH
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

    # Appliquer les permissions appropriées au fichier de la bannière
    chmod 0644 /etc/issue

    # Vérification de la syntaxe pour SSH
    if command -v sshd &> /dev/null; then
        sshd -t
        if [ $? -ne 0 ]; then
            log "Error in SSH configuration. Please verify: $SSHD_CONFIG."
            exit 1
        fi
    else
        log "sshd not found. Please check your OpenSSH installation."
        exit 1
    fi
    cp /etc/issue /etc/issue.net
    # Redémarrer le service SSH pour appliquer les modifications
    systemctl restart sshd
    log "SSH service configured."
    
}


# Permission configuration
configure_permissions() {
    log "Configuring permissions..."

    for file in /boot/grub/grub.cfg /etc/crontab /etc/ssh/sshd_config; do
        if [ -f "$file" ]; then
            chmod 0600 "$file"
        else
            log "File $file does not exist."
        fi
    done

    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$dir" ]; then
            chmod 0640 "$dir"
        else
            log "Directory $dir does not exist."
        fi
    done

    log "Permissions configured."
}

# Configure Fail2Ban
configure_fail2ban() {
    if ! command -v systemctl &> /dev/null; then
        log "systemctl not found, unable to configure Fail2Ban."
        return
    fi

    log "Installing and configuring Fail2Ban..."
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
    log "Fail2Ban is ready."
}

# Configure installed packages
configure_installed_packages() {
    log "Configuring installed packages..."

    # ClamAV
    if systemctl is-active --quiet clamav-freshclam; then
        log "ClamAV is already running."
    else
        cat <<EOL > /etc/clamav/clamd.conf
# Basic configuration for clamd
LogFile /var/log/clamav/clamd.log
LogTime yes
DatabaseDirectory /var/lib/clamav
TemporaryDirectory /tmp
Email alert@example.com
PidFile /var/run/clamav/clamd.pid
EOL
        systemctl enable clamav-freshclam > /dev/null
        systemctl start clamav-freshclam > /dev/null
        log "ClamAV is ready."
    fi

    # AppArmor
    if systemctl is-active --quiet apparmor; then
        log "AppArmor is already active."
    else
        systemctl enable apparmor > /dev/null
        systemctl start apparmor > /dev/null
        log "AppArmor is activated."
    fi

    # SELinux check
    if command -v selinuxenabled &> /dev/null && selinuxenabled; then
        log "SELinux is active."
    else
        log "SELinux is not active or not supported on this system."
    fi

    # RSyslog
    if systemctl is-active --quiet rsyslog; then
        log "RSyslog is already configured."
    else
        systemctl enable rsyslog > /dev/null
        systemctl start rsyslog > /dev/null
        log "RSyslog configured and activated."
    fi

    # Unattended-Upgrades
    if dpkg -l | grep -q "^ii  unattended-upgrades "; then
        dpkg-reconfigure -plow unattended-upgrades > /dev/null
        log "Unattended-Upgrades configured for automatic updates."
    else
        log "The unattended-upgrades package is not installed."
    fi

    log "All installed packages have been configured."
}

# USB storage disabling
disable_usb_storage() {
    log "Disabling USB storage devices..."

    # Add UDEV rule to block USB storage
    echo 'ACTION=="add", SUBSYSTEM=="usb", ENV{ID_USB_DRIVER}=="usb-storage", ATTR{authorized}="0"' > /etc/udev/rules.d/99-usb-storage.rules

    # Reload UDEV rules
    udevadm control --reload-rules
    log "USB storage devices are disabled."
}

# Install additional packages
install_extras() {
    log "Installing additional security tools..."
    install_package auditd
    install_package ufw
    install_package lynis
    install_package rkhunter
    install_package fail2ban
    install_package debsums
    install_package sysstat
    install_package clamav
    install_package apt-listbugs
    install_package libpam-tmpdir
    install_package apt-show-versions
    install_package pam_passwdqc
    log "Additional security tools installed."
}

# Run the functions
install_extras
configure_login_defs
harden_compilers
configure_ssh
configure_permissions
configure_fail2ban
disable_usb_storage
configure_installed_packages


# Reboot system
echo -e "\033[1;31m[WARNING] Your system must be restarted to apply changes !\033[0m"
