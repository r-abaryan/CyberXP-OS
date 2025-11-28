#!/usr/bin/env python3
"""
CyberXP LLM Host Bridge with LangChain Agents
Analyzes security threats and can execute recommended actions using AI agents
"""

import sys
import requests
import json
import subprocess
import threading
from datetime import datetime

# LangChain imports
try:
    from langchain.agents import AgentExecutor, create_openai_functions_agent
    from langchain.tools import Tool
    from langchain.prompts import ChatPromptTemplate, MessagesPlaceholder
    from langchain_core.language_models.llms import LLM
    from langchain_core.callbacks import CallbackManagerForLLMRun
    from typing import Optional, List, Any
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("⚠️  LangChain not installed. Install with: pip install langchain langchain-core")
    print("   Falling back to basic mode...")

API_HOST = "10.0.2.2"  # VirtualBox NAT host IP
API_PORT = 5000
API_URL = f"http://{API_HOST}:{API_PORT}"

def execute_command(command, description):
    """Execute security command with logging"""
    print(f"\n🔧 Executing: {description}")
    print(f"   Command: {command}")
    
    # Log action
    log_entry = f"[{datetime.now()}] {description}\nCommand: {command}\n"
    try:
        with open('/var/log/cyberxp-actions.log', 'a') as f:
            f.write(log_entry)
    except:
        pass
    
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print(f"✅ Success")
            if result.stdout:
                print(f"   Output: {result.stdout.strip()}")
            return f"Success: {result.stdout.strip()}" if result.stdout else "Success"
        else:
            print(f"⚠️  Command returned code {result.returncode}")
            if result.stderr:
                print(f"   Error: {result.stderr.strip()}")
            return f"Error (code {result.returncode}): {result.stderr.strip()}" if result.stderr else f"Error: command failed with code {result.returncode}"
    except subprocess.TimeoutExpired:
        print("❌ Command timeout (>30s)")
        return "Error: Command timeout (>30s)"
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return f"Error: {str(e)}"

# LangChain Tools
def block_ip_tool(ip_address: str) -> str:
    """Block an IP address using firewall. Input: IP address (e.g., '192.168.1.100')"""
    cmd = f"sudo ufw deny from {ip_address} 2>&1 || sudo iptables -A INPUT -s {ip_address} -j DROP"
    return execute_command(cmd, f"Block IP: {ip_address}")

def check_logs_tool(service: str = "all") -> str:
    """Check system logs. Input: service name (e.g., 'ssh') or 'all' for all logs"""
    if service == "all":
        cmd = "sudo journalctl -n 50"
    else:
        cmd = f"sudo journalctl -u {service} -n 50"
    return execute_command(cmd, f"Check logs: {service}")

def stop_service_tool(service: str) -> str:
    """Stop a systemd service. Input: service name (e.g., 'ssh', 'apache2')"""
    cmd = f"sudo systemctl stop {service}"
    return execute_command(cmd, f"Stop service: {service}")

def check_connections_tool(port: str = "") -> str:
    """Check active network connections. Input: optional port number (e.g., '22') or empty for all"""
    if port:
        cmd = f"sudo netstat -tulpn | grep :{port}"
    else:
        cmd = "sudo netstat -tulpn"
    return execute_command(cmd, f"Check connections: {port or 'all'}")

def quarantine_file_tool(file_path: str) -> str:
    """Move a suspicious file to quarantine. Input: full file path"""
    cmd = f"sudo mkdir -p /tmp/quarantine && sudo mv {file_path} /tmp/quarantine/"
    return execute_command(cmd, f"Quarantine file: {file_path}")

# System health monitoring tools for agent
def get_cpu_usage_tool() -> str:
    """Get current CPU usage percentage. No input needed."""
    try:
        import time
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
        cpu = 100.0 * (1.0 - idle_delta / total_delta) if total_delta > 0 else 0
        return f"CPU Usage: {cpu:.1f}%"
    except Exception as e:
        return f"Error getting CPU: {str(e)}"

def get_memory_usage_tool() -> str:
    """Get current memory usage. No input needed."""
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
        return f"Memory: {used//1024}MB/{total//1024}MB ({percent:.1f}%)"
    except Exception as e:
        return f"Error getting memory: {str(e)}"

def get_disk_usage_tool() -> str:
    """Get disk usage for root partition. No input needed."""
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True, timeout=2)
        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            return f"Disk: {parts[2]}/{parts[1]} ({parts[4]})"
        return "Error: Could not parse disk usage"
    except Exception as e:
        return f"Error getting disk: {str(e)}"

def get_firewall_status_tool() -> str:
    """Get firewall (ufw) status. No input needed."""
    try:
        result = subprocess.run(['sudo', '-n', 'ufw', 'status'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            output = result.stdout.lower()
            if 'status: active' in output:
                rules = len([line for line in result.stdout.split('\n') 
                           if line.strip() and not line.startswith('Status') 
                           and not line.startswith('To') and not line.startswith('-')])
                return f"Firewall: ACTIVE ({max(0, rules-1)} rules)"
            else:
                return "Firewall: INACTIVE"
        return "Firewall: Status unknown"
    except Exception as e:
        return f"Error getting firewall: {str(e)}"

def get_open_ports_tool() -> str:
    """Get count of open/listening ports. No input needed."""
    try:
        result = subprocess.run(['ss', '-tuln'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            listening = len([line for line in lines if 'LISTEN' in line])
            return f"Open ports: {listening}"
        return "Error: Could not get port info"
    except Exception as e:
        return f"Error getting ports: {str(e)}"

def get_failed_logins_tool() -> str:
    """Get count of failed login attempts. No input needed."""
    try:
        result = subprocess.run(['sudo', '-n', 'grep', '-c', 'Failed password', '/var/log/auth.log'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            count = int(result.stdout.strip())
            return f"Failed logins: {count}"
        return "Failed logins: 0 (or log not accessible)"
    except Exception as e:
        return f"Error getting failed logins: {str(e)}"

def get_security_updates_tool() -> str:
    """Check for pending security updates. No input needed."""
    try:
        result = subprocess.run(['apt', 'list', '--upgradable'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            security = len([line for line in lines if 'security' in line.lower()])
            total = max(0, len(lines) - 1)
            return f"Security updates: {security} critical, {total} total"
        return "Security updates: Unknown"
    except Exception as e:
        return f"Error getting updates: {str(e)}"

def enable_firewall_tool() -> str:
    """Enable firewall (ufw). No input needed."""
    cmd = "sudo ufw enable"
    return execute_command(cmd, "Enable firewall")

def update_system_tool() -> str:
    """Update system packages (security updates). No input needed."""
    cmd = "sudo apt update && sudo apt upgrade -y"
    return execute_command(cmd, "Update system packages")

def check_ssh_config_tool() -> str:
    """Check SSH security configuration. No input needed."""
    issues = []
    try:
        # Check if SSH allows root login
        result = subprocess.run(['grep', '-i', '^PermitRootLogin', '/etc/ssh/sshd_config'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            if 'yes' in result.stdout.lower():
                issues.append("SSH allows root login (security risk)")
            else:
                issues.append("SSH root login: disabled (secure)")
        else:
            issues.append("SSH root login: default (may allow)")
        
        # Check if password authentication is enabled
        result = subprocess.run(['grep', '-i', '^PasswordAuthentication', '/etc/ssh/sshd_config'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            if 'yes' in result.stdout.lower():
                issues.append("SSH password authentication enabled (consider keys)")
            else:
                issues.append("SSH password auth: disabled (using keys - secure)")
        else:
            issues.append("SSH password auth: default (may allow)")
        
        # Check SSH service status
        result = subprocess.run(['systemctl', 'is-active', 'ssh'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            issues.append(f"SSH service: {result.stdout.strip()}")
        
        return "SSH Configuration:\n" + "\n".join(f"  - {issue}" for issue in issues) if issues else "SSH Configuration: OK"
    except Exception as e:
        return f"Error checking SSH config: {str(e)}"

def get_system_health():
    """Collect system health and security status"""
    health_data = {
        'cpu': 0.0,
        'memory': {'used_mb': 0, 'total_mb': 0, 'percent': 0},
        'disk': {'used': '0G', 'total': '0G', 'percent': 0},
        'firewall': {'active': False, 'rules': 0},
        'open_ports': 0,
        'failed_logins': 0,
        'security_updates': {'security': 0, 'total': 0}
    }
    
    # CPU usage
    try:
        import time
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
        health_data['cpu'] = 100.0 * (1.0 - idle_delta / total_delta) if total_delta > 0 else 0
    except:
        pass
    
    # Memory
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
        health_data['memory'] = {
            'used_mb': used // 1024,
            'total_mb': total // 1024,
            'percent': (used / total * 100) if total > 0 else 0
        }
    except:
        pass
    
    # Disk
    try:
        result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True, timeout=2)
        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            health_data['disk'] = {
                'used': parts[2],
                'total': parts[1],
                'percent': float(parts[4].rstrip('%'))
            }
    except:
        pass
    
    # Firewall
    try:
        result = subprocess.run(['sudo', '-n', 'ufw', 'status'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            output = result.stdout.lower()
            if 'status: active' in output:
                rules = len([line for line in result.stdout.split('\n') 
                           if line.strip() and not line.startswith('Status') 
                           and not line.startswith('To') and not line.startswith('-')])
                health_data['firewall'] = {'active': True, 'rules': max(0, rules - 1)}
    except:
        pass
    
    # Open ports
    try:
        result = subprocess.run(['ss', '-tuln'], capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            health_data['open_ports'] = len([line for line in lines if 'LISTEN' in line])
    except:
        pass
    
    # Failed logins
    try:
        result = subprocess.run(['sudo', '-n', 'grep', '-c', 'Failed password', '/var/log/auth.log'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            health_data['failed_logins'] = int(result.stdout.strip())
    except:
        pass
    
    # Security updates
    try:
        result = subprocess.run(['apt', 'list', '--upgradable'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            security = len([line for line in lines if 'security' in line.lower()])
            health_data['security_updates'] = {
                'security': security,
                'total': max(0, len(lines) - 1)
            }
    except:
        pass
    
    return health_data

def format_health_report(health):
    """Format health data as readable report"""
    report = f"""System Health Report:
══════════════════════════════════════════════════
CPU Usage: {health['cpu']:.1f}%
Memory: {health['memory']['used_mb']}MB/{health['memory']['total_mb']}MB ({health['memory']['percent']:.1f}%)
Disk: {health['disk']['used']}/{health['disk']['total']} ({health['disk']['percent']:.1f}%)

Security Status:
  Firewall: {'ACTIVE' if health['firewall']['active'] else 'INACTIVE'} ({health['firewall']['rules']} rules)
  Open Ports: {health['open_ports']}
  Failed Logins: {health['failed_logins']}
  Security Updates: {health['security_updates']['security']} critical, {health['security_updates']['total']} total

Issues Detected:"""
    
    issues = []
    if health['cpu'] > 90:
        issues.append(f"  ⚠️  High CPU usage: {health['cpu']:.1f}%")
    if health['memory']['percent'] > 90:
        issues.append(f"  ⚠️  High memory usage: {health['memory']['percent']:.1f}%")
    if health['disk']['percent'] > 90:
        issues.append(f"  ⚠️  Disk almost full: {health['disk']['percent']:.1f}%")
    if not health['firewall']['active']:
        issues.append("  ⚠️  Firewall is INACTIVE")
    if health['open_ports'] > 20:
        issues.append(f"  ⚠️  Many open ports: {health['open_ports']}")
    if health['failed_logins'] > 5:
        issues.append(f"  ⚠️  Multiple failed logins: {health['failed_logins']}")
    if health['security_updates']['security'] > 0:
        issues.append(f"  ⚠️  {health['security_updates']['security']} critical security updates pending")
    
    if not issues:
        report += "\n  ✓ No critical issues detected"
    else:
        report += "\n" + "\n".join(issues)
    
    return report

# Custom LLM wrapper for API
if LANGCHAIN_AVAILABLE:
    class CyberXPLLM(LLM):
        api_url: str = API_URL
        
        @property
        def _llm_type(self) -> str:
            return "cyberxp"
        
        def _call(
            self,
            prompt: str,
            stop: Optional[List[str]] = None,
            run_manager: Optional[CallbackManagerForLLMRun] = None,
            **kwargs: Any,
        ) -> str:
            try:
                # Shorter timeout for agent calls (they're decision prompts, not full analysis)
                # Full analysis uses 120s, but agent reasoning should be faster
                timeout = 60 if "system health" in prompt.lower() or "diagnostic" in prompt.lower() else 30
                response = requests.post(
                    f"{self.api_url}/generate",
                    json={"prompt": prompt},
                    timeout=timeout
                )
                if response.status_code == 200:
                    data = response.json()
                    return data.get('response', '')
                raise Exception(f"API error: {response.status_code}")
            except Exception as e:
                raise Exception(f"LLM API call failed: {str(e)}")

def analyze_system_health(simple_mode=False):
    """Let AI agent investigate system health using its tools"""
    print("🤖 AI Agent System Troubleshooting")
    print()
    
    if simple_mode:
        print("The agent will perform a QUICK security check (critical items only).")
        print("⚠️  If critical issues are found, you will be prompted for immediate action.")
    else:
        print("The agent will perform a COMPLETE security and health diagnostic.")
        print("⚠️  If critical issues are found, you will be prompted for immediate action.")
    print()
    
    # Ask user if they want AI to investigate
    print("Start system diagnostic? (y/n): ", end='')
    choice = input().strip().lower()
    
    if choice not in ['y', 'yes']:
        print("⏭️  Skipped")
        return
    
    print()
    if simple_mode:
        print("⏳ Agent running quick diagnostic...")
        print("   Checking: Firewall, failed logins, security updates, SSH config...")
    else:
        print("⏳ Agent running complete diagnostic...")
        print("   Checking: Firewall, ports, logins, updates, SSH, CPU, memory, disk...")
    print()
    
    # Simple mode: only critical security checks
    if simple_mode:
        threat_desc = """Perform a QUICK security diagnostic. Check these CRITICAL items:

CRITICAL SECURITY CHECKS (MANDATORY):
1. Firewall status - use get_firewall_status tool
2. Failed login attempts - use get_failed_logins tool
3. Security updates - use get_security_updates tool
4. SSH configuration - use check_ssh_config tool (check root login, password auth)

After gathering this data, analyze the results and:

IMMEDIATE ACTION REQUIRED if you find:
- Firewall is INACTIVE → This is CRITICAL, prompt user immediately
- Multiple failed logins (>5) → Possible attack, prompt user immediately
- Critical security updates pending → Prompt user to update immediately
- SSH allows root login → Security risk, prompt user immediately

PROCESS:
1. Check all 4 critical items first
2. Identify which issues require IMMEDIATE action
3. If immediate action needed, STOP and PROMPT USER: "⚠️ IMMEDIATE ACTION REQUIRED: [issue]. Would you like me to fix this now? (y/n)"
4. Wait for user approval before proceeding
5. After immediate actions, propose fixes for remaining issues

This is a quick check - focus on critical security only."""
    else:
        # Full mode: complete diagnostic
        threat_desc = """Perform a COMPLETE system security and health diagnostic. You MUST check ALL of the following:

CRITICAL SECURITY CHECKS (MANDATORY):
1. Firewall status - use get_firewall_status tool
2. Open ports count - use get_open_ports tool  
3. Failed login attempts - use get_failed_logins tool
4. Security updates - use get_security_updates tool
5. SSH configuration - use check_ssh_config tool (check root login, password auth)
6. Network connections - use check_connections tool
7. System logs - use check_logs tool for suspicious activity

SYSTEM HEALTH CHECKS (MANDATORY):
8. CPU usage - use get_cpu_usage tool
9. Memory usage - use get_memory_usage tool
10. Disk usage - use get_disk_usage tool

After gathering ALL this data (all 10 checks), analyze the results and:

IMMEDIATE ACTION REQUIRED if you find:
- Firewall is INACTIVE → This is CRITICAL, prompt user immediately
- Multiple failed logins (>5) → Possible attack, prompt user immediately
- Critical security updates pending → Prompt user to update immediately
- SSH allows root login → Security risk, prompt user immediately
- High CPU/Memory (>90%) → System may be compromised, prompt user immediately

PROCESS:
1. Check all 10 items first
2. Identify which issues require IMMEDIATE action
3. If immediate action needed, STOP and PROMPT USER: "⚠️ IMMEDIATE ACTION REQUIRED: [issue]. Would you like me to fix this now? (y/n)"
4. Wait for user approval before proceeding
5. After immediate actions, continue with other fixes
6. Propose fixes for ALL remaining issues
7. Prioritize critical security issues first

Do NOT skip any checks. This is a complete diagnostic. You must use all 10 tools listed above."""
    
    if LANGCHAIN_AVAILABLE:
        return run_agent_mode(threat_desc, auto_mode=False, simple_mode=simple_mode)
    else:
        print("⚠️  LangChain not available. Install with: pip install langchain langchain-core")
        print("   Falling back to basic analysis...")
        return run_original_mode(threat_desc, auto_mode=False)

def main():
    auto_mode = '--auto' in sys.argv or '-y' in sys.argv
    use_agent = '--agent' in sys.argv
    health_check = '--status' in sys.argv or '--health' in sys.argv
    simple_mode = '--simple' in sys.argv
    
    if '--auto' in sys.argv:
        sys.argv.remove('--auto')
    if '-y' in sys.argv:
        sys.argv.remove('-y')
    if '--agent' in sys.argv:
        sys.argv.remove('--agent')
    if '--status' in sys.argv:
        sys.argv.remove('--status')
    if '--health' in sys.argv:
        sys.argv.remove('--health')
    if '--simple' in sys.argv:
        sys.argv.remove('--simple')
    
    # Health check mode
    if health_check:
        return analyze_system_health(simple_mode=simple_mode)
    
    if len(sys.argv) < 2:
        print("Usage: cyberxp-analyze [OPTIONS] <threat_description>")
        print()
        print("Options:")
        print("  --auto, -y       Auto-execute recommended actions (no confirmation)")
        print("  --agent          Use LangChain agent for intelligent reasoning")
        print("  --status, --health  Analyze system health and propose fixes")
        print("  --simple              Quick troubleshooting (critical items only)")
        print()
        print("Examples:")
        print("  cyberxp-analyze 'Suspicious login from unknown IP 192.168.1.100'")
        print("  cyberxp-analyze --auto 'Multiple failed SSH attempts detected'")
        print("  cyberxp-analyze --agent 'Suspicious activity detected'")
        print("  cyberxp-analyze --status        # Full system diagnostic")
        print("  cyberxp-analyze --status --simple  # Quick security check")
        sys.exit(1)
    
    threat = ' '.join(sys.argv[1:])
    
    # Use LangChain agent if available and requested
    if use_agent and LANGCHAIN_AVAILABLE:
        return run_agent_mode(threat, auto_mode)
    elif use_agent and not LANGCHAIN_AVAILABLE:
        print("❌ Error: --agent requires LangChain. Install with: pip install langchain langchain-core")
        sys.exit(1)
    
    # Original mode (backward compatible)
    return run_original_mode(threat, auto_mode)

def run_agent_mode(threat, auto_mode, simple_mode=False):
    """Run with LangChain agent for intelligent reasoning"""
    print("🤖 Agent Mode: Using LangChain for intelligent threat response")
    print(f"   Threat: {threat}")
    print()
    
    # Create tools - agent can use these to gather data and take actions
    tools = [
        # Security actions
        Tool(name="block_ip", func=block_ip_tool, description="Block an IP address using firewall. Input: IP address as string"),
        Tool(name="check_logs", func=check_logs_tool, description="Check system logs. Input: service name (e.g., 'ssh') or 'all' for all logs"),
        Tool(name="stop_service", func=stop_service_tool, description="Stop a systemd service. Input: service name (e.g., 'ssh', 'apache2')"),
        Tool(name="check_connections", func=check_connections_tool, description="Check active network connections. Input: optional port number (e.g., '22') or empty for all"),
        Tool(name="quarantine_file", func=quarantine_file_tool, description="Move suspicious file to quarantine. Input: file path"),
        
        # System health monitoring tools
        Tool(name="get_cpu_usage", func=get_cpu_usage_tool, description="Get current CPU usage percentage. No input needed."),
        Tool(name="get_memory_usage", func=get_memory_usage_tool, description="Get current memory usage. No input needed."),
        Tool(name="get_disk_usage", func=get_disk_usage_tool, description="Get disk usage for root partition. No input needed."),
        Tool(name="get_firewall_status", func=get_firewall_status_tool, description="Get firewall (ufw) status. No input needed."),
        Tool(name="get_open_ports", func=get_open_ports_tool, description="Get count of open/listening ports. No input needed."),
        Tool(name="get_failed_logins", func=get_failed_logins_tool, description="Get count of failed login attempts. No input needed."),
        Tool(name="get_security_updates", func=get_security_updates_tool, description="Check for pending security updates. No input needed."),
        Tool(name="check_ssh_config", func=check_ssh_config_tool, description="Check SSH security configuration (root login, password auth). No input needed."),
        
        # System maintenance tools
        Tool(name="enable_firewall", func=enable_firewall_tool, description="Enable firewall (ufw). No input needed."),
        Tool(name="update_system", func=update_system_tool, description="Update system packages including security updates. No input needed."),
    ]
    
    # Create agent prompt
    prompt = ChatPromptTemplate.from_messages([
        ("system", """You are a cybersecurity analyst agent. Analyze threats and take appropriate actions.

Available tools:
Security Actions:
- block_ip: Block malicious IP addresses
- check_logs: Investigate system logs  
- stop_service: Stop compromised services
- check_connections: Monitor network connections
- quarantine_file: Isolate suspicious files

System Health Monitoring (use ALL for complete diagnostic):
- get_cpu_usage: Check CPU usage
- get_memory_usage: Check memory usage
- get_disk_usage: Check disk space
- get_firewall_status: Check firewall status (CRITICAL - check FIRST)
- get_open_ports: Count open/listening ports (CRITICAL)
- get_failed_logins: Count failed login attempts (CRITICAL - check FIRST)
- get_security_updates: Check for pending security updates (CRITICAL - check FIRST)
- check_ssh_config: Check SSH security configuration - root login, password auth (CRITICAL)
- check_connections: Check network connections
- check_logs: Check system logs for suspicious activity

System Maintenance:
- enable_firewall: Enable firewall (use if firewall is INACTIVE)
- update_system: Update system packages (use if security updates pending)

IMPORTANT: When performing system health diagnostics:
1. You MUST check ALL monitoring tools to get complete picture
2. Do NOT skip any checks - this is a comprehensive diagnostic
3. Check firewall, ports, failed logins, security updates, and SSH config FIRST (critical security)
4. Then check CPU, memory, disk (system health)
5. Review logs and connections if issues found
6. Analyze ALL results together

IMMEDIATE ACTION DETECTION:
- If firewall is INACTIVE → This is CRITICAL, STOP and PROMPT USER immediately
- If failed logins > 5 → Possible attack, STOP and PROMPT USER immediately  
- If critical security updates pending → STOP and PROMPT USER immediately
- If SSH allows root login → Security risk, STOP and PROMPT USER immediately
- If CPU/Memory > 90% → System may be compromised, STOP and PROMPT USER immediately

When you detect immediate action needed:
1. STOP your current process
2. Clearly state: "⚠️ IMMEDIATE ACTION REQUIRED: [specific issue]"
3. Explain why it's critical
4. Ask: "Would you like me to fix this now? (y/n)"
5. Wait for user response before continuing
6. If user approves, take action immediately
7. Then continue with remaining checks and fixes

After immediate actions (if any):
8. Propose fixes for ALL remaining issues
9. Prioritize critical security fixes first
10. For SSH issues: recommend disabling root login and password auth if enabled

For system health investigation, you MUST use all relevant monitoring tools.
For critical threats, act immediately. For suspicious but uncertain threats, investigate first."""),
        MessagesPlaceholder(variable_name="chat_history"),
        ("human", "{input}"),
        MessagesPlaceholder(variable_name="agent_scratchpad"),
    ])
    
    # Initialize LLM
    llm = CyberXPLLM()
    
    # Create agent using ReAct pattern
    # Adjust max_iterations based on mode
    if simple_mode:
        max_iters = 6  # Quick check: 4 critical items + 2 for analysis/actions
    elif "system health" in threat.lower() or "diagnostic" in threat.lower():
        max_iters = 12  # Full diagnostic: 10 checks + 2 for analysis/actions
    else:
        max_iters = 5  # Regular threat analysis
    
    try:
        from langchain.agents import initialize_agent, AgentType
        agent_executor = initialize_agent(
            tools=tools,
            llm=llm,
            agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
            verbose=not auto_mode,
            max_iterations=max_iters,
            handle_parsing_errors="Check your output and make sure it conforms!"
        )
    except ImportError:
        # Fallback for older LangChain versions
        from langchain.agents import AgentExecutor, create_react_agent
        from langchain import hub
        try:
            prompt_template = hub.pull("hwchase17/react")
        except:
            # Use default prompt if hub not available
            from langchain.agents import create_prompt
            prompt_template = create_prompt(tools)
        agent = create_react_agent(llm, tools, prompt_template)
        agent_executor = AgentExecutor(
            agent=agent,
            tools=tools,
            verbose=not auto_mode,
            max_iterations=max_iters,
            handle_parsing_errors="Check your output and make sure it conforms!"
        )
    
    # Execute with overall timeout (cross-platform)
    print("⏳ Agent analyzing and responding...")
    print("=" * 60)
    
    # Set overall timeout based on mode
    if simple_mode:
        timeout_seconds = 180  # 3 minutes for quick check
    elif "system health" in threat.lower() or "diagnostic" in threat.lower():
        timeout_seconds = 600  # 10 minutes for full diagnostic
    else:
        timeout_seconds = 180  # 3 minutes for threats
    print(f"⏱️  Timeout: {timeout_seconds // 60} minutes max")
    print()
    
    result_container = {"result": None, "error": None, "timeout": False}
    
    def run_agent():
        try:
            result_container["result"] = agent_executor.invoke({
                "input": f"Security threat: {threat}. Analyze and respond appropriately.",
                "chat_history": []
            })
        except Exception as e:
            result_container["error"] = e
    
    # Run agent in thread
    agent_thread = threading.Thread(target=run_agent, daemon=True)
    agent_thread.start()
    agent_thread.join(timeout=timeout_seconds)
    
    if agent_thread.is_alive():
        result_container["timeout"] = True
        print("\n" + "=" * 60)
        print("⏱️  Agent timeout (>{} min)".format(timeout_seconds // 60))
        print("   This may be due to:")
        print("   - Slow network (VirtualBox NAT)")
        print("   - LLM model taking too long")
        print("   - Too many tool calls ({} max iterations)".format(max_iters))
        print("\n💡 Try:")
        print("   - Check network connection to {}:{}".format(API_HOST, API_PORT))
        print("   - Verify llm-api-server.py is running on host")
        if not simple_mode:
            print("   - Use --simple flag for quicker check (critical items only)")
        print("   - Use --auto flag to skip confirmations")
        sys.exit(1)
    
    if result_container["error"]:
        print(f"\n❌ Error: {str(result_container['error'])}")
        sys.exit(1)
    
    if result_container["result"]:
        print("\n" + "=" * 60)
        print("✅ Agent analysis complete")
        print(f"\nResult: {result_container['result'].get('output', 'N/A')}")

def run_original_mode(threat, auto_mode):
    """Original mode: Get analysis from API and execute actions"""
    # Check API health
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        if response.status_code != 200:
            print("❌ Error: LLM API server not ready")
            print("Make sure llm-api-server.py is running on Windows host")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("❌ Error: Cannot connect to LLM API server")
        print(f"   Expected at: {API_URL}")
        print()
        print("Make sure:")
        print("  1. llm-api-server.py is running on Windows host")
        print("  2. Windows Firewall allows port 5000")
        print("  3. VirtualBox network is configured (NAT or Host-only)")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)
    
    # Call API for analysis
    print("🔍 Analyzing threat with CyberXP AI...")
    print(f"   Threat: {threat}")
    print(f"   API: {API_URL}")
    print()
    print("⏳ This may take 30-120 seconds...")
    print()
    
    try:
        response = requests.post(
            f"{API_URL}/generate",
            json={"prompt": threat},
            timeout=120
        )
        
        if response.status_code == 200:
            data = response.json()
            
            # Use parsed JSON from API server
            parsed = data.get('parsed')
            
            if parsed:
                # Display structured analysis
                print("🔍 Threat Analysis:")
                print("══════════════════════════════════════════════════")
                print(f"Severity: {parsed.get('severity', 'Unknown')}")
                print(f"Analysis: {parsed.get('analysis', 'N/A')}")
                if parsed.get('explanation'):
                    print(f"Explanation: {parsed.get('explanation')}")
                print()
                
                actions = parsed.get('recommended_actions', [])
                if actions:
                    print(f"📋 Recommended Actions ({len(actions)}):")
                    print("══════════════════════════════════════════════════")
                    for i, action in enumerate(actions, 1):
                        action_type = action.get('type', 'unknown')
                        cmd = action.get('command', '')
                        desc = action.get('description', '')
                        needs_confirm = action.get('requires_confirmation', True)
                        
                        print(f"\n{i}. [{action_type.upper()}] {desc}")
                        print(f"   Command: {cmd}")
                        if needs_confirm:
                            print(f"   ⚠️  Requires confirmation")
                    
                    print()
                    
                    # Execute actions
                    if auto_mode:
                        print("🤖 Auto-mode: Executing all actions...")
                    else:
                        print("❓ Execute recommended actions? (y/n/all): ", end='')
                        choice = input().strip().lower()
                    
                    if auto_mode or choice in ['y', 'yes', 'all', 'a']:
                        execute_all = (choice == 'all' or choice == 'a' or auto_mode)
                        
                        for i, action in enumerate(actions, 1):
                            cmd = action.get('command', '')
                            desc = action.get('description', '')
                            needs_confirm = action.get('requires_confirmation', True)
                            
                            if not execute_all and needs_confirm:
                                print(f"\n❓ Execute action {i}? [{desc}] (y/n): ", end='')
                                if not auto_mode:
                                    confirm = input().strip().lower()
                                    if confirm not in ['y', 'yes']:
                                        print("⏭️  Skipped")
                                        continue
                            
                            # Verify command with API
                            try:
                                verify_resp = requests.post(
                                    f"{API_URL}/execute",
                                    json={"command": cmd, "description": desc},
                                    timeout=5
                                )
                                if verify_resp.status_code != 200:
                                    print(f"⚠️  Command not approved by API: {verify_resp.json().get('error')}")
                                    continue
                            except:
                                print(f"⚠️  Could not verify command with API")
                                if not auto_mode:
                                    print(f"   Continue anyway? (y/n): ", end='')
                                    if input().strip().lower() not in ['y', 'yes']:
                                        continue
                            
                            execute_command(cmd, desc)
                    else:
                        print("⏭️  Actions not executed")
                else:
                    print("ℹ️  No actions recommended")
                
                print("\n══════════════════════════════════════════════════")
            else:
                # Fallback: display raw response
                print("🔍 Threat Analysis:")
                print("══════════════════════════════════════════════════")
                print(data.get('response', ''))
                print("══════════════════════════════════════════════════")
        else:
            print(f"❌ Error: API returned {response.status_code}")
            print(response.text)
            sys.exit(1)
            
    except requests.exceptions.Timeout:
        print("❌ Error: Analysis timeout (>2 minutes)")
        print()
        print("The AI model may be too slow.")
        print("Try a shorter threat description.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()
