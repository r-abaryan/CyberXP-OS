#!/usr/bin/env python3
"""
CyberXP Integration Bridge
Connects CyberXP-OS dashboard with CyberLLM-Agent
"""

import sys
import os
import subprocess
import json
from pathlib import Path

CYBERLLM_PATH = "/opt/cyberxp-ai"
CYBERLLM_SCRIPT = f"{CYBERLLM_PATH}/src/cyber_agent_vec.py"

def check_cyberllm_installed():
    """Check if CyberLLM-Agent is installed"""
    return os.path.exists(CYBERLLM_SCRIPT)

def analyze_threat(threat_description, enable_ioc=True):
    """
    Analyze a threat using CyberLLM-Agent
    
    Args:
        threat_description: Description of the threat
        enable_ioc: Whether to extract IOCs
    
    Returns:
        dict: Analysis results
    """
    if not check_cyberllm_installed():
        return {
            'error': 'CyberLLM-Agent not installed',
            'message': 'Run: sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh'
        }
    
    try:
        cmd = [
            'python3',
            CYBERLLM_SCRIPT,
            '--threat', threat_description
        ]
        
        if enable_ioc:
            cmd.append('--enable_ioc')
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=CYBERLLM_PATH
        )
        
        if result.returncode == 0:
            return {
                'success': True,
                'output': result.stdout,
                'analysis': parse_analysis(result.stdout)
            }
        else:
            return {
                'error': 'Analysis failed',
                'stderr': result.stderr
            }
    
    except subprocess.TimeoutExpired:
        return {'error': 'Analysis timeout (>30s)'}
    except Exception as e:
        return {'error': str(e)}

def parse_analysis(output):
    """Parse CyberLLM output into structured data"""
    lines = output.split('\n')
    
    analysis = {
        'severity': 'Unknown',
        'recommendations': [],
        'iocs': []
    }
    
    for line in lines:
        if 'Severity:' in line:
            analysis['severity'] = line.split('Severity:')[1].strip()
        elif 'Recommendation:' in line or '•' in line:
            rec = line.replace('•', '').strip()
            if rec:
                analysis['recommendations'].append(rec)
        elif any(ioc in line.lower() for ioc in ['ip:', 'hash:', 'domain:', 'url:']):
            analysis['iocs'].append(line.strip())
    
    return analysis

def quick_analyze(threat):
    """Quick threat analysis - returns formatted string"""
    result = analyze_threat(threat)
    
    if 'error' in result:
        return f"❌ Error: {result['error']}"
    
    analysis = result.get('analysis', {})
    output = []
    output.append(f"🔍 Threat Analysis")
    output.append(f"Severity: {analysis.get('severity', 'Unknown')}")
    
    if analysis.get('recommendations'):
        output.append("\nRecommendations:")
        for rec in analysis['recommendations'][:3]:
            output.append(f"  • {rec}")
    
    if analysis.get('iocs'):
        output.append("\nIOCs Found:")
        for ioc in analysis['iocs'][:5]:
            output.append(f"  • {ioc}")
    
    return '\n'.join(output)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: cyberxp-analyze <threat_description>")
        sys.exit(1)
    
    threat = ' '.join(sys.argv[1:])
    print(quick_analyze(threat))
