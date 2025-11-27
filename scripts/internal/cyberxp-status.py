#!/usr/bin/env python3
"""
CyberXP-OS Terminal Dashboard - Sampler Style
Beautiful ASCII-art dashboard with progress bars and graphs
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
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    END = '\033[0m'

def clear_screen():
    """Clear terminal screen"""
    os.system('clear' if os.name == 'posix' else 'cls')

def get_cpu_usage():
    """Get CPU usage percentage"""
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
            fields = line.split()
            idle = int(fields[4])
            total = sum(int(x) for x in fields[1:])
            time.sleep(0.1)
        
        with open('/proc/stat', 'r') as f:
            line = f.readline()
            fields = line.split()
            idle2 = int(fields[4])
            total2 = sum(int(x) for x in fields[1:])
        
        idle_delta = idle2 - idle
        total_delta = total2 - total
        usage = 100.0 * (1.0 - idle_delta / total_delta)
        return usage
    except:
        return 0.0

def get_memory_usage():
    """Get memory usage"""
    try:
        meminfo = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    meminfo[parts[0].strip()] = int(parts[1].strip().split()[0])
        
        total = meminfo.get('MemTotal', 0)
        available = meminfo.get('MemAvailable', 0)
        used = total - available
        percent = (used / total * 100) if total > 0 else 0
        
        return {
            'used_mb': used // 1024,
            'total_mb': total // 1024,
            'percent': percent
        }
    except:
        return {'used_mb': 0, 'total_mb': 0, 'percent': 0}

def get_gpu_usage():
    """Get GPU usage if NVIDIA GPU available"""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total', '--format=csv,noheader,nounits'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            parts = result.stdout.strip().split(',')
            return {
                'available': True,
                'usage': float(parts[0].strip()),
                'mem_used': int(parts[1].strip()),
                'mem_total': int(parts[2].strip())
            }
    except:
        pass
    return {'available': False, 'usage': 0, 'mem_used': 0, 'mem_total': 0}

def get_disk_usage():
    """Get disk usage"""
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            return {
                'used': parts[2],
                'total': parts[1],
                'percent': float(parts[4].rstrip('%'))
            }
    except:
        pass
    return {'used': '0G', 'total': '0G', 'percent': 0}

def draw_progress_bar(percent, width=40, label="", color=Colors.CYAN):
    """Draw a progress bar with label"""
    filled = int(width * percent / 100)
    bar = '█' * filled + '░' * (width - filled)
    
    # Color based on percentage
    if percent > 90:
        bar_color = Colors.RED
    elif percent > 70:
        bar_color = Colors.YELLOW
    else:
        bar_color = color
    
    return f"{label:.<20} [{bar_color}{bar}{Colors.END}] {percent:>5.1f}%"

def draw_cpu_graph(usage, width=30, height=10):
    """Draw ASCII CPU usage graph"""
    bars = []
    bar_height = int((usage / 100) * height)
    
    for i in range(height, 0, -1):
        if i <= bar_height:
            bars.append(f"{Colors.BLUE}{'█' * width}{Colors.END}")
        else:
            bars.append(f"{Colors.DIM}{'░' * width}{Colors.END}")
    
    return '\n'.join(bars)

def draw_memory_graph(percent, width=30, height=10):
    """Draw ASCII memory usage graph"""
    bars = []
    bar_height = int((percent / 100) * height)
    
    for i in range(height, 0, -1):
        if i <= bar_height:
            bars.append(f"{Colors.MAGENTA}{'█' * width}{Colors.END}")
        else:
            bars.append(f"{Colors.DIM}{'░' * width}{Colors.END}")
    
    return '\n'.join(bars)

def draw_big_clock():
    """Draw large ASCII clock"""
    now = datetime.now()
    time_str = now.strftime("%H:%M:%S")
    
    # ASCII art numbers (simplified)
    digits = {
        '0': ['███', '█ █', '█ █', '█ █', '███'],
        '1': [' █ ', '██ ', ' █ ', ' █ ', '███'],
        '2': ['███', '  █', '███', '█  ', '███'],
        '3': ['███', '  █', '███', '  █', '███'],
        '4': ['█ █', '█ █', '███', '  █', '  █'],
        '5': ['███', '█  ', '███', '  █', '███'],
        '6': ['███', '█  ', '███', '█ █', '███'],
        '7': ['███', '  █', '  █', '  █', '  █'],
        '8': ['███', '█ █', '███', '█ █', '███'],
        '9': ['███', '█ █', '███', '  █', '███'],
        ':': [' ', '█', ' ', '█', ' ']
    }
    
    lines = ['', '', '', '', '']
    for char in time_str:
        if char in digits:
            for i, line in enumerate(digits[char]):
                lines[i] += line + ' '
    
    result = []
    for line in lines:
        result.append(f"{Colors.CYAN}{line}{Colors.END}")
    
    return '\n'.join(result)

def display_dashboard():
    """Display the main dashboard"""
    clear_screen()
    
    # Get system stats
    cpu = get_cpu_usage()
    mem = get_memory_usage()
    gpu = get_gpu_usage()
    disk = get_disk_usage()
    
    # Compact Header
    print(f"{Colors.BOLD}{Colors.CYAN}╔═══════════════════════════════════════════════════════════════╗{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}║{Colors.END}  {Colors.BOLD}{Colors.GREEN}🛡️  CyberXP-OS{Colors.END} {Colors.BOLD}{Colors.BLUE}Security Platform{Colors.END}                   {Colors.BOLD}{Colors.CYAN}║{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}╚═══════════════════════════════════════════════════════════════╝{Colors.END}")
    
    # Current time (compact)
    now = datetime.now().strftime("%H:%M:%S")
    print(f"\n{Colors.BOLD}TIME:{Colors.END} {Colors.CYAN}{now}{Colors.END}  {Colors.DIM}|{Colors.END}  {Colors.BOLD}SYSTEM HEALTH{Colors.END}")
    print(f"{'─' * 65}")
    
    # Progress bars (compact - 35 width)
    print(draw_progress_bar(cpu, width=35, label="CPU", color=Colors.BLUE))
    print(draw_progress_bar(mem['percent'], width=35, label="RAM", color=Colors.MAGENTA))
    print(draw_progress_bar(disk['percent'], width=35, label="DISK", color=Colors.YELLOW))
    
    if gpu['available']:
        print(draw_progress_bar(gpu['usage'], width=35, label="GPU", color=Colors.GREEN))
    
    # Compact stats
    print(f"\n{Colors.BOLD}DETAILS{Colors.END}")
    print(f"{'─' * 65}")
    print(f"{Colors.BLUE}CPU:{Colors.END} {cpu:.1f}% ({os.cpu_count()} cores)  {Colors.DIM}|{Colors.END}  {Colors.MAGENTA}RAM:{Colors.END} {mem['used_mb']}MB/{mem['total_mb']}MB")
    print(f"{Colors.YELLOW}DISK:{Colors.END} {disk['used']}/{disk['total']}  {Colors.DIM}|{Colors.END}  ", end='')
    
    if gpu['available']:
        print(f"{Colors.GREEN}GPU:{Colors.END} {gpu['usage']:.1f}% ({gpu['mem_used']}MB/{gpu['mem_total']}MB)")
    else:
        print(f"{Colors.DIM}GPU: N/A{Colors.END}")
    
    # Footer
    print(f"\n{'─' * 65}")
    print(f"{Colors.GREEN}h{Colors.END}-Help {Colors.GREEN}a{Colors.END}-AI {Colors.GREEN}s{Colors.END}-Services {Colors.GREEN}l{Colors.END}-Logs {Colors.GREEN}q{Colors.END}-Quit {Colors.DIM}| Auto-refresh: 5s{Colors.END}")

def show_ai_assistant():
    """Show AI help menu"""
    clear_screen()
    
    # Check if AI is installed
    ai_installed = os.path.exists('/opt/cyberxp-ai') or os.path.exists('/usr/local/bin/cyberxp-analyze')
    
    print(f"{Colors.BOLD}{Colors.CYAN}🤖 AI Assistant{Colors.END}")
    print()
    
    if not ai_installed:
        print(f"{Colors.YELLOW}AI not installed yet.{Colors.END}")
        print()
        print("To install AI capabilities:")
        print(f"  {Colors.GREEN}sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh{Colors.END}")
        print()
        print("Or reinstall with AI:")
        print(f"  {Colors.GREEN}sudo ./scripts/install.sh{Colors.END}")
        print("  Choose option 2 (Dashboard + AI)")
        print()
        input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")
        return
    
    print(f"{Colors.GREEN}✓ AI Available{Colors.END}")
    print()
    print("1 - Troubleshoot system issues")
    print("2 - Explain error message")
    print("3 - Service management help")
    print("4 - Security best practices")
    print("5 - Ask AI anything (custom query)")
    print("6 - Threat analysis")
    print("b - Back to dashboard")
    print()
    
    choice = input(f"{Colors.BOLD}Choice: {Colors.END}").strip()
    
    if choice == 'b':
        return
    elif choice == '1':
        troubleshoot_issues()
    elif choice == '2':
        explain_error()
    elif choice == '3':
        service_help()
    elif choice == '4':
        security_tips()
    elif choice == '5':
        custom_ai_query()
    elif choice == '6':
        analyze_threat()

def troubleshoot_issues():
    """Provide troubleshooting guidance"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}🔧 System Troubleshooting{Colors.END}")
    print()
    print(f"{Colors.YELLOW}Analyzing system...{Colors.END}")
    print()
    
    # Simple issue detection
    mem = get_memory_usage()
    disk = get_disk_usage()
    
    issues_found = False
    
    if mem['percent'] > 90:
        issues_found = True
        print(f"{Colors.RED}● High memory usage: {mem['percent']:.1f}%{Colors.END}")
        print(f"  Solution: Check processes with 'htop' and kill heavy ones")
        print()
    
    if disk['percent'] > 90:
        issues_found = True
        print(f"{Colors.RED}● Disk almost full: {disk['percent']:.1f}%{Colors.END}")
        print(f"  Solution: Clean up with 'sudo apt clean && sudo apt autoremove'")
        print()
    
    if not issues_found:
        print(f"{Colors.GREEN}✓ No critical issues detected!{Colors.END}")
        print()
    
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def explain_error():
    """Explain error messages"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}📝 Error Explanation{Colors.END}")
    print()
    print("Paste your error message (or 'q' to cancel):")
    print()
    error = input(f"{Colors.BOLD}Error: {Colors.END}").strip()
    
    if error.lower() == 'q' or not error:
        return
    
    print()
    print(f"{Colors.YELLOW}Analyzing...{Colors.END}")
    print()
    
    # Common error patterns
    if 'permission denied' in error.lower():
        print(f"{Colors.BOLD}Explanation:{Colors.END} Insufficient permissions")
        print(f"{Colors.BOLD}Solution:{Colors.END} Try with sudo: sudo <command>")
    elif 'command not found' in error.lower():
        print(f"{Colors.BOLD}Explanation:{Colors.END} Command not installed")
        print(f"{Colors.BOLD}Solution:{Colors.END} Install package or check spelling")
    elif 'no space left' in error.lower():
        print(f"{Colors.BOLD}Explanation:{Colors.END} Disk is full")
        print(f"{Colors.BOLD}Solution:{Colors.END} Free space: sudo apt clean && sudo apt autoremove")
    else:
        print(f"{Colors.YELLOW}Error not in database. Try Google or check logs.{Colors.END}")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def service_help():
    """Service management help"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}⚙️ Service Management Guide{Colors.END}")
    print()
    print(f"{Colors.BOLD}Common Commands:{Colors.END}")
    print()
    print(f"  Start:   {Colors.GREEN}sudo systemctl start <service>{Colors.END}")
    print(f"  Stop:    {Colors.GREEN}sudo systemctl stop <service>{Colors.END}")
    print(f"  Restart: {Colors.GREEN}sudo systemctl restart <service>{Colors.END}")
    print(f"  Status:  {Colors.GREEN}sudo systemctl status <service>{Colors.END}")
    print(f"  Enable:  {Colors.GREEN}sudo systemctl enable <service>{Colors.END}")
    print(f"  Logs:    {Colors.GREEN}sudo journalctl -u <service> -f{Colors.END}")
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def security_tips():
    """Security best practices"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}🔒 Security Best Practices{Colors.END}")
    print()
    print("1. Change default passwords")
    print("2. Enable firewall: sudo ufw enable")
    print("3. Keep system updated: sudo apt update && sudo apt upgrade")
    print("4. Monitor logs: sudo journalctl -f")
    print("5. Use SSH keys instead of passwords")
    print("6. Disable root login via SSH")
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def custom_ai_query():
    """Custom AI query"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}🤖 Ask AI Anything{Colors.END}")
    print()
    print("What would you like to know? (or 'q' to cancel)")
    print()
    query = input(f"{Colors.BOLD}Question: {Colors.END}").strip()
    
    if query.lower() == 'q' or not query:
        return
    
    print()
    print(f"{Colors.YELLOW}⏳ Processing...{Colors.END}")
    print(f"{Colors.DIM}This may take 30-60 seconds on CPU{Colors.END}")
    print()
    
    try:
        result = subprocess.run(
            ['cyberxp-analyze', query],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}Query failed{Colors.END}")
            print(result.stderr)
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Timeout (>2 min). Try shorter query.{Colors.END}")
    except FileNotFoundError:
        print(f"{Colors.RED}AI not configured. Run:{Colors.END}")
        print(f"  sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
    except Exception as e:
        print(f"{Colors.RED}Error: {str(e)}{Colors.END}")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def analyze_threat():
    """Analyze threat"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 Threat Analysis{Colors.END}")
    print()
    print("Describe the threat (or 'q' to cancel):")
    print()
    threat = input(f"{Colors.BOLD}Threat: {Colors.END}").strip()
    
    if threat.lower() == 'q' or not threat:
        return
    
    print()
    print(f"{Colors.YELLOW}⏳ Analyzing...{Colors.END}")
    print(f"{Colors.DIM}This may take 30-60 seconds{Colors.END}")
    print()
    
    try:
        result = subprocess.run(
            ['cyberxp-analyze', threat],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}Analysis failed{Colors.END}")
            print(result.stderr)
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Timeout. Try shorter description.{Colors.END}")
    except FileNotFoundError:
        print(f"{Colors.RED}AI not configured{Colors.END}")
    except Exception as e:
        print(f"{Colors.RED}Error: {str(e)}{Colors.END}")
    
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def show_services():
    """Show service management"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}⚙️  Service Management{Colors.END}")
    print()
    print("1 - Start CyberXP Dashboard")
    print("2 - Stop CyberXP Dashboard")
    print("3 - Restart CyberXP Dashboard")
    print("4 - View Status")
    print("b - Back")
    print()
    
    choice = input(f"{Colors.BOLD}Choice: {Colors.END}").strip()
    
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
    """Show logs"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}📄 System Logs{Colors.END}")
    print()
    subprocess.run(['journalctl', '-u', 'cyberxp-dashboard', '-n', '20', '--no-pager'])
    print()
    input(f"{Colors.BOLD}Press Enter to continue...{Colors.END}")

def main():
    """Main loop"""
    try:
        if not sys.stdout.isatty():
            print("Error: Must run in interactive terminal")
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
                    show_services()
                elif key.lower() == 'l':
                    show_logs()
                elif key.lower() == 'a':
                    print(f"\n{Colors.YELLOW}AI analysis requires full installation{Colors.END}")
                    time.sleep(2)
    
    except KeyboardInterrupt:
        clear_screen()
        print(f"\n{Colors.GREEN}Goodbye!{Colors.END}")
        sys.exit(0)

if __name__ == '__main__':
    main()
