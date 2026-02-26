import requests
import time
import uuid
import sys
import json

# Configuration
AGENT_URL = "http://localhost:8000"
JAEGER_API_URL = "http://localhost:16686/api/traces"
SERVICE_NAME = "agentic-app"

def print_result(name, passed, details=""):
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"{status} - {name}")
    if details:
        print(f"   {details}")

def test_health():
    try:
        resp = requests.get(f"{AGENT_URL}/health")
        if resp.status_code == 200:
            print_result("Agent Health Check", True)
            return True
        else:
            print_result("Agent Health Check", False, f"Status: {resp.status_code}")
            return False
    except Exception as e:
        print_result("Agent Health Check", False, f"Exception: {str(e)}")
        return False

def chat(message, thread_id="test-eval"):
    try:
        payload = {"message": message, "thread_id": thread_id}
        resp = requests.post(f"{AGENT_URL}/chat", json=payload)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"Chat request failed: {e}")
        return None

def test_happy_path_memory_and_tools():
    # Use a unique ID to avoid collision with previous runs (though memory is global in current implementation, 
    # relying on unique specific content helps).
    unique_id = str(uuid.uuid4())[:8]
    secret_code = f"CODE-{unique_id}"
    
    print(f"\n--- Starting Happy Path Eval (Session: {unique_id}) ---")

    # 1. Store Memory
    store_prompt = f"Hi, My Name is {secret_code}."
    print(f"\nUser: {store_prompt}")
    resp = chat(store_prompt, thread_id=f"store-{unique_id}")
    if not resp: return
    print(f"Agent: {resp['response']}")
    
    # Check if 'save_memory' tool was called (naive check on response text or tool_usage if returned)
    # The API returns "tool_usage", let's inspect it.
    tool_usage = resp.get("tool_usage", [])
    used_save_memory = any(
        call.get("name") == "save_memory" 
        for calls in tool_usage 
        if calls for call in calls # unpack list of lists or dict
    )
    # Note: `tool_usage` structure from main.py is `[m.tool_calls for m in result["messages"] ...]`
    # which is a list of lists of tool call objects.
    
    # We might not see tool usage in the final response if the agent finishes loops. 
    # But usually LangGraph returns the full history or we check the final response implies success.
    
    
    # 2. Recall Memory
    time.sleep(5)  # Wait for Milvus to index the new vector
    recall_prompt = "What is my name?"
    print(f"\nUser: {recall_prompt}")
    resp = chat(recall_prompt, thread_id=f"store-{unique_id}")
    if not resp: return
    print(f"Agent: {resp['response']}")
    
    if secret_code in resp['response']:
        print_result("Memory Recall Test", True)
    else:
        print_result("Memory Recall Test", False, f"Expected '{secret_code}' in response")

    # 3. MCP Tool Test (Fruit Price)
    # "What is the price of apple?"
    fruit_prompt = "How much does an apple cost?"
    print(f"\nUser: {fruit_prompt}")
    resp = chat(fruit_prompt)
    if not resp: return
    print(f"Agent: {resp['response']}")
    
    if "$2.99" in resp['response']: # Matches hardcoded value in mcp/main.py
        print_result("MCP Tool (Fruit Price)", True)
    else:
        print_result("MCP Tool (Fruit Price)", False, "Expected '$2.99' in response")

def verify_traces_exist():
    # Wait a moment for traces to flush to Jaeger
    time.sleep(5) # Increased slightly to ensure spans from both services are flushed
    try:
        # 1. Verify Main Agent Traces
        agent_params = {
            "service": SERVICE_NAME,
            "limit": 5,
            "lookback": "1h"
        }
        resp = requests.get(JAEGER_API_URL, params=agent_params)
        data = resp.json()
        
        if data.get('data') and len(data['data']) > 0:
            trace_count = len(data['data'])
            print_result("OTEL Trace Collection (Agent)", True, f"Found {trace_count} recent traces for {SERVICE_NAME}")
        else:
            print_result("OTEL Trace Collection (Agent)", False, f"No traces found for {SERVICE_NAME}")

        # 2. Verify MCP Tool Traces
        mcp_params = {
            "service": "mcp-server",
            "operation": "get_fruit_price", # The span name defined in mcp/main.py
            "limit": 5,
            "lookback": "1h"
        }
        mcp_resp = requests.get(JAEGER_API_URL, params=mcp_params)
        mcp_data = mcp_resp.json()

        if mcp_data.get('data') and len(mcp_data['data']) > 0:
            found_mcp_span = False
            fruit_queried = "unknown"
            
            # Inspect the traces to find our specific span and its attributes
            for trace in mcp_data['data']:
                for span in trace.get('spans', []):
                    if span.get('operationName') == 'get_fruit_price':
                        found_mcp_span = True
                        # Extract the custom attribute we set in the span
                        tags = {tag['key']: tag['value'] for tag in span.get('tags', [])}
                        if 'fruit.name' in tags:
                            fruit_queried = tags['fruit.name']
                        break
                if found_mcp_span:
                    break
            
            if found_mcp_span:
                print_result("OTEL Trace Collection (MCP Tool)", True, f"Captured 'get_fruit_price' span (Fruit: {fruit_queried})")
            else:
                print_result("OTEL Trace Collection (MCP Tool)", False, "Traces found, but missing 'get_fruit_price' span")
        else:
            print_result("OTEL Trace Collection (MCP Tool)", False, "No traces found for mcp-server in Jaeger")
            
    except Exception as e:
        print_result("OTEL Trace Collection", False, f"Failed to query Jaeger: {e}")
        
def verify_traces_exist_old():
    # Wait a moment for traces to flush to Jaeger
    time.sleep(2)
    try:
        # Query Jaeger for services
        params = {
            "service": SERVICE_NAME,
            "limit": 5,
            "lookback": "1h"
        }
        resp = requests.get(JAEGER_API_URL, params=params)
        data = resp.json()
        
        # data['data'] contains list of traces
        if data.get('data') and len(data['data']) > 0:
            trace_count = len(data['data'])
            print_result("OTEL Trace Collection", True, f"Found {trace_count} recent traces for {SERVICE_NAME}")
            
            # Inspect first trace for spans (simplified)
            spans = data['data'][0].get('spans', [])
            span_names = [s['operationName'] for s in spans]
            print(f"   Sample operations captured: {span_names[:5]}...")
        else:
            print_result("OTEL Trace Collection", False, "No traces found in Jaeger")
            
    except Exception as e:
        print_result("OTEL Trace Collection", False, f"Failed to query Jaeger: {e}")

if __name__ == "__main__":
    print("Initializing Evaluation...")
    if test_health():
        test_happy_path_memory_and_tools()
        print("\n--- Verifying Telemetry ---")
        verify_traces_exist()
    else:
        print("Skipping tests as Agent is unhealthy.")
