# Application Code Guidelines

## Architecture
This project is a microservices-based AI Agent application built with Python. The core components include:
- **Agent API (`agent/`)**: A FastAPI backend running a LangGraph ReAct agent. It integrates with Milvus for long-term memory (via Mem0) and external tools via MCP.
- **Frontend (`app/`)**: A Streamlit application providing the chat interface.
- **MCP Server (`mcp/`)**: A FastMCP server providing external tools (e.g., `get_fruit_price`) to the agent via SSE.
- **AI Gateway (`ai-gateway/`)**: A proxy/gateway for LLM API calls.
- **Vector Store (`milvus/`)**: Milvus standalone for storing agent memories and embeddings.

## Code Style & Stack
- **Language**: Python 3.13 (Fedora 42 base images). Use modern syntax freely (`X | None`, match statements, etc.).
- **Frameworks**: FastAPI (Backend), Streamlit (Frontend), LangGraph (Agent Orchestration).
- **Typing**: Use strict Python type hints (`-> str`, `BaseModel`, etc.) for all function signatures and Pydantic models.
- **Async**: Use `async`/`await` for all I/O bound operations in FastAPI and MCP servers (e.g., `async def chat(...)`, `async with session...`).

## Docker Build Pattern
All services use an identical multi-stage Docker build:
- **Builder**: `quay.io/fedora/fedora:42` — installs build deps (`python3`, `gcc`), pip installs to `/install`
- **Runtime**: `quay.io/fedora/fedora-minimal:42` — copies `/install` to `/packages`, sets `PYTHONPATH="/packages"`
- Non-root `appuser` in all containers, `HOME=/tmp`
- `PYTHONDONTWRITEBYTECODE=1` and `PYTHONUNBUFFERED=1` for clean container behavior
- The agent Dockerfile additionally downloads the embedding model (`all-MiniLM-L6-v2`) at build time and bakes it into the image at `/tmp/.cache/huggingface` to avoid runtime downloads

## Observability & Telemetry
- **OpenTelemetry (OTel)** is mandatory across all services. Each service sets a unique `service.name` resource attribute (`agentic-app`, `streamlit-app`, `mcp-server`).
- Always instrument new FastAPI apps with `FastAPIInstrumentor.instrument_app(app)`.
- Always instrument external HTTP calls (e.g., `RequestsInstrumentor`, `HTTPXClientInstrumentor`).
- Always instrument LangChain/LangGraph operations with `LangchainInstrumentor().instrument()`.
- Use `LoggingInstrumentor().instrument(set_logging_format=True)` to inject trace/span IDs into log records. Format logs with `[trace_id=%(otelTraceID)s span_id=%(otelSpanID)s]` for log-trace correlation.
- Suppress noisy loggers: `logging.getLogger("httpx").setLevel(logging.WARNING)`.
- When creating custom tools or complex functions, wrap them in custom spans using `with tracer.start_as_current_span("operation_name"):`.
- In Streamlit, use `@st.cache_resource` to ensure OTEL setup runs only once across reruns.
- OTEL endpoint protocol is `http/protobuf`. The exporter auto-appends `/v1/traces` — do NOT include it in the endpoint env var.

## Conventions
- **Configuration**: All configuration must be loaded via environment variables (using `os.getenv` or `dotenv`). Never hardcode credentials, hostnames, or ports.
- **Memory Management**: The agent uses Mem0 backed by Milvus for persistent long-term memory. The memory client is injected into tools via LangGraph's `RunnableConfig` — not global variables. Tools access it with `config.get("configurable", {}).get("memory_client")`. The memory client is passed at invocation time via `config={"configurable": {"thread_id": thread_id, "memory_client": memory}}`. Any modifications to the agent's system prompt must reinforce the mandatory use of `save_memory` and `recall_memory` for personal user data.
- **Mem0 Return Format**: `mem0ai==1.0.3` returns `{'results': [...]}` wrapped format, not plain lists. Always extract with `results['results']` before iterating, and add `isinstance(r, dict)` checks for safety.
- **Error Handling**: FastAPI endpoints must raise `HTTPException` for expected errors. Streamlit should gracefully catch and display errors using `st.error()`.

## MCP Tool Integration
External tools are loaded from MCP servers at startup using `langchain-mcp-adapters` with SSE transport:
- MCP tools are fetched during FastAPI lifespan initialization via `MultiServerMCPClient`
- Tools are merged with local tools: `all_tools = local_tools + mcp_tools`
- The agent gracefully degrades if the MCP server is unavailable (logs a warning, continues with local tools only)
- MCP servers use `FastMCP` with `host="0.0.0.0"` and `transport="sse"`
- Wrap MCP tool logic in custom OTEL spans with semantic attributes (e.g., `attributes={"fruit.name": fruit_name}`)

## System Prompt Design
The agent's system prompt must follow these patterns for reliable tool calling:
- Explicitly list all available tools with their purpose
- Use "CRITICAL RULES" or "MUST" language — weaker phrasing causes models to skip tool calls
- Rule: NEVER say "I don't know" about personal info without calling `recall_memory` first
- Rule: NEVER say "I've saved" without actually calling `save_memory`
- Document multi-step reasoning examples (e.g., recall favourite fruit → get its price)
- The system prompt is passed as a `SystemMessage` in each `ainvoke` call, not baked into the agent constructor

## FastAPI Lifespan Pattern
The agent uses FastAPI's `@asynccontextmanager` lifespan to initialize MCP connections and build the agent graph at startup:
- MCP tools are loaded asynchronously during lifespan startup
- The ReAct agent (`create_react_agent`) is constructed with all tools (local + MCP)
- `MemorySaver` provides in-process conversation history per `thread_id`
- The `/chat` endpoint returns 503 if the agent hasn't finished initializing

## Health Checks
Every service must expose a health endpoint:
- FastAPI services: `GET /health` — return 503 if not fully initialized, 200 otherwise
- Streamlit: relies on built-in `/_stcore/health`
- MCP server: `GET /sse` serves as the liveness indicator

## Evaluation & Testing
The `evaluation/` folder contains two test harnesses:
- **`e2e_evaluate_agent.py`**: End-to-end happy path — health check → save memory → recall memory → MCP tool call → Jaeger trace verification
- **`evaluation.py`**: Structured test suite with `TestCase` dataclass, expected tool usage per message, response validation, and latency tracking
- Use unique IDs per test run (`uuid.uuid4()[:8]`) to avoid memory collisions across runs
- Add `time.sleep(5)` between save and recall to allow Milvus vector indexing
- Use different `thread_id` values to isolate conversation context between test steps