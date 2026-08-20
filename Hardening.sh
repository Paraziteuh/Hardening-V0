#!/bin/bash

# Verify if started with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[ERROR] This script must be run as root (with sudo).\033[0m"
    exit 1
fi

# Resolve the script's own directory so config/ and services/ can be
# referenced reliably regardless of the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo apt update -y
sudo apt upgrade -y
# Function to display a status message
log() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

# Run a services/*.sh systemd hardening drop-in script, if present.
apply_service_hardening() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        log "Applying hardening: $(basename "$script_path")..."
        chmod +x "$script_path"
        "$script_path"
    else
        log "Hardening script not found at $script_path, skipping."
    fi
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

# Kernel/network sysctl hardening
configure_sysctl() {
    log "Applying kernel/network sysctl hardening..."

    SYSCTL_HARDENING_FILE="$SCRIPT_DIR/config/sysctl-hardening.conf"
    if [[ ! -f "$SYSCTL_HARDENING_FILE" ]]; then
        log "Sysctl hardening file not found at $SYSCTL_HARDENING_FILE, skipping."
        return
    fi

    cp "$SYSCTL_HARDENING_FILE" /etc/sysctl.d/99-hardening.conf
    sysctl --system > /dev/null
    log "Sysctl hardening applied."
}

# Kernel module blacklist for uncommon filesystems/protocols
configure_module_blacklist() {
    log "Blacklisting uncommon kernel modules..."

    MODPROBE_BLACKLIST_FILE="$SCRIPT_DIR/config/modprobe-blacklist.conf"
    if [[ ! -f "$MODPROBE_BLACKLIST_FILE" ]]; then
        log "Module blacklist file not found at $MODPROBE_BLACKLIST_FILE, skipping."
        return
    fi

    cp "$MODPROBE_BLACKLIST_FILE" /etc/modprobe.d/hardening-blacklist.conf
    log "Kernel module blacklist installed (takes effect for modules not already loaded)."
}

# SSH configuration
configure_ssh() {
    log "SSH hardening..."
    SSHD_CONFIG="/etc/ssh/sshd_config"
    SSH_CONFIG_FILE="$SCRIPT_DIR/config/ssh.config"

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

    # Configuration des options SSH (valeurs par défaut, surchargées
    # par config/ssh.config si le fichier est présent)
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

    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        log "Loading SSH hardening options from $SSH_CONFIG_FILE"
        while IFS='=' read -r cfg_key cfg_value; do
            # Ignorer les lignes vides et les commentaires
            [[ -z "$cfg_key" || "$cfg_key" == \#* ]] && continue
            # Nettoyer les espaces superflus autour de la clé/valeur
            cfg_key="$(echo -n "$cfg_key" | tr -d '[:space:]')"
            cfg_value="$(echo -n "$cfg_value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [[ -n "$cfg_key" ]] && ssh_options["$cfg_key"]="$cfg_value"
        done < "$SSH_CONFIG_FILE"
    else
        log "Config file not found at $SSH_CONFIG_FILE, using built-in defaults."
    fi

    # Paramètres critiques imposés indépendamment du fichier de config
    ssh_options[Banner]="/etc/issue"
    ssh_options[PermitRootLogin]="no"

    # Rendu disponible globalement pour configure_ufw(), afin que le pare-feu
    # autorise le port SSH réellement configuré (et pas seulement le 22 par défaut).
    SSH_PORT="${ssh_options[Port]}"

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

# UFW firewall configuration
configure_ufw() {
    if ! command -v ufw &> /dev/null; then
        log "ufw not found, skipping firewall configuration."
        return
    fi

    log "Configuring UFW firewall..."

    ufw default deny incoming > /dev/null
    ufw default allow outgoing > /dev/null

    # Autoriser explicitement le port SSH réellement configuré par
    # configure_ssh() (2222 par défaut, ou la valeur de config/ssh.config),
    # sans quoi l'activation d'ufw couperait l'accès distant.
    local ssh_port="${SSH_PORT:-22}"
    ufw allow "${ssh_port}/tcp" comment 'SSH' > /dev/null
    log "SSH allowed on port ${ssh_port}/tcp."

    # --force évite le prompt de confirmation interactif
    ufw --force enable > /dev/null
    ufw reload > /dev/null

    log "UFW firewall is active."
    ufw status verbose
}

# Time synchronization (accurate time matters for TLS validation and for
# the auditd time-change rules in config/audit.rules to be meaningful)
configure_chrony() {
    if ! command -v chronyd &> /dev/null; then
        log "chrony not found, skipping time sync configuration."
        return
    fi

    log "Enabling chrony time synchronization..."
    systemctl enable chrony > /dev/null 2>&1 || systemctl enable chronyd > /dev/null 2>&1
    systemctl restart chrony > /dev/null 2>&1 || systemctl restart chronyd > /dev/null 2>&1
    log "chrony is active."
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

    # "port" doit correspondre au port SSH réellement configuré par
    # configure_ssh() : si sshd écoute sur 2222 mais que ce jail ne
    # bannit que le port 22, les bans n'ont aucun effet sur le trafic réel.
    cat <<EOF > "$FAIL2BAN_CONFIG"
[sshd]
enabled  = true
port     = ${SSH_PORT:-ssh}
logpath  = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

    systemctl enable fail2ban > /dev/null
    systemctl start fail2ban > /dev/null
    log "Fail2Ban is ready."

    # Apply systemd sandboxing hardening to the Fail2Ban service
    apply_service_hardening "$SCRIPT_DIR/services/fail2ban-hardening.sh"
}

# Configure auditd rules
configure_auditd() {
    if ! command -v auditctl &> /dev/null; then
        log "auditd is not installed, skipping audit rules configuration."
        return
    fi

    log "Configuring auditd rules..."

    AUDIT_RULES_FILE="$SCRIPT_DIR/config/audit.rules"
    if [[ ! -f "$AUDIT_RULES_FILE" ]]; then
        log "Audit rules file not found at $AUDIT_RULES_FILE, skipping."
        return
    fi

    if [[ -d /etc/audit/rules.d ]]; then
        cp "$AUDIT_RULES_FILE" /etc/audit/rules.d/hardening.rules
        if command -v augenrules &> /dev/null; then
            augenrules --load
        else
            # Le paquet auditd sur Debian/Ubuntu documente "service auditd
            # restart" plutôt que "systemctl restart" pour éviter un état
            # incohérent lié à la prise en main du socket netlink d'audit.
            service auditd restart
        fi
    else
        cp "$AUDIT_RULES_FILE" /etc/audit/audit.rules
        service auditd restart
    fi

    systemctl enable auditd > /dev/null 2>&1

    if systemctl is-active --quiet auditd; then
        log "auditd is active with hardening rules."
    else
        log "auditd could not be started, please check manually."
    fi
}

# sudo/su hardening: log every sudo command, shorten the cached credential
# window, and restrict su to members of the 'sudo' group.
configure_sudo_su() {
    log "Hardening sudo and su..."

    local sudo_drop_in="/etc/sudoers.d/99-hardening"
    local sudo_tmp
    sudo_tmp="$(mktemp)"
    cat <<EOF > "$sudo_tmp"
Defaults        logfile="/var/log/sudo.log"
Defaults        log_input
Defaults        log_output
Defaults        timestamp_timeout=5
EOF

    # visudo -c valide la syntaxe AVANT d'activer le fichier : un
    # sudoers.d invalide peut casser sudo pour tout le monde, donc on ne
    # le déploie jamais sans validation préalable.
    if visudo -c -f "$sudo_tmp" > /dev/null 2>&1; then
        mv "$sudo_tmp" "$sudo_drop_in"
        chmod 0440 "$sudo_drop_in"
        log "sudo command logging and reduced credential caching enabled."
    else
        rm -f "$sudo_tmp"
        log "Generated sudoers drop-in failed validation, skipping (sudo left unchanged)."
    fi

    # Ne restreindre su au groupe 'sudo' que si ce groupe a réellement des
    # membres : sinon, cela couperait 'su' pour tout le monde.
    if getent group sudo > /dev/null 2>&1 && [ -n "$(getent group sudo | cut -d: -f4)" ]; then
        if [ -f /etc/pam.d/su ] && ! grep -q 'pam_wheel.so' /etc/pam.d/su; then
            echo 'auth required pam_wheel.so use_uid group=sudo' >> /etc/pam.d/su
            log "su restricted to members of the 'sudo' group."
        fi
    else
        log "Group 'sudo' has no members, skipping su restriction to avoid locking everyone out."
    fi
}

# Wire pam_passwdqc into the PAM password stack via pam-auth-update, rather
# than editing /etc/pam.d/common-password by hand.
configure_pam_passwdqc() {
    if ! dpkg -l | grep -q "^ii  libpam-passwdqc "; then
        log "libpam-passwdqc not installed, skipping password quality PAM setup."
        return
    fi

    log "Enabling pam_passwdqc via pam-auth-update..."
    if command -v pam-auth-update &> /dev/null; then
        DEBIAN_FRONTEND=noninteractive pam-auth-update --enable passwdqc 2>/dev/null
        log "pam_passwdqc enabled."
    else
        log "pam-auth-update not found; please enable pam_passwdqc manually."
    fi
}

# Enable sysstat's periodic system activity data collection (sadc), which
# the package installs disabled by default on Debian/Ubuntu.
configure_sysstat() {
    if ! command -v sar &> /dev/null; then
        log "sysstat not found, skipping."
        return
    fi

    log "Enabling sysstat data collection..."
    SYSSTAT_DEFAULT="/etc/default/sysstat"
    if [ -f "$SYSSTAT_DEFAULT" ]; then
        if grep -q '^ENABLED=' "$SYSSTAT_DEFAULT"; then
            sed -i 's/^ENABLED=.*/ENABLED="true"/' "$SYSSTAT_DEFAULT"
        else
            echo 'ENABLED="true"' >> "$SYSSTAT_DEFAULT"
        fi
    fi
    systemctl enable sysstat > /dev/null 2>&1
    systemctl restart sysstat > /dev/null 2>&1
    log "sysstat data collection is active."
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

    # Apply systemd sandboxing hardening to the ClamAV Fresh Clam service
    apply_service_hardening "$SCRIPT_DIR/services/clamav-hardening.sh"

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

    # Apply systemd sandboxing hardening to the RSyslog service
    apply_service_hardening "$SCRIPT_DIR/services/rsyslog-hardening.sh"

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
    # Le paquet Debian/Ubuntu s'appelle libpam-passwdqc (l'ancien nom
    # pam_passwdqc n'existe pas dans les dépôts et échouait silencieusement).
    install_package libpam-passwdqc
    install_package aide
    install_package chrony
    log "Additional security tools installed."
}

# Initialize the AIDE file integrity database. Run late, after the rest of
# the script's configuration changes, so the baseline reflects the final
# hardened state instead of flagging every file this script just touched.
configure_aide() {
    if ! command -v aide &> /dev/null; then
        log "AIDE not found, skipping file integrity baseline."
        return
    fi

    log "Initializing AIDE file integrity database (this can take a while)..."
    if command -v aideinit &> /dev/null; then
        aideinit -y -f >> /var/log/config_script.log 2>&1
    else
        aide --init >> /var/log/config_script.log 2>&1
        if [ -f /var/lib/aide/aide.db.new ]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        elif [ -f /var/lib/aide/aide.db.new.gz ]; then
            mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        fi
    fi
    log "AIDE database initialized. Verify /etc/cron.daily/aide (or a systemd timer) is scheduled for periodic checks."
}

# Update rkhunter's rootkit signature database and re-baseline the file
# properties it tracks. Run late for the same reason as configure_aide().
configure_rkhunter() {
    if ! command -v rkhunter &> /dev/null; then
        log "rkhunter not found, skipping."
        return
    fi

    log "Updating rkhunter and baselining file properties..."
    RKHUNTER_DEFAULT="/etc/default/rkhunter"
    if [ -f "$RKHUNTER_DEFAULT" ]; then
        if grep -q '^CRON_DAILY_RUN=' "$RKHUNTER_DEFAULT"; then
            sed -i 's/^CRON_DAILY_RUN=.*/CRON_DAILY_RUN="true"/' "$RKHUNTER_DEFAULT"
        else
            echo 'CRON_DAILY_RUN="true"' >> "$RKHUNTER_DEFAULT"
        fi
    fi

    rkhunter --update --nocolors >> /var/log/config_script.log 2>&1
    rkhunter --propupd --nocolors >> /var/log/config_script.log 2>&1
    log "rkhunter database updated; daily scan enabled via $RKHUNTER_DEFAULT."
}

# Enable debsums' scheduled package integrity check.
configure_debsums() {
    if ! command -v debsums &> /dev/null; then
        log "debsums not found, skipping."
        return
    fi

    log "Enabling debsums scheduled integrity check..."
    DEBSUMS_DEFAULT="/etc/default/debsums"
    if [ -f "$DEBSUMS_DEFAULT" ]; then
        if grep -q '^CRON_CHECK=' "$DEBSUMS_DEFAULT"; then
            sed -i 's/^CRON_CHECK=.*/CRON_CHECK=true/' "$DEBSUMS_DEFAULT"
        else
            echo 'CRON_CHECK=true' >> "$DEBSUMS_DEFAULT"
        fi
    fi
    log "debsums scheduled check enabled via $DEBSUMS_DEFAULT."
}

# Run the functions
install_extras
configure_login_defs
harden_compilers
configure_sysctl
configure_module_blacklist
configure_ssh
configure_ufw
configure_chrony
configure_permissions
configure_fail2ban
configure_auditd
configure_sudo_su
configure_pam_passwdqc
configure_sysstat
disable_usb_storage
configure_installed_packages
configure_aide
configure_rkhunter
configure_debsums


# Reboot system
echo -e "\033[1;31m[WARNING] Your system must be restarted to apply changes !\033[0m"
