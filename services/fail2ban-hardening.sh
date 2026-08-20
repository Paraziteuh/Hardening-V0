#!/bin/bash

# Define the path to the fail2ban service file and drop-in directory
SERVICE_FILE="/lib/systemd/system/fail2ban.service"
DROP_IN_DIR="/etc/systemd/system/fail2ban.service.d"
DROP_IN_FILE="$DROP_IN_DIR/extend.conf"

# Check if the fail2ban.service file exists
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Fail2Ban service file not found at $SERVICE_FILE. Please ensure Fail2Ban is installed."
    exit 1
fi

# Create the drop-in directory if it doesn't exist
if [[ ! -d "$DROP_IN_DIR" ]]; then
    echo "Creating drop-in directory for custom service configuration..."
    sudo mkdir -p "$DROP_IN_DIR"
    if [[ $? -ne 0 ]]; then
        echo "Failed to create drop-in directory. Aborting."
        exit 1
    fi
    echo "Drop-in directory created at $DROP_IN_DIR."
fi

# Create or update the extend.conf file with security hardening settings.
# Unlike ClamAV, Fail2Ban keeps CAP_NET_ADMIN/CAP_NET_RAW: it needs them to
# insert and remove ban rules via iptables/nftables.
echo "Creating/updating the $DROP_IN_FILE file with security hardening settings..."
cat <<EOL | sudo tee "$DROP_IN_FILE" > /dev/null
[Service]
# Security Hardening
ProtectSystem=strict
ProtectHome=yes
ReadOnlyPaths=/usr
ReadWritePaths=/var/run/fail2ban
ReadWritePaths=/var/lib/fail2ban
NoNewPrivileges=true
CapabilityBoundingSet=~CAP_SYS_ADMIN ~CAP_SYS_PTRACE ~CAP_SYS_BOOT ~CAP_SYS_CHROOT ~CAP_SYS_TIME ~CAP_WAKE_ALARM ~CAP_BLOCK_SUSPEND ~CAP_MAC_ADMIN ~CAP_MAC_OVERRIDE ~CAP_AUDIT_WRITE ~CAP_AUDIT_CONTROL ~CAP_PERFMON ~CAP_BPF ~CAP_LEASE
PrivateTmp=true
PrivateDevices=true
ProtectKernelModules=true
ProtectClock=true
ProtectKernelLogs=true
ProtectKernelTunables=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK
RestrictNamespaces=true
SystemCallFilter=@system-service
UMask=0077

EOL

if [[ $? -ne 0 ]]; then
    echo "Failed to create/update the extend.conf file. Aborting."
    exit 1
fi
echo "Security hardening settings added to $DROP_IN_FILE."

# Reload systemd to apply changes
echo "Reloading systemd configuration..."
sudo systemctl daemon-reload
if [[ $? -ne 0 ]]; then
    echo "Failed to reload systemd configuration. Please check manually."
    exit 1
fi

# Restart and enable the Fail2Ban service
echo "Restarting and enabling the Fail2Ban service..."
sudo systemctl restart fail2ban.service
if [[ $? -ne 0 ]]; then
    echo "Failed to restart the Fail2Ban service. Please check the service status for errors."
    exit 1
fi
sudo systemctl enable fail2ban.service > /dev/null

# Verify the status of the Fail2Ban service
echo "Checking the status of the Fail2Ban service..."
sudo systemctl status fail2ban.service --no-pager

echo "Fail2Ban service has been successfully hardened."
