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

def get_firewall_status():
    """Get firewall (ufw) status"""
    try:
        result = subprocess.run(['sudo', '-n', 'ufw', 'status'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            output = result.stdout.lower()
            if 'status: active' in output:
                # Count rules
                rules = len([line for line in result.stdout.split('\n') if line.strip() and not line.startswith('Status') and not line.startswith('To') and not line.startswith('-')])
                return {'active': True, 'rules': max(0, rules - 1)}
            else:
                return {'active': False, 'rules': 0}
    except:
        pass
    return {'active': False, 'rules': 0}

def get_open_ports():
    """Get count of listening ports"""
    try:
        result = subprocess.run(['ss', '-tuln'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            # Count LISTEN states
            listening = len([line for line in lines if 'LISTEN' in line])
            return listening
    except:
        pass
    return 0

def get_failed_logins():
    """Get recent failed login attempts"""
    try:
        # Try to read auth.log for failed attempts
        result = subprocess.run(['sudo', '-n', 'grep', '-c', 'Failed password', '/var/log/auth.log'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            return int(result.stdout.strip())
    except:
        pass
    return 0

def get_security_updates():
    """Check for security updates"""
    try:
        # Check for updates without updating cache (faster)
        result = subprocess.run(['apt', 'list', '--upgradable'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            # Filter security updates
            security = len([line for line in lines if 'security' in line.lower()])
            total = max(0, len(lines) - 1)  # Exclude header
            return {'security': security, 'total': total}
    except:
        pass
    return {'security': 0, 'total': 0}

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
    
    # Get security stats
    firewall = get_firewall_status()
    open_ports = get_open_ports()
    failed_logins = get_failed_logins()
    security_updates = get_security_updates()
    
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
    
    # Security Status Section
    print(f"\n{Colors.BOLD}🔒 SECURITY & FIREWALL{Colors.END}")
    print(f"{'─' * 65}")
    
    # Firewall Status
    if firewall['active']:
        fw_status = f"{Colors.GREEN}● ACTIVE{Colors.END}"
        fw_icon = "🟢"
    else:
        fw_status = f"{Colors.RED}● INACTIVE{Colors.END}"
        fw_icon = "🔴"
    
    print(f"{fw_icon} {Colors.BOLD}Firewall:{Colors.END} {fw_status}  {Colors.DIM}|{Colors.END}  {Colors.CYAN}Rules:{Colors.END} {firewall['rules']}")
    
    # Open Ports
    port_color = Colors.GREEN if open_ports < 10 else (Colors.YELLOW if open_ports < 20 else Colors.RED)
    print(f"🔌 {Colors.BOLD}Open Ports:{Colors.END} {port_color}{open_ports}{Colors.END}  {Colors.DIM}|{Colors.END}  ", end='')
    
    # Failed Logins
    if failed_logins == 0:
        login_status = f"{Colors.GREEN}0 (Secure){Colors.END}"
        login_icon = "✓"
    elif failed_logins < 5:
        login_status = f"{Colors.YELLOW}{failed_logins} (Monitor){Colors.END}"
        login_icon = "⚠"
    else:
        login_status = f"{Colors.RED}{failed_logins} (Alert!){Colors.END}"
        login_icon = "⚠"
    
    print(f"{login_icon} {Colors.BOLD}Failed Logins:{Colors.END} {login_status}")
    
    # Security Updates
    if security_updates['security'] > 0:
        update_status = f"{Colors.RED}{security_updates['security']} critical{Colors.END}"
        update_icon = "⚠"
    elif security_updates['total'] > 0:
        update_status = f"{Colors.YELLOW}{security_updates['total']} available{Colors.END}"
        update_icon = "📦"
    else:
        update_status = f"{Colors.GREEN}Up to date{Colors.END}"
        update_icon = "✓"
    
    print(f"{update_icon} {Colors.BOLD}Updates:{Colors.END} {update_status}")
    
    # Security Score (simple calculation)
    security_score = 0
    if firewall['active']:
        security_score += 40
    if failed_logins < 5:
        security_score += 30
    if security_updates['security'] == 0:
        security_score += 20
    if open_ports < 15:
        security_score += 10
    
    # Security score bar
    score_color = Colors.GREEN if security_score >= 80 else (Colors.YELLOW if security_score >= 60 else Colors.RED)
    score_label = "EXCELLENT" if security_score >= 80 else ("GOOD" if security_score >= 60 else "NEEDS ATTENTION")
    
    print(f"\n{Colors.BOLD}Security Score:{Colors.END} {score_color}{security_score}/100{Colors.END} {Colors.DIM}({score_label}){Colors.END}")
    filled = int(30 * security_score / 100)
    bar = '█' * filled + '░' * (30 - filled)
    print(f"[{score_color}{bar}{Colors.END}]")
    
    # Footer
    print(f"\n{'─' * 65}")
    print(f"{Colors.GREEN}h{Colors.END}-Help {Colors.GREEN}a{Colors.END}-AI {Colors.GREEN}s{Colors.END}-Services {Colors.GREEN}l{Colors.END}-Logs {Colors.GREEN}q{Colors.END}-Quit {Colors.DIM}| Auto-refresh: 5s{Colors.END}")

def show_ai_assistant():
    """Show AI help menu"""
    clear_screen()
    
    # Check if AI is installed
    # Check if CyberLLM-Agent is installed (check for actual script)
    ai_installed = os.path.exists('/opt/cyberxp-ai/src/cyber_agent_vec.py') and os.path.exists('/usr/local/bin/cyberxp-analyze')
    
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
    """Delegate to AI agent for system troubleshooting"""
    clear_screen()
    print(f"{Colors.BOLD}{Colors.CYAN}🔧 System Troubleshooting{Colors.END}")
    print()
    print(f"{Colors.YELLOW}This will use AI agent to investigate system health and security.{Colors.END}")
    print()
    print(f"{Colors.BOLD}Choose troubleshooting mode:{Colors.END}")
    print(f"  1. {Colors.GREEN}Simple{Colors.END} - Quick check (firewall, logins, updates, SSH) - ~2-3 min")
    print(f"  2. {Colors.CYAN}Full{Colors.END} - Complete diagnostic (all checks) - ~5-10 min")
    print()
    print(f"{Colors.BOLD}Select mode (1/2) or 'q' to quit: {Colors.END}", end='')
    mode_choice = input().strip().lower()
    
    if mode_choice == 'q':
        input(f"\n{Colors.BOLD}Press Enter to continue...{Colors.END}")
        return
    
    simple_mode = (mode_choice == '1')
    
    if not simple_mode and mode_choice != '2':
        print(f"{Colors.YELLOW}Invalid choice. Using full mode.{Colors.END}")
        simple_mode = False
    
    # Ask about auto-fix
    print()
    print(f"{Colors.BOLD}Auto-fix mode:{Colors.END}")
    print(f"  {Colors.GREEN}Yes{Colors.END} - Automatically fix issues without prompting")
    print(f"  {Colors.YELLOW}No{Colors.END} - Prompt before each fix (recommended)")
    print()
    print(f"{Colors.BOLD}Enable auto-fix? (y/n): {Colors.END}", end='')
    auto_fix = input().strip().lower() in ['y', 'yes']
    
    print()
    if simple_mode:
        print(f"{Colors.YELLOW}⏳ AI agent running quick diagnostic...{Colors.END}")
        cmd = ['cyberxp-analyze', '--status', '--simple']
        timeout = 180  # 3 minutes
    else:
        print(f"{Colors.YELLOW}⏳ AI agent running complete diagnostic...{Colors.END}")
        cmd = ['cyberxp-analyze', '--status']
        timeout = 600  # 10 minutes
    
    if auto_fix:
        cmd.append('--auto')
        print(f"{Colors.GREEN}✓ Auto-fix enabled - issues will be fixed automatically{Colors.END}")
    
    print()
    
    # Let the agent do all the work - it has tools to check everything
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"{Colors.RED}AI analysis failed{Colors.END}")
            if result.stderr:
                print(result.stderr)
            print()
            print(f"{Colors.YELLOW}Try manually:{Colors.END}")
            print(f"  cyberxp-analyze --status")
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Timeout. Try again later.{Colors.END}")
    except FileNotFoundError:
        print(f"{Colors.YELLOW}AI not configured. Install with:{Colors.END}")
        print(f"  sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
    except Exception as e:
        print(f"{Colors.RED}Error: {str(e)}{Colors.END}")
    
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
                    analyze_threat()
    
    except KeyboardInterrupt:
        clear_screen()
        print(f"\n{Colors.GREEN}Goodbye!{Colors.END}")
        sys.exit(0)

if __name__ == '__main__':
    main()
