#!/usr/bin/env python3
"""
CyberXP-OS Terminal Dashboard
Lightweight terminal-based system status monitor
"""

import os
import sys
import time
import subprocess
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
            'percent': f"{percent:.1f}%"
        }
    except:
        return {'total': 'unknown', 'used': 'unknown', 'percent': 'unknown'}

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
                'percent': parts[4]
            }
    except:
        pass
    return {'total': 'unknown', 'used': 'unknown', 'available': 'unknown', 'percent': 'unknown'}

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
        
        # Get CPU usage (simple approximation)
        with open('/proc/stat', 'r') as f:
            cpu_line = f.readline()
            cpu_times = [int(x) for x in cpu_line.split()[1:]]
            total_time = sum(cpu_times)
            idle_time = cpu_times[3]
            
        return {
            'model': cpu_model[:50] + '...' if len(cpu_model) > 50 else cpu_model,
            'cores': cpu_count,
            'usage': f"{((total_time - idle_time) / total_time * 100):.1f}%"
        }
    except:
        return {'model': 'unknown', 'cores': 'unknown', 'usage': 'unknown'}

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

def print_header():
    """Print dashboard header"""
    print(f"{Colors.BOLD}{Colors.CYAN}╔═══════════════════════════════════════════════════════════════════╗{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}  {Colors.BOLD}🛡️  CyberXP-OS Terminal Dashboard{Colors.END}                              {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}  {Colors.BLUE}AI-Powered Security Analysis Platform{Colors.END}                       {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}╚═══════════════════════════════════════════════════════════════════╝{Colors.END}")
    print()

def print_section(title):
    """Print section header"""
    print(f"{Colors.BOLD}{Colors.YELLOW}▶ {title}{Colors.END}")
    print(f"{Colors.YELLOW}{'─' * 70}{Colors.END}")

def print_metric(label, value, status=None):
    """Print a metric with optional status indicator"""
    status_icon = ""
    if status == "good":
        status_icon = f"{Colors.GREEN}✓{Colors.END}"
    elif status == "warn":
        status_icon = f"{Colors.YELLOW}⚠{Colors.END}"
    elif status == "error":
        status_icon = f"{Colors.RED}✗{Colors.END}"
    
    print(f"  {Colors.BOLD}{label:.<30}{Colors.END} {value} {status_icon}")

def display_dashboard():
    """Display the main dashboard"""
    clear_screen()
    
    # Header
    print_header()
    
    # System Information
    print_section("System Information")
    hostname = get_hostname()
    uptime = get_uptime()
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    print_metric("Hostname", hostname)
    print_metric("Uptime", uptime)
    print_metric("Current Time", timestamp)
    print()
    
    # CPU Information
    print_section("CPU")
    cpu = get_cpu_info()
    print_metric("Model", cpu['model'])
    print_metric("Cores", str(cpu['cores']))
    print_metric("Usage", cpu['usage'])
    print()
    
    # Memory Information
    print_section("Memory")
    mem = get_memory_info()
    mem_percent = float(mem['percent'].rstrip('%'))
    mem_status = "good" if mem_percent < 80 else "warn" if mem_percent < 90 else "error"
    
    print_metric("Total", mem['total'])
    print_metric("Used", mem['used'])
    print_metric("Usage", mem['percent'], mem_status)
    print()
    
    # Disk Information
    print_section("Disk Usage (/)")
    disk = get_disk_info()
    disk_percent = float(disk['percent'].rstrip('%'))
    disk_status = "good" if disk_percent < 80 else "warn" if disk_percent < 90 else "error"
    
    print_metric("Total", disk['total'])
    print_metric("Used", disk['used'])
    print_metric("Available", disk['available'])
    print_metric("Usage", disk['percent'], disk_status)
    print()
    
    # Network Information
    print_section("Network")
    net = get_network_info()
    print_metric("IP Address", net['ip'])
    print_metric("Active Interfaces", net['interfaces'])
    print_metric("Load Average (1/5/15)", get_load_average())
    print()
    
    # Services Status
    print_section("Services")
    services = [
        ('cyberxp-dashboard', 'CyberXP Dashboard'),
        ('ssh', 'SSH Server'),
        ('ufw', 'Firewall'),
    ]
    
    for service_name, display_name in services:
        is_active = get_service_status(service_name)
        status = f"{Colors.GREEN}Running{Colors.END}" if is_active else f"{Colors.RED}Stopped{Colors.END}"
        status_icon = "good" if is_active else "error"
        print_metric(display_name, status, status_icon)
    print()
    
    # Footer
    print(f"{Colors.CYAN}{'─' * 70}{Colors.END}")
    print(f"{Colors.BOLD}Commands:{Colors.END}")
    print(f"  {Colors.GREEN}q{Colors.END} - Quit")
    print(f"  {Colors.GREEN}r{Colors.END} - Refresh")
    print(f"  {Colors.GREEN}s{Colors.END} - Service management")
    print(f"  {Colors.GREEN}l{Colors.END} - View logs")
    print(f"  {Colors.GREEN}a{Colors.END} - AI threat analysis")
    print()
    print(f"{Colors.CYAN}Auto-refresh in 5 seconds... (Press any key to refresh now){Colors.END}")

def show_service_menu():
    """Show service management menu"""
    clear_screen()
    print_header()
    print_section("Service Management")
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
    print_section("Recent Logs (Last 20 lines)")
    print()
    subprocess.run(['journalctl', '-u', 'cyberxp-dashboard', '-n', '20', '--no-pager'])
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def analyze_threat():
    """Analyze a threat using CyberLLM-Agent"""
    clear_screen()
    print_header()
    print_section("AI Threat Analysis")
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
    print(f"{Colors.YELLOW}Analyzing... (this may take 5-10 seconds){Colors.END}")
    print()
    
    try:
        result = subprocess.run(
            ['cyberxp-analyze', threat],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}Analysis failed{Colors.END}")
            print(result.stderr)
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Analysis timeout (>30s){Colors.END}")
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
