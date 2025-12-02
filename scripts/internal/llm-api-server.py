#!/usr/bin/env python3
"""
LLM API Server - Windows Host Side
Hosts your fine-tuned 1B model and exposes REST API
"""

from flask import Flask, request, jsonify
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import json
import re
import subprocess
import os

app = Flask(__name__)

# Configuration
MODEL_PATH = "abaryan/CyberXP_Agent_Llama_3.2_1B"
MAX_LENGTH = 512
TEMPERATURE = 0.7

# SSH Configuration for VM access
VM_SSH_HOST = os.environ.get('VM_SSH_HOST', '10.0.2.15')  # VM IP (adjust as needed)
VM_SSH_USER = os.environ.get('VM_SSH_USER', 'root')  # SSH user (default: root)
VM_SSH_KEY = os.environ.get('VM_SSH_KEY', '')  # Path to SSH key (optional)
# No password - using passwordless SSH (key-based or configured)

def execute_ssh_command(command, timeout=10):
    """Execute command on VM via SSH (passwordless - root user)"""
    try:
        # Build SSH command
        ssh_cmd = ['ssh']
        
        # Add SSH key if provided
        if VM_SSH_KEY and os.path.exists(VM_SSH_KEY):
            ssh_cmd.extend(['-i', VM_SSH_KEY])
        
        # Disable host key checking for automation (use with caution)
        ssh_cmd.extend(['-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null'])
        
        # Add connection timeout
        ssh_cmd.extend(['-o', 'ConnectTimeout=5'])
        
        # Disable password prompt (assumes passwordless SSH is configured)
        ssh_cmd.extend(['-o', 'BatchMode=yes', '-o', 'PasswordAuthentication=no'])
        
        # Build full command - root user, no password
        ssh_target = f"{VM_SSH_USER}@{VM_SSH_HOST}"
        ssh_cmd.append(ssh_target)
        ssh_cmd.append(command)
        
        # Execute via SSH
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Command timeout",
            "returncode": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }

# Load model once at startup
print("Loading model...")
try:
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH,
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
        device_map="auto"
    )
    # Set pad token if not set
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    print("Model loaded!")
except Exception as e:
    print(f"ERROR loading model: {str(e)}")
    import traceback
    traceback.print_exc()
    raise

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "ok", "model": MODEL_PATH})

@app.route('/generate', methods=['POST'])
def generate():
    """Generate text from prompt"""
    try:
        # Check if model is loaded
        if 'model' not in globals() or model is None:
            return jsonify({"error": "Model not loaded"}), 500
        if 'tokenizer' not in globals() or tokenizer is None:
            return jsonify({"error": "Tokenizer not loaded"}), 500
            
        data = request.json
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
            
        prompt = data.get('prompt', '')
        max_length = data.get('max_length', MAX_LENGTH)
        temperature = data.get('temperature', TEMPERATURE)
        
        if not prompt:
            return jsonify({"error": "No prompt provided"}), 400
        
        # Create prompt template for cybersecurity triage with JSON output
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

Common security commands:
- Block IP: sudo ufw deny from <IP>
- Block IP in iptables: sudo iptables -A INPUT -s <IP> -j DROP
- Stop service: sudo systemctl stop <service>
- Check logs: sudo journalctl -u <service> -n 50
- Quarantine file: sudo mv <file> /tmp/quarantine/
- Enable firewall: sudo ufw enable
- Check connections: sudo netstat -tulpn | grep <port>

### Threat/Status:
{threat}

### JSON Response:
"""
        # Apply the template to the user's prompt
        formatted_prompt = template.format(threat=prompt)

        # Tokenize
        try:
            inputs = tokenizer(formatted_prompt, return_tensors="pt")
            # Move to model device if model has device attribute
            if hasattr(model, 'device'):
                inputs = {k: v.to(model.device) for k, v in inputs.items()}
            elif hasattr(model, 'module') and hasattr(model.module, 'device'):
                inputs = {k: v.to(model.module.device) for k, v in inputs.items()}
        except Exception as e:
            return jsonify({"error": f"Tokenization failed: {str(e)}"}), 500
        
        # Generate - optimize for speed
        try:
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_length=min(max_length, 256),  # Cap at 256 for faster generation
                    max_new_tokens=128,  # Limit new tokens for faster response
                    temperature=temperature,
                    do_sample=True,
                    top_p=0.9,
                    pad_token_id=tokenizer.eos_token_id if tokenizer.eos_token_id else tokenizer.pad_token_id,
                    num_return_sequences=1
                )
        except Exception as e:
            return jsonify({"error": f"Generation failed: {str(e)}"}), 500
        
        # Decode
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Remove prompt from response
        if response.startswith(formatted_prompt):
            response = response[len(formatted_prompt):].strip()
        
        # Try to extract JSON from response
        json_data = None
        try:
            # Look for JSON object in response
            json_match = re.search(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}', response, re.DOTALL)
            if json_match:
                json_str = json_match.group(0)
                json_data = json.loads(json_str)
        except:
            pass
        
        return jsonify({
            "response": response,
            "parsed": json_data,  # Parsed JSON if available
            "prompt": prompt
        })
    
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"ERROR in /generate: {str(e)}")
        print(f"Traceback: {error_details}")
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500

@app.route('/execute', methods=['POST'])
def execute():
    """Execute security action command on VM via SSH"""
    try:
        data = request.json
        command = data.get('command', '')
        description = data.get('description', '')
        
        if not command:
            return jsonify({"error": "No command provided"}), 400
        
        # Safety: Only allow specific security-related commands
        allowed_prefixes = [
            'sudo ufw', 'sudo iptables', 'sudo systemctl',
            'sudo journalctl', 'sudo netstat', 'sudo ss',
            'sudo mv', 'sudo cp', 'sudo chmod', 'sudo chown',
            'sudo fail2ban-client', 'sudo suricata',
            'ip addr', 'ip route', 'ip link',
            'netstat', 'ss', 'tcpdump', 'wireshark',
            'df', 'free', 'top', 'ps', 'grep', 'cat', 'head', 'tail'
        ]
        
        command_lower = command.lower()
        is_allowed = any(command_lower.startswith(prefix) for prefix in allowed_prefixes)
        
        if not is_allowed:
            return jsonify({
                "error": "Command not allowed",
                "message": "Only security-related commands are permitted"
            }), 403
        
        # Execute command on VM via SSH
        result = execute_ssh_command(command, timeout=30)
        
        if result["success"]:
            return jsonify({
                "status": "success",
                "command": command,
                "description": description,
                "stdout": result["stdout"],
                "stderr": result["stderr"],
                "returncode": result["returncode"]
            })
        else:
            return jsonify({
                "status": "error",
                "command": command,
                "description": description,
                "error": result["stderr"],
                "returncode": result["returncode"]
            }), 500
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/execute_ssh', methods=['POST'])
def execute_ssh():
    """Execute arbitrary command on VM via SSH (for tool execution)"""
    try:
        data = request.json
        command = data.get('command', '')
        timeout = data.get('timeout', 10)
        
        if not command:
            return jsonify({"error": "No command provided"}), 400
        
        # Execute command on VM via SSH
        result = execute_ssh_command(command, timeout=timeout)
        
        return jsonify({
            "success": result["success"],
            "stdout": result["stdout"],
            "stderr": result["stderr"],
            "returncode": result["returncode"]
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Run on all interfaces so VBox can access
    app.run(host='0.0.0.0', port=5000, debug=False)
