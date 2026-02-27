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
1. **Analyze Reference:** Read the reference implementation in `code/agent/` to understand the architecture (FastAPI, LangGraph, OpenTelemetry, MCP integration).
2. **Create Directory:** Create a new directory under `code/` named `$ARGUMENTS`.
3. **Generate Code:** Generate a new FastAPI + LangGraph app in `code/$ARGUMENTS/main.py`. Ensure it includes:
   - FastAPI lifespan setup
   - OpenTelemetry instrumentation
   - A basic LangGraph ReAct agent setup
   - A `/chat` and `/health` endpoint
4. **Dependencies:** Create a `code/$ARGUMENTS/requirements.txt` with the necessary dependencies (fastapi, uvicorn, langgraph, langchain-openai, opentelemetry-api, etc.).
5. **Containerization:** Create a `Dockerfile` in `code/$ARGUMENTS/` following the multi-stage pattern from the reference implementation.

Ensure the generated code follows the best practices outlined in the `agentic-app-builder` skill.
