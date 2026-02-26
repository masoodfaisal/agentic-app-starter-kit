# import os
# import logging
# from contextlib import asynccontextmanager
# from fastapi import FastAPI, HTTPException
# from pydantic import BaseModel
# from dotenv import load_dotenv

# OpenTelemetry
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.langchain import LangchainInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# LangChain / LangGraph
# from langchain_openai import ChatOpenAI
# from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
# from langgraph.prebuilt import create_react_agent
# from langgraph.checkpoint.memory import MemorySaver
# from langchain.agents import create_agent

# MCP
# from langchain_mcp_adapters.client import MultiServerMCPClient

# Mem0
# from mem0 import Memory
from sentence_transformers import SentenceTransformer

from langchain_core.tools import tool
from langchain_core.runnables import RunnableConfig

# ============================================================================
# Setup: Telemetry
# ============================================================================
def setup_telemetry(otel_endpoint: str):
    resource = Resource(attributes={"service.name": "agentic-app"})
    trace.set_tracer_provider(TracerProvider(resource=resource))
    trace.get_tracer_provider().add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=otel_endpoint))
    )
    LangchainInstrumentor().instrument()
    HTTPXClientInstrumentor().instrument()
    



# ============================================================================
# Setup: Memory (Mem0 + Milvus)
# ============================================================================
def get_embedding_dim(embedding_model:str):
    """Get embedding dimension from the model."""
    model = SentenceTransformer(embedding_model)
    return model.get_sentence_embedding_dimension()

    
# ============================================================================
# Tools
# ============================================================================
# memory = None


# def set_memory(mem_instance):
#     global memory
#     memory = mem_instance


@tool
def save_memory(content: str, user_id: str = "default", config: RunnableConfig = None) -> str:
    """Save valuable information or facts to long-term memory for future retrieval."""
    import logging
    logger = logging.getLogger(__name__)

    # Extract memory from config
    memory = config.get("configurable", {}).get("memory_client")
    if not memory:
        return "Error: Memory client not configured."
        
    logger.info(f"save_memory called with content='{content}', user_id='{user_id}'")
    try:
        result = memory.add(content, user_id=user_id)
        logger.info(f"save_memory result: {result}")
        return f"Saved to memory: {result}"
    except Exception as e:
        logger.error(f"save_memory failed: {e}")
        return f"Failed to save memory: {e}"

    # # Direct milvus 
    # embedding = embedder.encode(content).tolist()
    # milvus.insert("memories", {"user_id": user_id, "text": content, "embedding": embedding})
    # return f"Saved: {content}"    


@tool
def recall_memory(query: str, user_id: str = "default", config: RunnableConfig = None) -> str:
    """Search long-term memory for relevant information based on a query."""
    import logging
    logger = logging.getLogger(__name__)
    memory = config.get("configurable", {}).get("memory_client")
    if not memory:
        return "Error: Memory client not configured."
    results = memory.search(query, user_id=user_id, limit=10)
    logger.info(f"recall_memory query='{query}' results={results}")

    # mem0 returns {'results': [...]} — extract the list
    if isinstance(results, dict) and 'results' in results:
        results = results['results']

    if not results:
        return "No relevant memories found."
    formatted = []
    for r in results:
        if isinstance(r, dict):
            formatted.append(f"- {r.get('memory', r)} (score: {r.get('score', 0):.2f})")
        else:
            formatted.append(f"- {r}")
    return "\n".join(formatted)
    # Direct milvus 
    # embedding = embedder.encode(query).tolist()
    # results = milvus.search("memories", data=[embedding], limit=3, 
    #                         filter=f'user_id == "{user_id}"', output_fields=["text"])


@tool
def get_all_memories(user_id: str = "default", config: RunnableConfig = None) -> str:
    """Get all stored memories for a user."""
    memory = config.get("configurable", {}).get("memory_client")
    if not memory:
        return "Error: Memory client not configured."
    memories = memory.get_all(user_id=user_id)
    # mem0 may return {'results': [...]} — extract the list
    if isinstance(memories, dict) and 'results' in memories:
        memories = memories['results']
    if not memories:
        return "No memories stored."
    formatted = []
    for m in memories:
        if isinstance(m, dict):
            formatted.append(m.get("memory", str(m)))
        else:
            formatted.append(str(m))
    return "\n---\n".join(formatted)    