import base64
import os
import requests
import streamlit as st

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.requests import RequestsInstrumentor

import logging

# Config
AGENT_HOST = os.getenv("AGENT_HOST", "http://app.internal:8000")
CHAT_ENDPOINT = os.getenv("CHAT_ENDPOINT", f"{AGENT_HOST}/chat")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://jaeger.internal:4317")

# Enable debug logging for OpenTelemetry
logging.getLogger("opentelemetry").setLevel(logging.WARN)
logging.basicConfig(level=logging.WARN)

# --- TRACING SETUP (Singleton) ---
@st.cache_resource
def setup_telemetry():
    resource = Resource(attributes={"service.name": "streamlit-app"})
    trace.set_tracer_provider(TracerProvider(resource=resource))
    otlp_exporter = OTLPSpanExporter(endpoint=OTEL_ENDPOINT) # for grpc, insecure=True)
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)
    # This automatically injects trace headers into requests.post/get
    RequestsInstrumentor().instrument()

setup_telemetry()
# ---------------------

def call_agent(message: str):
	thread_id = os.getenv("THREAD_ID", "default")
	payload = {"message": message, "thread_id": thread_id}
	headers = {"Content-Type": "application/json"}
	try:
		resp = requests.post(CHAT_ENDPOINT, json=payload, headers=headers, timeout=60)
		resp.raise_for_status()
		return resp.json()
	except Exception as e:
		return {"error": str(e)}


def main():
    
	st.set_page_config(page_title="Agent Chat", layout="centered")
	st.title("Agent Chat")

	# Sidebar for configuration
	with st.sidebar:
		st.header("Configuration")
		thread_id = st.text_input("Thread ID", value=os.getenv("THREAD_ID", "default"), key="thread_id_input")
		# Update env var so call_agent uses it (legacy behavior) or pass it directly
		os.environ["THREAD_ID"] = thread_id
		
		if st.button("Clear Chat"):
			st.session_state.messages = []
			st.rerun()

	# Initialize chat history
	if "messages" not in st.session_state:
		st.session_state.messages = []

	# Display chat messages from history on app rerun
	for message in st.session_state.messages:
		with st.chat_message(message["role"]):
			st.markdown(message["content"])
			if "tool_usage" in message and message["tool_usage"]:
				with st.expander("Tool Usage"):
					st.json(message["tool_usage"])

	# Accept user input
	if prompt := st.chat_input("What is on your mind?"):
		# Add user message to chat history
		st.session_state.messages.append({"role": "user", "content": prompt})
		
		# Display user message in chat message container
		with st.chat_message("user"):
			st.markdown(prompt)

		# Display assistant response in chat message container
		with st.chat_message("assistant"):
			with st.spinner("Thinking..."):
				result = call_agent(prompt)
				
				if "error" in result:
					st.error(result["error"])
					response_content = f"Error: {result['error']}"
					tool_usage = []
				else:
					response_content = result.get("response", "No response received.")
					tool_usage = result.get("tool_usage", [])
					
					st.markdown(response_content)
					if tool_usage:
						with st.expander("Tool Usage"):
							st.json(tool_usage)
			
			# Add assistant response to chat history
			st.session_state.messages.append({
				"role": "assistant", 
				"content": response_content,
				"tool_usage": tool_usage
			})
   



if __name__ == "__main__":
	main()