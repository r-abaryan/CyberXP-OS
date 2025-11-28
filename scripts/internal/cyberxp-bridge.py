#!/usr/bin/env python3
"""
CyberXP Integration Bridge
Calls CyberLLM-Agent with fallback to direct LLM
"""

import sys
import os

def main():
    if len(sys.argv) < 2:
        print("Usage: cyberxp-analyze <threat_description>")
        print()
        print("Example:")
        print("  cyberxp-analyze 'Suspicious login from unknown IP'")
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
            
            direct_ai_fallback(threat)
            
    except subprocess.TimeoutExpired:
        print("❌ Error: Analysis timeout (>2 minutes)")
        print()
        print("The AI model may be too slow on this system.")
        print("Try increasing VM resources or using a shorter threat description.")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

def direct_ai_fallback(threat):
    """
    Direct LLM analysis without Vector DB/RAG
    Uses CyberXP fine-tuned model with LangChain for cybersecurity triage
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
        
        # Create prompt template for cybersecurity triage
        template = """### Instruction:
You are a cybersecurity analyst. Perform threat triage and analysis.

### Threat Description:
{threat}

### Analysis:
Provide:
1. Threat Classification
2. Severity Level (Low/Medium/High/Critical)
3. Immediate Actions
4. Investigation Steps

### Response:
"""
        
        prompt = PromptTemplate(template=template, input_variables=["threat"])
        chain = LLMChain(llm=llm, prompt=prompt)
        
        # Generate analysis
        print("🤖 Analyzing threat (15-30 seconds)...")
        result = chain.run(threat=threat)
        
        print("\n🔍 Threat Analysis:")
        print("══════════════════════════════════════════════════")
        print(result.strip())
        print("══════════════════════════════════════════════════")
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
