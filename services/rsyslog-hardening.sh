#!/bin/bash

# Define the path to the rsyslog service file and drop-in directory
SERVICE_FILE="/lib/systemd/system/rsyslog.service"
DROP_IN_DIR="/etc/systemd/system/rsyslog.service.d"
DROP_IN_FILE="$DROP_IN_DIR/extend.conf"

# Check if the rsyslog.service file exists
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "RSyslog service file not found at $SERVICE_FILE. Please ensure RSyslog is installed."
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
# ProtectKernelLogs is deliberately NOT set here: rsyslog's imklog module
# reads the kernel log ring buffer, and blocking it would silently stop
# kernel messages from reaching the logs. CAP_NET_ADMIN is dropped since,
# unlike Fail2Ban, rsyslog never touches firewall rules.
echo "Creating/updating the $DROP_IN_FILE file with security hardening settings..."
cat <<EOL | sudo tee "$DROP_IN_FILE" > /dev/null
[Service]
# Security Hardening
ProtectSystem=strict
ProtectHome=yes
ReadOnlyPaths=/usr
ReadWritePaths=/var/log
ReadWritePaths=/var/spool/rsyslog
NoNewPrivileges=true
CapabilityBoundingSet=~CAP_SYS_ADMIN ~CAP_NET_ADMIN ~CAP_SYS_PTRACE ~CAP_SYS_BOOT ~CAP_SYS_CHROOT ~CAP_SYS_TIME ~CAP_WAKE_ALARM ~CAP_BLOCK_SUSPEND ~CAP_MAC_ADMIN ~CAP_MAC_OVERRIDE ~CAP_AUDIT_CONTROL ~CAP_PERFMON ~CAP_BPF ~CAP_LEASE
PrivateTmp=true
PrivateDevices=true
ProtectKernelModules=true
ProtectClock=true
ProtectKernelTunables=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK
RestrictNamespaces=true
SystemCallFilter=@system-service
UMask=0027

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

# Restart and enable the RSyslog service
echo "Restarting and enabling the RSyslog service..."
sudo systemctl restart rsyslog.service
if [[ $? -ne 0 ]]; then
    echo "Failed to restart the RSyslog service. Please check the service status for errors."
    exit 1
fi
sudo systemctl enable rsyslog.service > /dev/null

# Verify the status of the RSyslog service
echo "Checking the status of the RSyslog service..."
sudo systemctl status rsyslog.service --no-pager

echo "RSyslog service has been successfully hardened."
