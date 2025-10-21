# CyberXP-OS Software Licenses

This document lists all software components included in CyberXP-OS and their respective licenses.

---

## CyberXP-OS Components

### CyberXP-OS Core
- **License**: MIT License
- **Copyright**: 2025 CyberXP-OS Contributors
- **Repository**: https://github.com/abaryan/CyberXP-OS

### CyberXP Dashboard
- **License**: MIT License
- **Copyright**: 2025 CyberXP-OS Project
- **Description**: Lightweight Flask-based security monitoring dashboard
- **Dependencies**: Flask (BSD-3-Clause), Werkzeug (BSD-3-Clause)

---

## Base Operating System

### Alpine Linux
- **License**: MIT License (and various component licenses)
- **Version**: 3.18.4
- **Website**: https://alpinelinux.org/
- **Description**: Lightweight security-focused Linux distribution

---

## Security Tools

### Suricata
- **License**: GPLv2
- **Website**: https://suricata.io/
- **Description**: Network Intrusion Detection System (IDS/IPS)

### fail2ban
- **License**: GPLv2
- **Website**: https://www.fail2ban.org/
- **Description**: Intrusion prevention software framework

### Nmap
- **License**: Nmap Public Source License (custom, GPL-compatible)
- **Website**: https://nmap.org/
- **Description**: Network discovery and security auditing

### tcpdump
- **License**: BSD-3-Clause
- **Website**: https://www.tcpdump.org/
- **Description**: Network packet analyzer

### ClamAV
- **License**: GPLv2
- **Website**: https://www.clamav.net/
- **Description**: Open source antivirus engine

### AIDE
- **License**: GPLv2
- **Website**: https://aide.github.io/
- **Description**: Advanced Intrusion Detection Environment

---

## System Components

### OpenRC
- **License**: BSD-2-Clause
- **Website**: https://github.com/OpenRC/openrc
- **Description**: Dependency-based init system

### iptables
- **License**: GPLv2
- **Website**: https://www.netfilter.org/
- **Description**: Linux kernel firewall

### OpenSSH
- **License**: BSD-style license
- **Website**: https://www.openssh.com/
- **Description**: Secure shell connectivity tools

---

## Python Components

### Flask
- **License**: BSD-3-Clause
- **Version**: 3.0.0
- **Website**: https://flask.palletsprojects.com/
- **Description**: Lightweight web framework

### Werkzeug
- **License**: BSD-3-Clause
- **Version**: 3.0.1
- **Website**: https://werkzeug.palletsprojects.com/
- **Description**: WSGI utility library

---

## Optional Components (CyberXP Core)

### CyberXP
- **License**: MIT License
- **Repository**: https://github.com/abaryan/CyberXP
- **Description**: AI-powered security threat assessment engine
- **Note**: Optional component for advanced AI analysis

### Hugging Face Transformers
- **License**: Apache-2.0
- **Website**: https://huggingface.co/transformers
- **Description**: Machine learning library for NLP

### Gradio
- **License**: Apache-2.0
- **Website**: https://gradio.app/
- **Description**: Web UI for ML models (used in CyberXP core only)

---

## Development Tools (Not included in ISO)

### ShellCheck
- **License**: GPLv3
- **Website**: https://www.shellcheck.net/
- **Description**: Shell script static analysis tool

### VirtualBox
- **License**: GPLv2 (VirtualBox OSE)
- **Website**: https://www.virtualbox.org/
- **Description**: Virtualization software for testing

---

## License Compatibility

CyberXP-OS is distributed under the **MIT License**, which is compatible with:
- ✅ GPLv2 components (one-way compatibility)
- ✅ BSD-style licenses
- ✅ Apache-2.0 licenses
- ✅ Other permissive licenses

### Combined Work License

When CyberXP-OS is distributed as a complete system including GPL components:
- The overall system is subject to GPL requirements
- Individual MIT-licensed components remain MIT-licensed
- Source code for GPL components is available per GPL requirements

---

## Third-Party Notices

### Alpine Linux Package Repository
CyberXP-OS includes packages from the Alpine Linux repository. Each package has its own license. Use `apk info -L <package>` to view package licenses.

### Security Rules and Signatures
- Suricata rules: Various licenses (Emerging Threats ET Open, etc.)
- ClamAV signatures: Licensed under ClamAV's terms

---

## Source Code Availability

### For GPL Components
Source code for all GPL-licensed components is available from:
1. Alpine Linux package repository: https://pkgs.alpinelinux.org/
2. Upstream project websites (listed above)
3. CyberXP-OS repository: https://github.com/abaryan/CyberXP-OS

### For CyberXP-OS Components
Source code is available at: https://github.com/abaryan/CyberXP-OS

---

## Trademark Notices

- **Alpine Linux** is a trademark of Alpine Linux Development Team
- **Suricata** is a trademark of the Open Information Security Foundation (OISF)
- **ClamAV** is a project of Cisco Systems
- **VirtualBox** is a trademark of Oracle Corporation
- **CyberXP-OS** and **CyberXP** are projects of the CyberXP-OS development team

---

## Disclaimer

This software is provided "AS IS", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement.

---

## Questions?

For licensing questions or clarifications:
- **Email**: legal@cyberxp-os.com
- **GitHub Issues**: https://github.com/abaryan/CyberXP-OS/issues

---

**Last Updated**: October 2025  
**CyberXP-OS Version**: 0.1.0-alpha

