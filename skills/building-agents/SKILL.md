---
name: agentic-app-builder
description: Build production-grade agentic AI applications from scratch using LangGraph, FastAPI, MCP tools, OpenTelemetry observability, structured evaluation, and containerized microservices. Use when creating new AI agents, adding tools or memory to agents, instrumenting with OpenTelemetry, writing agent evaluations, or containerizing agent services.
---

# Building Production Agentic Applications

This skill teaches how to build, instrument, evaluate, and containerize agentic AI applications using proven patterns from a reference implementation. Use this as a blueprint when creating new agent projects or adding agentic capabilities to existing ones.

Reference implementation lives in `code/` — read those files for working examples of every pattern below.

## Architecture Pattern

Build agentic apps as a set of focused microservices:

```
Frontend (Streamlit/Gradio) → Agent API (FastAPI + LangGraph) → AI Gateway (LiteLLM) → LLM
                                    ↕                              
                              Vector DB (Milvus)     MCP Server(s) (FastMCP/SSE)
                                    ↕
                              Trace Collector (Jaeger/OTEL Collector)
```

Each service is independently deployable, observable, and testable.

## Step 1: Agent Core (FastAPI + LangGraph)

Create a ReAct agent using LangGraph's `create_react_agent` with FastAPI as the HTTP layer.

```python
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException

# Build agent at startup, not per-request
@asynccontextmanager
async def lifespan(app: FastAPI):
    global agent_graph
    all_tools = local_tools + await load_mcp_tools()
    agent_graph = create_react_agent(llm, all_tools, checkpointer=MemorySaver())
    yield

app = FastAPI(lifespan=lifespan)

# System prompt goes in each invoke call, not the constructor
result = await agent_graph.ainvoke(
    {"messages": [SystemMessage(content=SYSTEM_PROMPT), HumanMessage(content=user_msg)]},
    config={"configurable": {"thread_id": thread_id}}
)
```

Key patterns:
- Use FastAPI lifespan to initialize agent and MCP connections once at startup
- Pass system prompt as `SystemMessage` per invocation, not baked into the agent
- Use `MemorySaver` for in-process conversation history per `thread_id`
- Return 503 from `/chat` if agent hasn't finished initializing
- Always expose `GET /health` returning 503 until ready, 200 after

## Step 2: Tool Design

### Local Tools
Define tools with `@tool` decorator. Inject dependencies via `RunnableConfig`, not globals:

```python
from langchain_core.tools import tool
from langchain_core.runnables import RunnableConfig

@tool
def save_memory(content: str, user_id: str = "default", config: RunnableConfig = None) -> str:
    """Save valuable information to long-term memory for future retrieval."""
    memory = config.get("configurable", {}).get("memory_client")
    if not memory:
        return "Error: Memory client not configured."
    result = memory.add(content, user_id=user_id)
    return f"Saved to memory: {result}"
```

Pass injected dependencies at invocation time:
```python
config={"configurable": {"thread_id": thread_id, "memory_client": memory}}
```

### MCP Tools (External)
Load external tools from MCP servers at startup using SSE transport:

```python
from langchain_mcp_adapters.client import MultiServerMCPClient

try:
    client = MultiServerMCPClient({"my_tools": {"url": "http://mcp:8000/sse", "transport": "sse"}})
    mcp_tools = await client.get_tools()
except Exception:
    mcp_tools = []  # Graceful degradation

all_tools = local_tools + mcp_tools
```

### Building MCP Servers
Use FastMCP to expose tools over SSE:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("My_Tools", host="0.0.0.0", port=8000)

@mcp.tool()
async def get_data(query: str) -> str:
    """Fetch data based on query parameter."""
    with tracer.start_as_current_span("get_data", attributes={"query": query}):
        return f"Result for {query}"

if __name__ == "__main__":
    mcp.run(transport="sse")
```

## Step 3: System Prompt Engineering for Agents

System prompts for tool-calling agents require forceful language. Weak phrasing causes models to skip tool calls.

```
## CRITICAL RULES:

1. You MUST call `recall_memory` BEFORE responding to ANY personal question.
   NEVER say "I don't know" without checking memory first.

2. When the user shares ANY personal fact, you MUST call `save_memory`.
   NEVER say "I've saved" without actually calling the tool.

3. Multi-step reasoning: "What is the price of my favourite fruit?"
   → Step 1: recall_memory("favourite fruit")
   → Step 2: get_fruit_price(result)
```

Patterns that work:
- Use "MUST", "NEVER", "CRITICAL RULES" — not "should" or "try to"
- Explicitly list every available tool with its purpose
- Provide multi-step reasoning examples showing tool chaining
- Separate chat-only scenarios from tool-required scenarios

## Step 4: OpenTelemetry Instrumentation

Every service in an agentic app must be instrumented. This is non-negotiable for debugging agent behavior in production.

### Setup Pattern (FastAPI services)
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.langchain import LangchainInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor

resource = Resource(attributes={"service.name": "my-agent-service"})
trace.set_tracer_provider(TracerProvider(resource=resource))
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT))
)

# Instrument everything
FastAPIInstrumentor.instrument_app(app)
LangchainInstrumentor().instrument()
HTTPXClientInstrumentor().instrument()
LoggingInstrumentor().instrument(set_logging_format=True)
```

### Logging with Trace Correlation
```python
logging.basicConfig(
    format='%(asctime)s %(levelname)s [trace_id=%(otelTraceID)s span_id=%(otelSpanID)s] %(message)s',
    level=logging.INFO
)
logging.getLogger("httpx").setLevel(logging.WARNING)
```

### Custom Spans for Tools
Wrap tool logic in spans with semantic attributes for trace-level debugging:
```python
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("get_fruit_price", attributes={"fruit.name": fruit_name}):
    result = lookup_price(fruit_name)
```

### Streamlit OTEL (singleton pattern)
```python
@st.cache_resource
def setup_telemetry():
    # ... provider setup ...
    RequestsInstrumentor().instrument()

setup_telemetry()
```

### Rules
- Each service gets a unique `service.name` resource attribute
- Protocol: `http/protobuf`. The exporter auto-appends `/v1/traces` — do NOT include it in the endpoint env var
- Use Jaeger (`jaegertracing/jaeger:2.2.0`) for local dev, OTEL Collector for production
- Suppress noisy loggers: `logging.getLogger("httpx").setLevel(logging.WARNING)`

## Step 5: Evaluation & Testing

Agent evaluation requires structured test harnesses, not just unit tests. Build two layers:

### E2E Happy Path
Tests the full stack end-to-end: health → memory save → memory recall → tool call → trace verification.

```python
def test_happy_path():
    unique_id = str(uuid.uuid4())[:8]

    # 1. Health check
    assert requests.get(f"{AGENT_URL}/health").status_code == 200

    # 2. Save memory
    resp = chat(f"My name is CODE-{unique_id}", thread_id=f"test-{unique_id}")
    assert resp is not None

    # 3. Recall memory (wait for vector indexing)
    time.sleep(5)
    resp = chat("What is my name?", thread_id=f"test-{unique_id}")
    assert f"CODE-{unique_id}" in resp["response"]

    # 4. MCP tool call
    resp = chat("How much does an apple cost?")
    assert "$" in resp["response"]

    # 5. Verify traces exist in Jaeger
    traces = requests.get(JAEGER_API, params={"service": "agentic-app", "limit": 5}).json()
    assert len(traces.get("data", [])) > 0
```

### Structured Evaluation Suite
Define test cases as data with expected tool usage and response validation:

```python
@dataclass
class TestCase:
    name: str
    messages: list[str]
    expected_tools: list[list[str]]   # expected tools per message
    expected_in_response: list[str]   # strings in final response
    description: str = ""

TESTS = [
    TestCase(
        name="multi_step_reasoning",
        messages=["My favourite fruit is banana", "What is the price of my favourite fruit?"],
        expected_tools=[["save_memory"], ["recall_memory", "get_fruit_price"]],
        expected_in_response=["banana", "price", "$"],
    ),
]
```

### Evaluation Best Practices
- Use unique IDs per run (`uuid.uuid4()[:8]`) to avoid memory collisions across runs
- Add `time.sleep(5)` between save and recall to allow vector DB indexing
- Use different `thread_id` values to isolate conversation context between test steps
- Track latency per test case for performance regression detection
- Verify OTEL traces in Jaeger as part of the test — observability is a feature, not an afterthought

## Step 6: Containerization

### Multi-Stage Dockerfile (use for every service)
```dockerfile
# --- Builder ---
FROM quay.io/fedora/fedora:42 AS builder
RUN dnf install -y python3 python3-pip python3-devel gcc && dnf clean all
WORKDIR /build
COPY requirements.txt .
RUN python3 -m pip install --no-cache-dir --target=/install -r requirements.txt

# --- Runtime ---
FROM quay.io/fedora/fedora-minimal:42
RUN microdnf install -y python3 shadow-utils && microdnf clean all
WORKDIR /app
COPY --from=builder /install /packages
COPY . .
RUN useradd -m -r -s /bin/false appuser && \
    chown -R appuser:appuser /app /packages
ENV PYTHONPATH="/packages" HOME=/tmp PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
CMD ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Baking ML Models at Build Time
For services that need embedding models, download them during the build to avoid runtime downloads:
```dockerfile
# In builder stage
RUN PYTHONPATH=/install python3 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# In runtime stage
COPY --from=builder /root/.cache/huggingface /tmp/.cache/huggingface
```

### Docker Compose Orchestration
```yaml
services:
  agent:
    build: ./code/agent
    depends_on:
      vector-db: { condition: service_healthy }
      ai-gateway: { condition: service_healthy }
      mcp: { condition: service_started }
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318/v1/traces
      - MCP_HOST=mcp

  mcp:
    build: ./code/mcp
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318/v1/traces

  jaeger:
    image: jaegertracing/jaeger:2.2.0
    ports: ["16686:16686", "4317:4317", "4318:4318"]
```

Key patterns:
- Use `depends_on` with `condition: service_healthy` for services with health checks
- Mount source code as volumes during development for hot reload
- Use `service_started` for services without health endpoints
- All config via environment variables — same image runs in dev, staging, prod

## Step 7: AI Gateway

Use LiteLLM as a proxy to abstract LLM provider details from the agent:

```yaml
# config.yaml
model_list:
  - model_name: my-model
    litellm_params:
      model: hosted_vllm/Qwen/Qwen3-30B-A3B-Instruct-2507
      api_base: https://my-inference-server/v1
      api_key: "my-key"
    model_info:
      supports_function_calling: true

litellm_settings:
  drop_params: true
  ssl_verify: false
```

The agent connects to the gateway as if it were OpenAI:
```python
llm = ChatOpenAI(openai_api_key="sk-123456", openai_api_base="http://ai-gateway:4000", model_name="my-model")
```

This lets you swap models, add fallbacks, or route to self-hosted inference without changing agent code.

## Checklist: New Agentic App

When building a new agentic application, verify:

1. [ ] Agent uses FastAPI lifespan for initialization
2. [ ] System prompt uses MUST/NEVER/CRITICAL language for tool calling
3. [ ] Tools inject dependencies via `RunnableConfig`, not globals
4. [ ] MCP tools load at startup with graceful degradation
5. [ ] Every service has OTEL instrumentation with unique `service.name`
6. [ ] Logs include `trace_id` and `span_id` for correlation
7. [ ] Custom spans wrap tool logic with semantic attributes
8. [ ] E2E evaluation covers: health → memory → tools → trace verification
9. [ ] Structured eval suite defines expected tools per message
10. [ ] Dockerfiles use multi-stage builds with non-root user
11. [ ] ML models baked into images at build time (no runtime downloads)
12. [ ] All config via environment variables
13. [ ] Health endpoints on every service (503 until ready, 200 after)
14. [ ] Docker Compose uses `depends_on` with health conditions
