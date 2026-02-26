import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

# OpenTelemetry
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.langchain import LangchainInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor

# LangChain / LangGraph
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver
# from langchain.agents import create_agent

# MCP
from langchain_mcp_adapters.client import MultiServerMCPClient

# Mem0
from mem0 import Memory
from sentence_transformers import SentenceTransformer

from tool import setup_telemetry, save_memory, recall_memory, get_all_memories, get_embedding_dim

load_dotenv()


LoggingInstrumentor().instrument(set_logging_format=True)
logging.basicConfig(
    format='%(asctime)s %(levelname)s [trace_id=%(otelTraceID)s span_id=%(otelSpanID)s] %(message)s',
    level=logging.INFO
)
logging.getLogger("httpx").setLevel(logging.WARNING)
logger = logging.getLogger(__name__)

# ============================================================================
# Configuration
# ============================================================================
MILVUS_HOST = os.getenv("MILVUS_HOST", "milvus-standalone")
MILVUS_PORT = os.getenv("MILVUS_PORT", "19530")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "sk-123456")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "http://ai-gateway:4000")
MODEL_NAME = os.getenv("MODEL_NAME", "llama-distributed")

# make sure that this model is baked into the image and available locally for this agent code
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")

MCP_HOST = os.getenv("MCP_HOST", "mcp")
MCP_PORT = os.getenv("MCP_PORT", "8000")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318/v1/traces")

SYSTEM_PROMPT = """You are a helpful and friendly AI assistant with persistent long-term memory that spans across conversations.

You have access to a memory system that stores facts from ALL past conversations. Even if you don't see prior messages in this conversation, the user may have told you things before that are stored in memory.

## Available Tools:
- `save_memory`: Save facts about the user to long-term memory
- `recall_memory`: Search memory for previously saved information
- `get_fruit_price`: Get the current price of a specific fruit

## CRITICAL RULES:

1. **ALWAYS check memory first**: When the user asks about ANY personal information (their name, preferences, codes, favorites, etc.), you MUST call `recall_memory` BEFORE responding. NEVER say "I don't know" or "I don't have that information" without first calling recall_memory to check. This applies even if you have no conversation history — memories persist across sessions.

2. **Saving is MANDATORY**: When the user shares ANY personal fact (name, preferences, codes, numbers, etc.), you MUST call `save_memory` with the exact information verbatim. Do NOT respond without calling the tool first. NEVER say "I've saved" or "noted" without actually calling save_memory.

3. **Fruit Prices**: Use `get_fruit_price` when asked about fruit prices.

4. **Multi-Step**: Some questions need multiple tools in sequence:
   - "What is the price of my favourite fruit?"
     → First call recall_memory("favourite fruit"), then call get_fruit_price with the result.

5. **Chat Naturally**: For greetings or general questions with no personal info, reply directly.
"""

SYSTEM_PROMPT_V2 = """You are a highly capable, friendly, and intelligent AI assistant. You have access to a persistent long-term memory system that spans across all past conversations with the user, as well as external tools.

## Core Persona & Behavior
- **Be Conversational & Natural:** For general knowledge questions, greetings, or casual chat, respond directly and naturally.
- **Format Clearly:** Use Markdown, bullet points, and bold text to make your answers easy to read.
- **Silent Execution:** Do not narrate your tool usage. Never say "I am saving this to memory" or "I am checking my tools." Just execute the tool and provide the final answer.
- **Admit When You Don't Know:** If a memory search returns no results, honestly state that you don't have that information and ask the user to provide it.

## Available Tools:
- `save_memory`: Save facts about the user to long-term memory
- `recall_memory`: Search memory for previously saved information
- `get_fruit_price`: Get the current price of a specific fruit

## Memory Management (CRITICAL)
You have access to `save_memory` and `recall_memory`. Memories persist across sessions.

1. **When to SAVE:** 
   - You MUST use `save_memory` when the user shares ENDURING personal facts, preferences, relationships, locations, or important codes (e.g., "I am a software engineer", "I'm allergic to peanuts", "My dog's name is Max").
   - DO NOT save temporary states or conversational filler (e.g., "I'm hungry right now", "Hello").
   - Save the information verbatim.

2. **When to RECALL:**
   - You MUST use `recall_memory` BEFORE answering if the user asks about themselves, their preferences, or references past context (e.g., "What is my favorite...", "Do you remember my...", "Based on my job...").
   - Never say "I don't know" to a personal question without checking memory first.

## External Tools & Multi-Step Reasoning
You have access to external tools provided by MCP servers (e.g., `get_fruit_price`).

- **Use Tools Dynamically:** Whenever the user asks for real-time data, pricing, or external actions, check if you have a tool that can fulfill the request.
- **Chain Tools When Necessary:** Break complex questions down. If a user asks a question that requires personal context AND external data, use tools in sequence.
  *Example:* "What is the price of my favorite fruit?"
  -> Step 1: `recall_memory("favorite fruit")` (Result: Apple)
  -> Step 2: `get_fruit_price("Apple")`
  -> Step 3: Provide the final conversational answer.
"""


# """You are a helpful and friendly AI assistant with long-term memory capabilities.

# ## Available Tools:
# - `save_memory`: Save facts about the user to long-term memory
# - `recall_memory`: Search memory for previously saved information
# - `get_fruit_price`: Get the current price of a specific fruit

# ## Guidelines:

# 1. **Chat Naturally**: For greetings or simple questions, reply directly without tools.

# 2. **Save Facts**: When the user shares ANY personal information, you MUST call the `save_memory` tool. 
#    Do NOT just acknowledge the information - you MUST invoke the tool to persist it.
#    - "My name is Alice" → MUST call save_memory("User's name is Alice")
#    - "My favourite fruit is apple" → MUST call save_memory("User's favourite fruit is apple")
#    Never say you've saved something without actually calling save_memory. 

# 3. **Recall Before Acting**: When the user references personal context (e.g., "my favourite", "my name"), 
#    ALWAYS use `recall_memory` FIRST to retrieve that information before taking any other action.

# 4. **Multi-Step Reasoning**: Some questions require multiple tool calls in sequence:
#    - Example: "What is the price of my favourite fruit?"
#      Step 1: Use `recall_memory` with query "favourite fruit"
#      Step 2: Use `get_fruit_price` with the fruit name from memory

# 5. **Fruit Prices**: Use `get_fruit_price` when the user asks about fruit prices.

# 6. **Final Answer**: After using tools, synthesize the results into a natural conversational response.
# """



def create_memory():
    """Create Mem0 memory client with Milvus backend."""
    return Memory.from_config({
        "llm": {
            "provider": "openai",
            "config": {
                "model": MODEL_NAME,
                "api_key": OPENAI_API_KEY,
                "openai_base_url": OPENAI_BASE_URL,
                "temperature": 0
            }
        },        
        "vector_store": {
            "provider": "milvus",
            "config": {
                "collection_name": "mem0_agent_memory",
                "url": f"http://{MILVUS_HOST}:{MILVUS_PORT}",
                "token": "",
                "embedding_model_dims": get_embedding_dim(EMBEDDING_MODEL),
            }
        },
        "embedder": {
            "provider": "huggingface",
            "config": {"model": EMBEDDING_MODEL}
        }
    })


# Initialize telemetry and memory
setup_telemetry(OTEL_ENDPOINT)
memory = create_memory()
# set_memory(memory)

# Initialize LLM
llm = ChatOpenAI(
    openai_api_key=OPENAI_API_KEY,
    openai_api_base=OPENAI_BASE_URL,
    model_name=MODEL_NAME,
    temperature=0
)





local_tools = [save_memory, recall_memory, get_all_memories]


# ============================================================================
# Agent Graph (Simplified with create_react_agent)
# ============================================================================
mcp_tools = []
app_graph = None
checkpointer = MemorySaver()


async def init_agent():
    """Initialize MCP tools and create the ReAct agent."""
    global mcp_tools, app_graph
    
    # Load MCP tools
    mcp_url = f"http://{MCP_HOST}:{MCP_PORT}/sse"
    logger.info(f"Connecting to MCP server at {mcp_url}...")
    
    try:
        mcp_client = MultiServerMCPClient({
            "fruit_prices": {
                "url": mcp_url,
                "transport": "sse",
            }
        })
        mcp_tools = await mcp_client.get_tools()
        logger.info(f"Loaded {len(mcp_tools)} MCP tools: {[t.name for t in mcp_tools]}")
    except Exception as e:
        logger.warning(f"Failed to connect to MCP server: {e}")
        mcp_tools = []
    
    # Create ReAct agent with all tools
    all_tools = local_tools + mcp_tools
    logger.info(f"Creating ReAct agent with {len(all_tools)} tools")
    
    # In LangGraph v1.0+, system prompt is passed via SystemMessage in the invoke call
    # or by binding it to the model
    app_graph = create_react_agent(
        llm, 
        all_tools,
        checkpointer=checkpointer
    )
    
    logger.info("ReAct agent initialized successfully")


# ============================================================================
# FastAPI App
# ============================================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - initialize agent on startup."""
    await init_agent()
    yield


app = FastAPI(title="LangGraph Agent API", lifespan=lifespan)
FastAPIInstrumentor.instrument_app(app)


class ChatRequest(BaseModel):
    message: str
    thread_id: str = "default"


@app.post("/chat")
async def chat(request: ChatRequest):
    """Chat endpoint - send a message to the agent."""
    if app_graph is None:
        logger.error("Agent not initialized yet")
        raise HTTPException(status_code=503, detail="Agent not initialized yet")
    
    # Invoke the agent with system prompt + user message
    result = await app_graph.ainvoke(
        {"messages": [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(content=request.message)
        ]},
        config={"configurable": {
            "thread_id": request.thread_id,
            "memory_client": memory
        }}
    )
    
    # Extract response and tool usage
    last_message = result["messages"][-1]
    tool_usage = [
        m.tool_calls for m in result["messages"] 
        if hasattr(m, 'tool_calls') and m.tool_calls
    ]
    
    return {
        "response": last_message.content,
        "tool_usage": tool_usage
    }


@app.get("/health")
def health():
    """Health check endpoint."""
    if app_graph is None:
        raise HTTPException(status_code=503, detail="Agent not initialized yet")

    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
