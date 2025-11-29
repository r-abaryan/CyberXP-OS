#!/usr/bin/env python3
"""
CyberXP Integration Bridge
Calls CyberLLM-Agent with fallback to direct LLM
Supports LangChain agents and system health analysis
"""

import sys
import os
import subprocess
import time
from datetime import datetime

# LangChain imports
try:
    from langchain.agents import AgentExecutor, initialize_agent, AgentType
    from langchain.tools import Tool
    from langchain.prompts import ChatPromptTemplate, MessagesPlaceholder
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False

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

def get_cpu_usage_tool() -> str:
    """Get current CPU usage percentage"""
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
        cpu = 100.0 * (1.0 - idle_delta / total_delta) if total_delta > 0 else 0
        return f"CPU Usage: {cpu:.1f}%"
    except Exception as e:
        return f"Error getting CPU: {str(e)}"

def get_memory_usage_tool() -> str:
    """Get current memory usage"""
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
    """Get disk usage"""
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
    """Get firewall status"""
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
    """Get count of open/listening ports"""
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
    """Get count of failed login attempts"""
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
    """Check for pending security updates"""
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
    """Enable firewall (ufw)"""
    cmd = "sudo ufw enable"
    return execute_command(cmd, "Enable firewall")

def update_system_tool() -> str:
    """Update system packages (security updates)"""
    cmd = "sudo apt update && sudo apt upgrade -y"
    return execute_command(cmd, "Update system packages")

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

def analyze_system_health(simple_mode=False, auto_mode=False):
    """Let agent analyze system health using its tools"""
    print("🤖 Agent will investigate system health and propose fixes")
    print()
    
    if auto_mode:
        print("🔧 Auto-fix mode: Issues will be fixed automatically without prompts.")
    else:
        print("⚠️  If critical issues are found, you will be prompted for immediate action.")
    print()
    
    # Ask user if they want AI to analyze (skip if auto mode)
    if not auto_mode:
        print("Would you like AI agent to investigate system health? (y/n): ", end='')
        choice = input().strip().lower()
        
        if choice not in ['y', 'yes']:
            print("⏭️  Skipped")
            return
    
    print()
    print("⏳ Agent investigating system...")
    print()
    
    # Let agent investigate - it will use tools to gather data and decide actions
    threat_desc = "Investigate system health and security status. Check CPU, memory, disk, firewall, open ports, failed logins, and security updates. Identify any issues and fix them automatically."
    
    # Use direct AI fallback with agent mode
    if LANGCHAIN_AVAILABLE:
        direct_ai_fallback(threat_desc, use_agent=True, auto_mode=auto_mode)
    else:
        print("⚠️  LangChain not available. Install with: pip install langchain langchain-core")
        print("   Falling back to basic analysis...")
        direct_ai_fallback(threat_desc, use_agent=False, auto_mode=auto_mode)

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
        return analyze_system_health(simple_mode=simple_mode, auto_mode=auto_mode)
    
    if len(sys.argv) < 2:
        print("Usage: cyberxp-analyze [OPTIONS] <threat_description>")
        print()
        print("Options:")
        print("  --auto, -y       Auto-execute recommended actions (no confirmation)")
        print("  --agent          Use LangChain agent for intelligent reasoning")
        print("  --status, --health  Analyze system health and propose fixes")
        print()
        print("Examples:")
        print("  cyberxp-analyze 'Suspicious login from unknown IP 192.168.1.100'")
        print("  cyberxp-analyze --auto 'Multiple failed SSH attempts detected'")
        print("  cyberxp-analyze --agent 'Suspicious activity detected'")
        print("  cyberxp-analyze --status  # Analyze system health")
        sys.exit(1)
    
    threat = ' '.join(sys.argv[1:])
    
    # Check if CyberLLM-Agent is installed
    cyberllm_path = os.environ.get('CYBERXP_AI_PATH', '/opt/cyberxp-ai')
    
    if not os.path.exists(cyberllm_path):
        print("❌ Error: CyberLLM-Agent not installed")
        print()
        print("To install:")
        print("  sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
        sys.exit(1)
    
    # Try to use AI
    try:
        import subprocess
        
        main_script = f"{cyberllm_path}/src/cyber_agent_vec.py"
        
        if not os.path.exists(main_script):
            print(f"❌ Error: {main_script} not found")
            print()
            print("CyberLLM-Agent installation appears incomplete.")
            print("Reinstall with: sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh")
            sys.exit(1)
        
        print("🔍 Analyzing threat with CyberXP AI...")
        print(f"   Threat: {threat}")
        print(f"   Script: {main_script}")
        print(f"   Working Dir: {cyberllm_path}")
        print()
        print("⏳ This may take 30-120 seconds on CPU...")
        print()
        
        # Call CyberLLM-Agent with proper arguments
        result = subprocess.run(
            [
                'python3', main_script,
                '--threat', threat,
                '--enable_ioc'
            ],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=cyberllm_path
        )
        
        if result.returncode == 0 and result.stdout:
            print(result.stdout)
        else:
            # Vector/RAG analysis failed, try direct fallback
            print("⚠️  Vector Analysis failed. Attempting direct LLM fallback...")
            if result.stderr:
                print(f"   (Error: {result.stderr.strip()})")
            print()
            
            # Check if agent mode requested
            use_agent_flag = '--agent' in sys.argv or use_agent
            direct_ai_fallback(threat, use_agent=use_agent_flag, auto_mode=auto_mode)
            
    except subprocess.TimeoutExpired:
        print("❌ Error: Analysis timeout (>2 minutes)")
        print()
        print("The AI model may be too slow on this system.")
        print("Try increasing VM resources or using a shorter threat description.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

def direct_ai_fallback(threat, use_agent=False, auto_mode=False):
    """
    Direct LLM analysis without Vector DB/RAG
    Uses CyberXP fine-tuned model with LangChain for cybersecurity triage
    Supports agent mode for intelligent tool usage
    """
    try:
        print("⏳ Loading CyberXP AI model (8-bit quantized)...")
        print("   This may take 15-25 seconds...")
        
        # Import here to avoid slow startup if not needed
        import torch
        from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig, pipeline
        from langchain_huggingface import HuggingFacePipeline
        from langchain.prompts import PromptTemplate
        from langchain.chains import LLMChain
        
        model_name = "abaryan/CyberXP_Agent_Llama_3.2_1B"
        
        # Configure 8-bit quantization (more compatible than 4-bit)
        quantization_config = BitsAndBytesConfig(
            load_in_8bit=True,
            llm_int8_threshold=6.0
        )
        
        # Load model with quantization
        print("📥 Loading tokenizer...")
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        
        print("📥 Loading quantized model...")
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            quantization_config=quantization_config,
            device_map="auto",
            low_cpu_mem_usage=True
        )
        
        print("🔧 Creating LangChain pipeline...")
        
        # Create HuggingFace pipeline
        pipe = pipeline(
            "text-generation",
            model=model,
            tokenizer=tokenizer,
            max_new_tokens=200,
            temperature=0.7,
            top_p=0.9,
            do_sample=True
        )
        
        # Wrap with LangChain
        llm = HuggingFacePipeline(pipeline=pipe)
        
        # Agent mode with tools
        if use_agent and LANGCHAIN_AVAILABLE:
            print("🤖 Agent Mode: Using tools for intelligent response")
            print()
            
            # Create tools - agent can use these to gather data and take actions
            tools = [
                # Security actions
                Tool(name="block_ip", func=block_ip_tool, description="Block an IP address using firewall. Input: IP address as string"),
                Tool(name="check_logs", func=check_logs_tool, description="Check system logs. Input: service name (e.g., 'ssh') or 'all' for all logs"),
                Tool(name="stop_service", func=stop_service_tool, description="Stop a systemd service. Input: service name (e.g., 'ssh', 'apache2')"),
                Tool(name="check_connections", func=check_connections_tool, description="Check active network connections. Input: optional port number (e.g., '22') or empty for all"),
                Tool(name="quarantine_file", func=quarantine_file_tool, description="Move suspicious file to quarantine. Input: full file path"),
                
                # System health monitoring tools
                Tool(name="get_cpu_usage", func=get_cpu_usage_tool, description="Get current CPU usage percentage. No input needed."),
                Tool(name="get_memory_usage", func=get_memory_usage_tool, description="Get current memory usage. No input needed."),
                Tool(name="get_disk_usage", func=get_disk_usage_tool, description="Get disk usage for root partition. No input needed."),
                Tool(name="get_firewall_status", func=get_firewall_status_tool, description="Get firewall (ufw) status. No input needed."),
                Tool(name="get_open_ports", func=get_open_ports_tool, description="Get count of open/listening ports. No input needed."),
                Tool(name="get_failed_logins", func=get_failed_logins_tool, description="Get count of failed login attempts. No input needed."),
                Tool(name="get_security_updates", func=get_security_updates_tool, description="Check for pending security updates. No input needed."),
                
                # System maintenance tools
                Tool(name="enable_firewall", func=enable_firewall_tool, description="Enable firewall (ufw). No input needed."),
                Tool(name="update_system", func=update_system_tool, description="Update system packages including security updates. No input needed."),
            ]
            
            # Create agent
            agent_executor = initialize_agent(
                tools=tools,
                llm=llm,
                agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION,
                verbose=not auto_mode,
                max_iterations=5,
                handle_parsing_errors="Check your output and make sure it conforms!"
            )
            
            # Execute agent
            print("⏳ Agent analyzing and responding...")
            print("=" * 60)
            
            try:
                result = agent_executor.run(
                    f"Security threat: {threat}. Analyze and respond appropriately."
                )
                print("\n" + "=" * 60)
                print("✅ Agent analysis complete")
                print(f"\nResult: {result}")
            except Exception as e:
                print(f"\n❌ Agent error: {str(e)}")
                print("Falling back to simple analysis...")
                use_agent = False
        
        # Simple chain mode (fallback or non-agent)
        if not use_agent:
            # Create prompt template for cybersecurity triage
            template = """### Instruction:
You are a cybersecurity analyst. Analyze the threat and provide actionable security responses.
Your response must be valid JSON only, with no other text.

JSON Schema:
{{
    "analysis": "Brief analysis of the threat/situation",
    "severity": "Low/Medium/High/Critical",
    "recommended_actions": [
        {{
            "command": "Exact shell command (e.g., 'sudo ufw deny from 192.168.1.100')",
            "description": "What this command does",
            "type": "firewall|service|log|monitor|block_ip|quarantine|alert",
            "requires_confirmation": true/false
        }}
    ],
    "immediate_threat": true/false,
    "explanation": "Why these actions are needed"
}}

### Threat/Status:
{threat}

### JSON Response:
"""
            
            prompt = PromptTemplate(template=template, input_variables=["threat"])
            chain = LLMChain(llm=llm, prompt=prompt)
            
            # Generate analysis
            print("🤖 Analyzing threat (15-30 seconds)...")
            result = chain.run(threat=threat)
            
            # Try to parse JSON
            import json
            import re
            parsed = None
            try:
                json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', result, re.DOTALL)
                if json_match:
                    parsed = json.loads(json_match.group(0))
            except:
                pass
            
            print("\n🔍 Threat Analysis:")
            print("══════════════════════════════════════════════════")
            
            if parsed:
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
                            
                            execute_command(cmd, desc)
                    else:
                        print("⏭️  Actions not executed")
                else:
                    print("ℹ️  No actions recommended")
            else:
                # Fallback: show raw response
                print(result.strip())
            
            print("\n══════════════════════════════════════════════════")
        
        sys.exit(0)
        
    except Exception as e:
        print(f"❌ AI Analysis failed: {str(e)}")
        print("\n⚠️  Unable to perform AI analysis.")
        print("Recommendation: Investigate manually following standard incident response procedures.")
        sys.exit(1)

# Commented out: Basic rule-based analysis (not needed with AI fallback)
# def basic_analysis(threat):
#     """Simple rule-based analysis as fallback"""
#     print("🔍 Threat Analysis (Basic Mode)")
#     print()
#     print(f"Threat Description: {threat}")
#     print()
#     
#     # Simple keyword analysis
#     threat_lower = threat.lower()
#     
#     severity = "Medium"
#     threat_type = "Unknown"
#     recommendations = []
#     
#     # Detect threat type
#     if any(word in threat_lower for word in ['phishing', 'email', 'link', 'attachment']):
#         threat_type = "Phishing Attack"
#         severity = "High"
#         recommendations = [
#             "Block sender email address",
#             "Scan all attachments for malware",
#             "Educate users about phishing indicators",
#             "Enable email authentication (SPF, DKIM, DMARC)"
#         ]
#     elif any(word in threat_lower for word in ['ransomware', 'encrypted', 'ransom']):
#         threat_type = "Ransomware"
#         severity = "Critical"
#         recommendations = [
#             "Isolate affected systems immediately",
#             "Do not pay ransom",
#             "Restore from clean backups",
#             "Scan network for lateral movement"
#         ]
#     elif any(word in threat_lower for word in ['ddos', 'flood', 'traffic']):
#         threat_type = "DDoS Attack"
#         severity = "High"
#         recommendations = [
#             "Enable DDoS protection",
#             "Contact ISP for mitigation",
#             "Implement rate limiting",
#             "Use CDN services"
#         ]
#     elif any(word in threat_lower for word in ['login', 'brute', 'password', 'unauthorized']):
#         threat_type = "Unauthorized Access Attempt"
#         severity = "High"
#         recommendations = [
#             "Block source IP address",
#             "Enable MFA for all accounts",
#             "Review access logs",
#             "Implement account lockout policies"
#         ]
#     elif any(word in threat_lower for word in ['malware', 'virus', 'trojan']):
#         threat_type = "Malware Infection"
#         severity = "High"
#         recommendations = [
#             "Quarantine infected systems",
#             "Run full antivirus scan",
#             "Update antivirus definitions",
#             "Investigate infection vector"
#         ]
#     else:
#         recommendations = [
#             "Monitor system logs for anomalies",
#             "Implement security best practices",
#             "Keep systems updated",
#             "Enable intrusion detection"
#         ]
#     
#     print(f"Threat Type: {threat_type}")
#     print(f"Severity: {severity}")
#     print()
#     print("Recommendations:")
#     for i, rec in enumerate(recommendations, 1):
#         print(f"  {i}. {rec}")
#     print()
#     print("💡 Note: This is basic rule-based analysis.")
#     print("   For AI-powered analysis, install CyberLLM-Agent:")
#     print("   https://github.com/r-abaryan/CyberLLM-Agent")


if __name__ == '__main__':
    main()
