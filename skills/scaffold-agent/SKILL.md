---
name: scaffold-agent
description: Scaffolds a new agentic microservice based on the reference architecture.
context: fork
agent: Plan
disable-model-invocation: true
argument-hint: [service-name]
allowed-tools: Read, Grep, Glob, Bash, Edit
---

# Scaffold Agent Task

Create a new agentic service named `$ARGUMENTS`.

Follow these steps carefully:

1. **Analyze Reference:** Read the reference implementation in `code/agent/` (especially `main.py` and `tool.py`) and the conventions in `skills/agentic-app-builder/Agents.md`.

2. **Create Directory:** Create a new directory under `code/` named `$ARGUMENTS`.

3. **Generate Code:** Generate a new FastAPI + LangGraph app in `code/$ARGUMENTS/main.py`. It must include:
   - FastAPI lifespan setup that initializes MCP connections and builds the agent graph at startup
   - OpenTelemetry instrumentation: `FastAPIInstrumentor`, `LangchainInstrumentor`, `HTTPXClientInstrumentor`, `LoggingInstrumentor` with trace-correlated log format
   - A unique `service.name` resource attribute for OTEL (e.g., `$ARGUMENTS-service`)
   - A basic LangGraph ReAct agent using `create_react_agent` with `MemorySaver` checkpointer
   - System prompt passed as `SystemMessage` per `ainvoke` call, using MUST/NEVER language for tool calling
   - A `POST /chat` endpoint (returns 503 if agent not initialized) and `GET /health` endpoint
   - Tool dependency injection via `RunnableConfig`, not globals
   - All configuration loaded from environment variables

4. **Dependencies:** Create `code/$ARGUMENTS/requirements.txt` with:
   - fastapi, uvicorn, langgraph, langchain-openai, langchain-mcp-adapters
   - opentelemetry-api, opentelemetry-sdk, opentelemetry-exporter-otlp-proto-http
   - opentelemetry-instrumentation-fastapi, opentelemetry-instrumentation-httpx
   - opentelemetry-instrumentation-langchain, opentelemetry-instrumentation-logging
   - python-dotenv, pydantic

5. **Containerization:** Create `code/$ARGUMENTS/Dockerfile` following the multi-stage pattern:
   - Builder: `quay.io/fedora/fedora:42` with python3, gcc, pip install to `/install`
   - Runtime: `quay.io/fedora/fedora-minimal:42` with non-root `appuser`, `HOME=/tmp`
   - Set `PYTHONDONTWRITEBYTECODE=1`, `PYTHONUNBUFFERED=1`, `PYTHONPATH="/packages"`
   - If the service needs embedding models, bake them at build time

6. **Docker Compose:** Add the new service to `docker-compose.yaml` with:
   - Appropriate `depends_on` with health conditions
   - OTEL endpoint environment variable
   - Source code volume mount for development

Ensure the generated code follows all conventions in `skills/agentic-app-builder/Agents.md`.
