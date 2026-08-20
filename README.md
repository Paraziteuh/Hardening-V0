# Hardening-V0

**Hardening-V0** is a baseline system hardening script, designed as a starting point for improving the security of Linux systems based on **Lynis** audit results. 

This script is **intended for educational purposes** and should be customized to meet specific security requirements or use cases.

---

## Features
- Provides basic security hardening measures based on Lynis recommendations.
- Includes modifiable configurations for user-specific needs.
- Helps users understand the importance of system hardening and how to apply it.
- Hardens SSH (`sshd_config`, banner, moved off port 22 by default) and
  configures a matching UFW firewall policy (default deny incoming, only the
  configured SSH port allowed).
- Installs and configures Fail2Ban, auditd (with a baseline `config/audit.rules`
  rule set), ClamAV, AppArmor, RSyslog and chrony (time sync).
- Applies systemd sandboxing drop-ins (`services/*-hardening.sh`) to the
  ClamAV, Fail2Ban and RSyslog services.
- Applies kernel/network sysctl hardening (`config/sysctl-hardening.conf`:
  ASLR, anti-spoofing, ICMP/redirect restrictions, SYN flood mitigation, ...)
  and blacklists uncommon filesystem/network-protocol kernel modules
  (`config/modprobe-blacklist.conf`).
- Hardens sudo (command logging, shorter credential caching) and restricts
  `su` to the `sudo` group; wires `pam_passwdqc` into the PAM password stack.
- Activates security tools that are otherwise installed but inert by
  default: rkhunter and debsums scheduled checks, sysstat data collection,
  and an AIDE file integrity baseline.

> **Note:** this script has been reviewed carefully but not executed against a
> live system as part of recent changes. Test it in a disposable VM/container
> before running it on anything you care about, and keep a separate access
> path (console, snapshot) in case the SSH/firewall changes lock you out.

---

## Prerequisites
Before running this script:
1. Clone the repository:
   ```bash
   git clone https://github.com/Paraziteuh/Hardening-V0.git
   cd Hardening-V0
   ```

2. (Optional) Review and adjust `config/ssh.config` to match your needs.
   Any `KEY=VALUE` pair set there overrides the script's built-in SSH
   hardening defaults.

3. Run the script:
   ```bash
   sudo chmod +x Hardening.sh
   sed -i 's/\r//g' Hardening.sh
   sudo ./Hardening.sh
   ```

4. Audit the result:
   ```bash
   sudo lynis audit system --pentest
   ```
