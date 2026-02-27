---
name: agentic-app-builder
description: Build production-grade agentic AI applications using LangGraph, FastAPI, MCP tools, OpenTelemetry, and containerized microservices.
---

# Building Production Agentic Applications

This skill guides building, instrumenting, evaluating, and containerizing agentic AI applications. Follow the conventions in `Agents.md` for all code style and architectural decisions.

Reference implementation lives in `code/` — read those files for working examples of every pattern below.

## Architecture Pattern

```
Frontend (Streamlit) → Agent API (FastAPI + LangGraph) → AI Gateway (LiteLLM) → LLM
                              ↕
                        Vector DB (Milvus)     MCP Server(s) (FastMCP/SSE)
                              ↕
                        Trace Collector (Jaeger/OTEL Collector/Langfuse)
```

Each service is independently deployable, observable, and testable.

## Checklist: New Agentic App

When building a new agentic application, verify:

1. [ ] Agent uses FastAPI lifespan for initialization (MCP connections + agent graph built at startup)
2. [ ] System prompt uses MUST/NEVER/CRITICAL language for tool calling
3. [ ] Tools inject dependencies via `RunnableConfig`, not globals
4. [ ] MCP tools load at startup with graceful degradation (log warning, continue with local tools)
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
15. [ ] Three local tools registered: `save_memory`, `recall_memory`, `get_all_memories`

## Quick Reference: Key Patterns

### Agent Core
- `create_react_agent(llm, all_tools, checkpointer=MemorySaver())`
- System prompt passed as `SystemMessage` per `ainvoke` call, not baked into constructor
- Return 503 from `/chat` if agent hasn't finished initializing

### Tool Design
- `@tool` decorator with `config: RunnableConfig = None` for dependency injection
- Pass `memory_client` via `config={"configurable": {"thread_id": ..., "memory_client": ...}}`
- MCP tools loaded via `MultiServerMCPClient` with SSE transport

### System Prompt Styles
Two proven approaches exist in the reference implementation:
- **V1 (Explicit)**: Lists every rule with MUST/NEVER, explicit multi-step examples
- **V2 (Silent Execution)**: Instructs agent to never narrate tool usage, just execute and respond naturally

Choose V2 for better UX; choose V1 when debugging tool-calling reliability.

### Observability
- Protocol: `http/protobuf`
- Note: The OTEL exporter auto-appends `/v1/traces` to the endpoint. However, the current docker-compose.yaml includes it in the env var value. Be consistent with whichever convention your deployment uses.
- Streamlit uses `RequestsInstrumentor` (not HTTPX) with `@st.cache_resource` singleton
- Supports Jaeger (local dev), Langfuse (production), or OTEL Collector → CloudWatch/X-Ray (AWS)

### Containerization
- Multi-stage: `fedora:42` builder → `fedora-minimal:42` runtime
- Non-root `appuser`, `HOME=/tmp`, `PYTHONDONTWRITEBYTECODE=1`
- Bake embedding models at build time (`all-MiniLM-L6-v2`)

### Evaluation
- E2E: health → save memory → wait 5s → recall → MCP tool → verify Jaeger traces
- Structured: `TestCase` dataclass with `expected_tools` per message and `expected_in_response`
- Unique IDs per run (`uuid.uuid4()[:8]`) to avoid memory collisions

For detailed code examples and conventions, see `Agents.md`.
