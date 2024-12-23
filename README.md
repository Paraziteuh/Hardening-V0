# Hardening-V0

**Hardening-V0** is a baseline system hardening script, designed as a starting point for improving the security of Linux systems based on **Lynis** audit results. 

This script is **intended for educational purposes** and should be customized to meet specific security requirements or use cases.

---

## Features
- Provides basic security hardening measures based on Lynis recommendations.
- Includes modifiable configurations for user-specific needs.
- Helps users understand the importance of system hardening and how to apply it.

---

## Prerequisites
Before running this script:
1. Please modify the config files in config/:
   ```bash
   git clone https://github.com/Paraziteuh/Hardening-V0.git
   cd Hardening-V0
   sudo chmod +x Hardening.sh
   sed -i 's/\r//g' Hardening.sh
   sudo ./Hardening.sh
   ```

2. Run the following:

   ```bash
   sudo lynis audit system --pentest
   ```
