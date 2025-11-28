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

app = Flask(__name__)

# Configuration
MODEL_PATH = "abaryan/CyberXP_Agent_Llama_3.2_1B"
MAX_LENGTH = 512
TEMPERATURE = 0.7

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
        
        # Generate
        try:
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    max_length=max_length,
                    temperature=temperature,
                    do_sample=True,
                    top_p=0.9,
                    pad_token_id=tokenizer.eos_token_id if tokenizer.eos_token_id else tokenizer.pad_token_id
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
    """Execute security action command (called from VM)"""
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
            'netstat', 'ss', 'tcpdump', 'wireshark'
        ]
        
        command_lower = command.lower()
        is_allowed = any(command_lower.startswith(prefix) for prefix in allowed_prefixes)
        
        if not is_allowed:
            return jsonify({
                "error": "Command not allowed",
                "message": "Only security-related commands are permitted"
            }), 403
        
        # Return command for execution on VM side (we don't execute here)
        return jsonify({
            "status": "approved",
            "command": command,
            "description": description,
            "message": "Command approved for execution"
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Run on all interfaces so VBox can access
    app.run(host='0.0.0.0', port=5000, debug=False)
