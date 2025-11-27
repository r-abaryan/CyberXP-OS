#!/usr/bin/env python3
"""
CyberXP-OS Terminal Dashboard with AI Assistant
Professional terminal-based system monitor with integrated AI help
"""

import os
import sys
import time
import subprocess
import json
from datetime import datetime

# ANSI color codes
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    DIM = '\033[2m'
    END = '\033[0m'

def clear_screen():
    """Clear terminal screen"""
    os.system('clear' if os.name == 'posix' else 'cls')

def get_hostname():
    """Get system hostname"""
    try:
        return os.uname().nodename
    except:
        return "unknown"

def get_uptime():
    """Get system uptime"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            return f"{days}d {hours}h {minutes}m"
    except:
        return "unknown"

def get_load_average():
    """Get system load average"""
    try:
        with open('/proc/loadavg', 'r') as f:
            loads = f.read().split()[:3]
            return f"{loads[0]} {loads[1]} {loads[2]}"
    except:
        return "unknown"

def get_memory_info():
    """Get memory information"""
    try:
        meminfo = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    meminfo[parts[0].strip()] = parts[1].strip()
        
        total = int(meminfo.get('MemTotal', '0').split()[0])
        available = int(meminfo.get('MemAvailable', '0').split()[0])
        used = total - available
        
        total_gb = total / 1024 / 1024
        used_gb = used / 1024 / 1024
        percent = (used / total * 100) if total > 0 else 0
        
        return {
            'total': f"{total_gb:.1f} GB",
            'used': f"{used_gb:.1f} GB",
            'percent': f"{percent:.1f}%",
            'percent_num': percent
        }
    except:
        return {'total': 'unknown', 'used': 'unknown', 'percent': 'unknown', 'percent_num': 0}

def get_disk_info():
    """Get disk usage information"""
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            return {
                'total': parts[1],
                'used': parts[2],
                'available': parts[3],
                'percent': parts[4],
                'percent_num': float(parts[4].rstrip('%'))
            }
    except:
        pass
    return {'total': 'unknown', 'used': 'unknown', 'available': 'unknown', 'percent': 'unknown', 'percent_num': 0}

def get_cpu_info():
    """Get CPU information"""
    try:
        # Get CPU model
        with open('/proc/cpuinfo', 'r') as f:
            for line in f:
                if 'model name' in line:
                    cpu_model = line.split(':')[1].strip()
                    break
        
        # Get CPU count
        cpu_count = os.cpu_count()
        
        # Get CPU usage
        with open('/proc/stat', 'r') as f:
            cpu_line = f.readline()
            cpu_times = [int(x) for x in cpu_line.split()[1:]]
            total_time = sum(cpu_times)
            idle_time = cpu_times[3]
            usage_percent = ((total_time - idle_time) / total_time * 100) if total_time > 0 else 0
            
        return {
            'model': cpu_model[:45] + '...' if len(cpu_model) > 45 else cpu_model,
            'cores': cpu_count,
            'usage': f"{usage_percent:.1f}%",
            'usage_num': usage_percent
        }
    except:
        return {'model': 'unknown', 'cores': 'unknown', 'usage': 'unknown', 'usage_num': 0}

def get_network_info():
    """Get network information"""
    try:
        # Get IP address
        result = subprocess.run(['ip', '-4', 'addr', 'show'], capture_output=True, text=True)
        ip_address = "Not configured"
        for line in result.stdout.split('\n'):
            if 'inet ' in line and '127.0.0.1' not in line:
                ip_address = line.split()[1].split('/')[0]
                break
        
        # Get active interfaces
        result = subprocess.run(['ip', 'link', 'show'], capture_output=True, text=True)
        interfaces = []
        for line in result.stdout.split('\n'):
            if 'state UP' in line:
                iface = line.split(':')[1].strip().split('@')[0]
                if iface != 'lo':
                    interfaces.append(iface)
        
        return {
            'ip': ip_address,
            'interfaces': ', '.join(interfaces) if interfaces else 'none'
        }
    except:
        return {'ip': 'unknown', 'interfaces': 'unknown'}

def get_service_status(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(['systemctl', 'is-active', service_name], 
                              capture_output=True, text=True)
        return result.stdout.strip() == 'active'
    except:
        return False

def detect_issues():
    """Detect system issues automatically"""
    issues = []
    
    # Check memory
    mem = get_memory_info()
    if mem['percent_num'] > 90:
        issues.append({
            'type': 'critical',
            'category': 'memory',
            'message': f"High memory usage: {mem['percent']}",
            'suggestion': "Consider restarting services or closing applications"
        })
    elif mem['percent_num'] > 80:
        issues.append({
            'type': 'warning',
            'category': 'memory',
            'message': f"Memory usage elevated: {mem['percent']}",
            'suggestion': "Monitor memory usage closely"
        })
    
    # Check disk
    disk = get_disk_info()
    if disk['percent_num'] > 90:
        issues.append({
            'type': 'critical',
            'category': 'disk',
            'message': f"Disk almost full: {disk['percent']}",
            'suggestion': "Clean up disk space immediately"
        })
    elif disk['percent_num'] > 80:
        issues.append({
            'type': 'warning',
            'category': 'disk',
            'message': f"Disk usage high: {disk['percent']}",
            'suggestion': "Consider cleaning up old files"
        })
    
    # Check services
    services = [
        ('cyberxp-dashboard', 'CyberXP Dashboard'),
        ('ssh', 'SSH Server'),
    ]
    
    for service_name, display_name in services:
        if not get_service_status(service_name):
            issues.append({
                'type': 'warning',
                'category': 'service',
                'message': f"{display_name} is not running",
                'suggestion': f"Start with: sudo systemctl start {service_name}"
            })
    
    return issues

def print_header():
    """Print professional dashboard header"""
    print(f"{Colors.BOLD}{Colors.CYAN}╔═══════════════════════════════════════════════════════════════════╗{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}                                                                   {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}     {Colors.BOLD}{Colors.GREEN}🛡️  CyberXP-OS{Colors.END} {Colors.BOLD}{Colors.BLUE}Security Platform{Colors.END}                       {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}     {Colors.DIM}AI-Powered Monitoring & Threat Analysis{Colors.END}                   {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}     {Colors.DIM}Version 0.1.0-alpha{Colors.END}                                       {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}                                                                   {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}╚═══════════════════════════════════════════════════════════════════╝{Colors.END}")
    print()

def print_section(title, icon="▶"):
    """Print section header with icon"""
    print(f"{Colors.BOLD}{Colors.YELLOW}{icon} {title}{Colors.END}")
    print(f"{Colors.DIM}{'─' * 70}{Colors.END}")

def print_metric(label, value, status=None):
    """Print a metric with optional status indicator"""
    status_icon = ""
    if status == "good":
        status_icon = f"{Colors.GREEN}✓{Colors.END}"
    elif status == "warn":
        status_icon = f"{Colors.YELLOW}⚠{Colors.END}"
    elif status == "error":
        status_icon = f"{Colors.RED}✗{Colors.END}"
    
    print(f"  {Colors.BOLD}{label:.<28}{Colors.END} {value} {status_icon}")

def display_dashboard():
    """Display the main dashboard with professional layout"""
    clear_screen()
    
    # Header
    print_header()
    
    # Detect issues
    issues = detect_issues()
    
    # Show alerts if any
    if issues:
        critical = [i for i in issues if i['type'] == 'critical']
        warnings = [i for i in issues if i['type'] == 'warning']
        
        if critical:
            print_section("🚨 Critical Alerts", "⚠")
            for issue in critical:
                print(f"  {Colors.RED}●{Colors.END} {issue['message']}")
                print(f"    {Colors.DIM}→ {issue['suggestion']}{Colors.END}")
            print()
        
        if warnings:
            print_section("⚡ Warnings", "!")
            for issue in warnings:
                print(f"  {Colors.YELLOW}●{Colors.END} {issue['message']}")
                print(f"    {Colors.DIM}→ {issue['suggestion']}{Colors.END}")
            print()
    
    # System Information
    print_section("System Overview", "📊")
    hostname = get_hostname()
    uptime = get_uptime()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    print_metric("Hostname", hostname)
    print_metric("Uptime", uptime)
    print_metric("Current Time", timestamp)
    print()
    
    # Resource Usage (Compact)
    print_section("Resource Usage", "💻")
    cpu = get_cpu_info()
    mem = get_memory_info()
    disk = get_disk_info()
    
    # CPU
    cpu_status = "good" if cpu['usage_num'] < 70 else "warn" if cpu['usage_num'] < 90 else "error"
    print_metric("CPU", f"{cpu['usage']} ({cpu['cores']} cores)", cpu_status)
    
    # Memory
    mem_status = "good" if mem['percent_num'] < 80 else "warn" if mem['percent_num'] < 90 else "error"
    print_metric("Memory", f"{mem['used']} / {mem['total']} ({mem['percent']})", mem_status)
    
    # Disk
    disk_status = "good" if disk['percent_num'] < 80 else "warn" if disk['percent_num'] < 90 else "error"
    print_metric("Disk", f"{disk['used']} / {disk['total']} ({disk['percent']})", disk_status)
    print()
    
    # Network
    print_section("Network", "🌐")
    net = get_network_info()
    print_metric("IP Address", net['ip'])
    print_metric("Interfaces", net['interfaces'])
    print_metric("Load Average", get_load_average())
    print()
    
    # Services
    print_section("Services", "⚙️")
    services = [
        ('cyberxp-dashboard', 'Dashboard'),
        ('ssh', 'SSH'),
        ('ufw', 'Firewall'),
    ]
    
    for service_name, display_name in services:
        is_active = get_service_status(service_name)
        status = f"{Colors.GREEN}Running{Colors.END}" if is_active else f"{Colors.RED}Stopped{Colors.END}"
        status_icon = "good" if is_active else "error"
        print_metric(display_name, status, status_icon)
    print()
    
    # Footer with commands
    print(f"{Colors.DIM}{'─' * 70}{Colors.END}")
    print(f"{Colors.BOLD}Commands:{Colors.END}")
    print(f"  {Colors.GREEN}h{Colors.END} - AI Help Assistant  │  {Colors.GREEN}a{Colors.END} - Threat Analysis  │  {Colors.GREEN}s{Colors.END} - Services  │  {Colors.GREEN}l{Colors.END} - Logs  │  {Colors.GREEN}q{Colors.END} - Quit")
    print()
    if issues:
        print(f"{Colors.YELLOW}💡 Tip: Press 'h' for AI assistance with detected issues{Colors.END}")
    print(f"{Colors.DIM}Auto-refresh in 5s... (Press any key to refresh){Colors.END}")

def show_ai_assistant():
    """Show AI-powered help assistant"""
    clear_screen()
    print_header()
    print_section("🤖 AI Help Assistant", "")
    print()
    
    # Check if AI is installed
    ai_installed = os.path.exists('/opt/cyberxp-ai/src/cyber_agent_vec.py')
    
    print(f"{Colors.BOLD}What do you need help with?{Colors.END}")
    print()
    print(f"  {Colors.GREEN}1{Colors.END} - Troubleshoot system issues")
    print(f"  {Colors.GREEN}2{Colors.END} - Explain an error message")
    print(f"  {Colors.GREEN}3{Colors.END} - Service management help")
    print(f"  {Colors.GREEN}4{Colors.END} - Security best practices")
    if ai_installed:
        print(f"  {Colors.GREEN}5{Colors.END} - Ask AI anything (custom query)")
    else:
        print(f"  {Colors.DIM}5 - Ask AI anything (requires AI installation){Colors.END}")
    print(f"  {Colors.GREEN}b{Colors.END} - Back to dashboard")
    print()
    
    choice = input(f"{Colors.BOLD}Choice: {Colors.END}").strip()
    
    if choice == '1':
        troubleshoot_issues()
    elif choice == '2':
        explain_error()
    elif choice == '3':
        service_help()
    elif choice == '4':
        security_tips()
    elif choice == '5' and ai_installed:
        custom_ai_query()
    elif choice == '5':
        print(f"\n{Colors.YELLOW}AI not installed. Install with:{Colors.END}")
        print(f"  sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
        input(f"\n{Colors.BOLD}Press Enter to continue...{Colors.END}")

def troubleshoot_issues():
    """Provide troubleshooting guidance"""
    clear_screen()
    print_header()
    print_section("🔧 System Troubleshooting", "")
    print()
    
    issues = detect_issues()
    
    if not issues:
        print(f"{Colors.GREEN}✓ No issues detected! System is healthy.{Colors.END}")
        print()
    else:
        print(f"{Colors.BOLD}Detected Issues:{Colors.END}")
        print()
        
        for i, issue in enumerate(issues, 1):
            icon = "🔴" if issue['type'] == 'critical' else "🟡"
            print(f"{icon} {Colors.BOLD}Issue {i}:{Colors.END} {issue['message']}")
            print(f"   {Colors.CYAN}Category:{Colors.END} {issue['category']}")
            print(f"   {Colors.GREEN}Solution:{Colors.END} {issue['suggestion']}")
            
            # Provide detailed fix
            if issue['category'] == 'memory':
                print(f"   {Colors.BOLD}Commands:{Colors.END}")
                print(f"     • View processes: {Colors.DIM}htop{Colors.END}")
                print(f"     • Kill process: {Colors.DIM}sudo kill -9 <PID>{Colors.END}")
            elif issue['category'] == 'disk':
                print(f"   {Colors.BOLD}Commands:{Colors.END}")
                print(f"     • Find large files: {Colors.DIM}sudo du -h / | sort -rh | head -20{Colors.END}")
                print(f"     • Clean apt cache: {Colors.DIM}sudo apt clean{Colors.END}")
            elif issue['category'] == 'service':
                service_name = 'cyberxp-dashboard' if 'Dashboard' in issue['message'] else 'ssh'
                print(f"   {Colors.BOLD}Commands:{Colors.END}")
                print(f"     • Start: {Colors.DIM}sudo systemctl start {service_name}{Colors.END}")
                print(f"     • Enable: {Colors.DIM}sudo systemctl enable {service_name}{Colors.END}")
                print(f"     • Check logs: {Colors.DIM}sudo journalctl -u {service_name} -n 20{Colors.END}")
            print()
    
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def explain_error():
    """Explain error messages"""
    clear_screen()
    print_header()
    print_section("📝 Error Explanation", "")
    print()
    
    print("Paste your error message (or type 'q' to cancel):")
    print()
    error = input(f"{Colors.BOLD}Error: {Colors.END}").strip()
    
    if error.lower() == 'q' or not error:
        return
    
    print()
    print(f"{Colors.YELLOW}Analyzing error...{Colors.END}")
    print()
    
    # Simple pattern matching for common errors
    explanations = {
        'permission denied': {
            'meaning': 'You don\'t have permission to access this file/command',
            'solution': 'Try running with sudo: sudo <command>'
        },
        'command not found': {
            'meaning': 'The command is not installed or not in PATH',
            'solution': 'Install the package or check spelling'
        },
        'connection refused': {
            'meaning': 'Service is not running or port is blocked',
            'solution': 'Check if service is running: systemctl status <service>'
        },
        'no space left': {
            'meaning': 'Disk is full',
            'solution': 'Free up disk space: sudo apt clean && sudo apt autoremove'
        },
        'port already in use': {
            'meaning': 'Another process is using this port',
            'solution': 'Find process: sudo lsof -i :<port>, then kill it'
        }
    }
    
    found = False
    for pattern, info in explanations.items():
        if pattern in error.lower():
            print(f"{Colors.BOLD}Explanation:{Colors.END}")
            print(f"  {info['meaning']}")
            print()
            print(f"{Colors.BOLD}Solution:{Colors.END}")
            print(f"  {info['solution']}")
            found = True
            break
    
    if not found:
        print(f"{Colors.YELLOW}Error not recognized in database.{Colors.END}")
        print()
        print("Try:")
        print(f"  • Google the error message")
        print(f"  • Check logs: sudo journalctl -n 50")
        print(f"  • Ask in CyberXP community")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def service_help():
    """Service management help"""
    clear_screen()
    print_header()
    print_section("⚙️ Service Management Guide", "")
    print()
    
    print(f"{Colors.BOLD}Common Service Commands:{Colors.END}")
    print()
    print(f"  {Colors.GREEN}Start service:{Colors.END}")
    print(f"    sudo systemctl start <service>")
    print()
    print(f"  {Colors.GREEN}Stop service:{Colors.END}")
    print(f"    sudo systemctl stop <service>")
    print()
    print(f"  {Colors.GREEN}Restart service:{Colors.END}")
    print(f"    sudo systemctl restart <service>")
    print()
    print(f"  {Colors.GREEN}Check status:{Colors.END}")
    print(f"    sudo systemctl status <service>")
    print()
    print(f"  {Colors.GREEN}Enable auto-start:{Colors.END}")
    print(f"    sudo systemctl enable <service>")
    print()
    print(f"  {Colors.GREEN}View logs:{Colors.END}")
    print(f"    sudo journalctl -u <service> -f")
    print()
    print(f"{Colors.BOLD}CyberXP Services:{Colors.END}")
    print(f"  • cyberxp-dashboard - Web dashboard")
    print(f"  • ssh - SSH server")
    print(f"  • ufw - Firewall")
    print()
    
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def security_tips():
    """Show security best practices"""
    clear_screen()
    print_header()
    print_section("🔒 Security Best Practices", "")
    print()
    
    tips = [
        ("Change default passwords", "sudo passwd && sudo passwd root"),
        ("Enable firewall", "sudo ufw enable && sudo ufw allow 22/tcp"),
        ("Keep system updated", "sudo apt update && sudo apt upgrade"),
        ("Monitor logs regularly", "sudo journalctl -f"),
        ("Use SSH keys", "ssh-keygen -t ed25519"),
        ("Disable root login", "Edit /etc/ssh/sshd_config: PermitRootLogin no"),
        ("Install fail2ban", "sudo apt install fail2ban"),
        ("Regular backups", "Use rsync or backup tools"),
    ]
    
    for i, (tip, command) in enumerate(tips, 1):
        print(f"{Colors.GREEN}{i}.{Colors.END} {Colors.BOLD}{tip}{Colors.END}")
        if command:
            print(f"   {Colors.DIM}{command}{Colors.END}")
        print()
    
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def custom_ai_query():
    """Custom AI query"""
    clear_screen()
    print_header()
    print_section("🤖 Ask AI Anything", "")
    print()
    
    print("What would you like to know? (or 'q' to cancel)")
    print()
    query = input(f"{Colors.BOLD}Question: {Colors.END}").strip()
    
    if query.lower() == 'q' or not query:
        return
    
    print()
    print(f"{Colors.YELLOW}⏳ Processing AI query...{Colors.END}")
    print(f"{Colors.DIM}This may take 5-10 seconds on CPU (faster with GPU){Colors.END}")
    print(f"{Colors.DIM}Please wait...{Colors.END}")
    print()
    
    try:
        result = subprocess.run(
            ['cyberxp-analyze', query],
            capture_output=True,
            text=True,
            timeout=120  # Increased to 2 minutes for CPU inference
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}AI query failed{Colors.END}")
            print(result.stderr)
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Query timeout (>2 minutes){Colors.END}")
        print()
        print(f"{Colors.YELLOW}💡 Tips to speed up AI:{Colors.END}")
        print(f"  • Increase VM RAM to 8GB+")
        print(f"  • Increase VM CPUs to 4+")
        print(f"  • Install on physical machine with GPU")
        print(f"  • Use shorter/simpler queries")
    except FileNotFoundError:
        print(f"{Colors.RED}AI not properly configured{Colors.END}")
    except Exception as e:
        print(f"{Colors.RED}Error: {str(e)}{Colors.END}")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def show_service_menu():
    """Show service management menu"""
    clear_screen()
    print_header()
    print_section("Service Management", "⚙️")
    print()
    print(f"  {Colors.GREEN}1{Colors.END} - Start CyberXP Dashboard")
    print(f"  {Colors.GREEN}2{Colors.END} - Stop CyberXP Dashboard")
    print(f"  {Colors.GREEN}3{Colors.END} - Restart CyberXP Dashboard")
    print(f"  {Colors.GREEN}4{Colors.END} - View Dashboard Status")
    print(f"  {Colors.GREEN}b{Colors.END} - Back to main dashboard")
    print()
    
    choice = input(f"{Colors.BOLD}Enter choice: {Colors.END}").strip().lower()
    
    if choice == '1':
        subprocess.run(['sudo', 'systemctl', 'start', 'cyberxp-dashboard'])
        print(f"{Colors.GREEN}Service started{Colors.END}")
        time.sleep(2)
    elif choice == '2':
        subprocess.run(['sudo', 'systemctl', 'stop', 'cyberxp-dashboard'])
        print(f"{Colors.YELLOW}Service stopped{Colors.END}")
        time.sleep(2)
    elif choice == '3':
        subprocess.run(['sudo', 'systemctl', 'restart', 'cyberxp-dashboard'])
        print(f"{Colors.GREEN}Service restarted{Colors.END}")
        time.sleep(2)
    elif choice == '4':
        subprocess.run(['systemctl', 'status', 'cyberxp-dashboard'])
        input(f"\n{Colors.BOLD}Press Enter to continue...{Colors.END}")

def show_logs():
    """Show recent logs"""
    clear_screen()
    print_header()
    print_section("Recent Logs (Last 20 lines)", "📄")
    print()
    subprocess.run(['journalctl', '-u', 'cyberxp-dashboard', '-n', '20', '--no-pager'])
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def analyze_threat():
    """Analyze a threat using CyberLLM-Agent"""
    clear_screen()
    print_header()
    print_section("AI Threat Analysis", "🔍")
    print()
    
    # Check if CyberLLM is installed
    if not os.path.exists('/opt/cyberxp-ai/src/cyber_agent_vec.py'):
        print(f"{Colors.RED}CyberLLM-Agent not installed{Colors.END}")
        print()
        print("To install:")
        print(f"  {Colors.GREEN}sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh{Colors.END}")
        print()
        input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")
        return
    
    print("Enter threat description (or 'q' to cancel):")
    print()
    threat = input(f"{Colors.BOLD}Threat: {Colors.END}").strip()
    
    if threat.lower() == 'q' or not threat:
        return
    
    print()
    print(f"{Colors.YELLOW}⏳ Analyzing threat...{Colors.END}")
    print(f"{Colors.DIM}This may take 30-60 seconds (faster with GPU){Colors.END}")
    print(f"{Colors.DIM}Please wait...{Colors.END}")
    print()
    
    try:
        result = subprocess.run(
            ['cyberxp-analyze', threat],
            capture_output=True,
            text=True,
            timeout=120  # Increased to 2 minutes
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}Analysis failed{Colors.END}")
            print(result.stderr)
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Analysis timeout (>2 minutes){Colors.END}")
        print()
        print(f"{Colors.YELLOW}💡 The AI is running but very slow.{Colors.END}")
        print(f"  • Try shorter threat descriptions")
        print(f"  • Increase VM resources (8GB RAM, 4+ CPUs)")
        print(f"  • Install NVIDIA drivers for GPU acceleration")
    except FileNotFoundError:
        print(f"{Colors.RED}cyberxp-analyze command not found{Colors.END}")
        print("Run: sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
    except Exception as e:
        print(f"{Colors.RED}Error: {str(e)}{Colors.END}")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def main():
    """Main dashboard loop"""
    try:
        # Check if running in terminal
        if not sys.stdout.isatty():
            print("Error: This script must be run in an interactive terminal")
            sys.exit(1)
        
        while True:
            display_dashboard()
            
            # Wait for input with timeout
            import select
            i, o, e = select.select([sys.stdin], [], [], 5)
            
            if i:
                key = sys.stdin.read(1)
                if key.lower() == 'q':
                    clear_screen()
                    print(f"{Colors.GREEN}Goodbye!{Colors.END}")
                    break
                elif key.lower() == 'r':
                    continue
                elif key.lower() == 'h':
                    show_ai_assistant()
                elif key.lower() == 's':
                    show_service_menu()
                elif key.lower() == 'l':
                    show_logs()
                elif key.lower() == 'a':
                    analyze_threat()
    
    except KeyboardInterrupt:
        clear_screen()
        print(f"\n{Colors.GREEN}Goodbye!{Colors.END}")
        sys.exit(0)

if __name__ == '__main__':
    main()
