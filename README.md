**THIS IS A DEVELOPMENT/DEMO STARTER KIT — NOT PRODUCTION-READY**

This repository is a starter/boilerplate for development and demos. Do NOT use the default configuration, credentials, or secrets in production.


# Agentic App Starter Kit

A complete starter kit for building AI-powered agentic applications with long-term memory capabilities. This project demonstrates a modular architecture using Open Source libraries such as LangGraph agents, Python based MCP servers, Milvus Vector databases, and LiteLLM AI gateways.

**What this provides:**
- A prescriptive way to run the non-LLM components of your agentic stack **locally** to improve developer velocity
- Deploy all agentic app components on AWS ECS seamlessly to go from laptop to serving customers

# Design Decisions
The key for this repo is to utilise the following design choices for your agentic applications.

## Build with Open APIs
Use as much Open APIs for all the components of your application. The benfits is that it would allow seamless selection of the right provider. This project adopted the following:

**Model Flexibility with Open AI API :** Using Open AI APIs for model gives you flexibility to use any model or mix of models without changing code. You can use self hosted models (such as vLLM runtime) or Model service via API gateway which translates Open AI API call to specific model interface.

**End to End Visibility wit OTEL :** Agentic application are distributed applications. You will need to collect data at diff stages to assess if a call meets a business requirements or not. Using Open Telemetry, will allow to not only trace all the components of your application but help evaluating your Agent. With OTEL, you can choose observability backend of your choice, such as Amazon CLoudWatch or Prometheus.

**Choice of Long Term Memory with Mem0 :** Using Mem0 protocol for integrating Long Term Memory for your agent, give you flexibility to use the best available choice in your eco-system. You can opt-in for Milvus (as in this repo) or any cloud provided memory store suitable for your eco-system without chaning your agent.

```mermaid
flowchart TD
    subgraph APIs [Build with Open APIs]
        direction TB
        
        subgraph Pillars [Standardized Interfaces]
            direction LR
            Model[Model Flexibility<br/>OpenAI API]
            Vis[Visibility<br/>OpenTelemetry]
            Mem[Memory<br/>Mem0 Protocol]
            MCP[Tool and Data Access<br/>Model Context Protocol]

        end
        
        Model --- ModelDesc[Swap models seamlessly without code changes]
        Vis --- VisDesc[Vendor-neutral tracing and evaluation]
        Mem --- MemDesc[Standardized long-term memory operations]
        MCP --- MCPDesc[Standardized protocol for tools and data]
    end

    style Model fill:#4ecdc4,color:#fff
    style Vis fill:#ff6b6b,color:#fff
    style Mem fill:#f9a825,color:#fff
    style MCP fill:#f9a666,color:#fff
    style APIs fill:#f9f9f9,stroke:#333,stroke-width:2px
```


## Comprehensive Evaluation
Write evaluation with the user query and expected outcome (white box testing). And the user query and valdiate tools get called in order, LLM prompt for each interaction during the call and if the data sources are being accessed with right information. You will see in this repo that we have used the OTEL library to collect information and validate it using our evaluation code.

## AI Gateway to access Models and Tools
AI Gateway (LiteLLM) sits between the agent and the LLM backend and the MCP Tools. This approach provides a single point of configuration (such as API Key management, caching) for all different LLMs and MCP tooling. It also provides load balancing and failover capabilities while helping you implment policies such as rate limiting.
LiteLLM AI Gateway, which is being used here, also provides protocol translation  from your LLM BAckend to an OPen AI API compatible format.

## Deployment Flexibility with Containers
Container gives you flexibility to work independently of the hosting runtime. Using containers, you can use Amazon ECS or Amaazon EKS or Amazon AgentCore to deploy your applications as suitable for your scenario. You can choose to deploy on-prem using Kubernete or use other provider such as GKE to host your application. 

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Components](#components)
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Environment Variables Reference](#environment-variables-reference)
- [AWS ECS Deployment](#aws-ecs-deployment)
- [Observability](#observability)
- [Testing](#testing)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Project Structure](#project-structure)

---

## Architecture Overview

```mermaid
flowchart TB
    subgraph Client_Layer [Client Layer]
        User[User]
    end

    subgraph Presentation_Layer [Presentation Layer]
        App[Streamlit App - Port 8501]
    end

    subgraph Application_Layer [Application Layer]
        Agent[LangGraph Agent - Port 8000]
        subgraph Memory_System [Memory System - Mem0]
            Mem0Client[Mem0 Client]
            Embedder[Local Embeddings - sentence-transformers]
        end
        MCP[MCP Server - Port 8000]
    end

    subgraph Infrastructure_Layer [Infrastructure Layer]
        Gateway[AI Gateway - LiteLLM - Port 4000]
        Milvus[(Milvus Vector DB - Port 19530)]
    end

    subgraph External_Services [External Services]
        LLM[LLM Backend - Llama 3.3 70B / Qwen]
    end

    User --> App
    App --> Agent
    Agent --> MCP
    Agent --> Gateway
    
    Agent --> Mem0Client
    Mem0Client --> Embedder
    Mem0Client --> Milvus
    
    Gateway --> LLM

    style App fill:#ff6b6b,color:#fff
    style Agent fill:#4ecdc4,color:#fff
    style MCP fill:#45b7d1,color:#fff
    style Gateway fill:#96ceb4,color:#fff
    style Milvus fill:#dda0dd,color:#fff
    style Mem0Client fill:#f9a825,color:#fff
```

---

## Components

### 1. Streamlit App (`code/app/`)

A chat interface built with Streamlit that provides the user-facing frontend.

| Property | Value |
|----------|-------|
| Port | 8501 |
| Framework | Streamlit |
| Purpose | Chat UI with conversation history |

**Features:**
- Real-time chat interface
- Configurable thread IDs for conversation isolation
- Tool usage visualization with expandable details
- OpenTelemetry instrumentation for distributed tracing

---

### 2. LangGraph Agent (`code/agent/`)

The core AI agent built with LangGraph, featuring intelligent long-term memory via Mem0.

| Property | Value |
|----------|-------|
| Port | 8000 |
| Framework | FastAPI + LangGraph |
| Purpose | AI reasoning with tool use and memory |

**Features:**

- **LangGraph** based agent workflow with conditional tool execution
- **Mem0 Integration**: Managed long-term memory with automatic user session handling
- **Hybrid Storage**: Uses Milvus for vector storage while Mem0 handles metadata
- Local embeddings using `sentence-transformers` (using all-MiniLM-L6-v2 model from hugging face)
- Multi-step reasoning (e.g., recall favorite fruit → get its price)
- OpenTelemetry instrumentation for distributed tracing

**Tools:**
- `save_memory` - Store user facts to long-term memory
- `recall_memory` - Semantic search with relevance scoring
- `get_all_memories` - Retrieve full history for current user
- `get_fruit_price` - MCP tool for fruit prices (demo)

---

### 3. MCP Server (`code/mcp/`)

A Model Context Protocol (MCP) server providing external tool capabilities.

| Property | Value |
|----------|-------|
| Port | 8000 (mapped to 8002 locally) |
| Framework | FastMCP |
| Transport | SSE (Server-Sent Events) |

**Available Tools:**
- `get_fruit_price` - Demo tool returning fruit prices

---

### 4. AI Gateway (`code/ai-gateway/`)

A LiteLLM-based proxy providing a unified OpenAI-compatible API for various LLM backends.

| Property | Value |
|----------|-------|
| Port | 4000 |
| Framework | LiteLLM Proxy |
| Purpose | LLM abstraction and routing |

**Features:**
- OpenAI-compatible API interface
- Support for multiple backends (vLLM, OpenAI, Ollama, Azure, etc.)
- Function calling support
- Streaming responses
- Admin UI at `/ui`

---

### 5. Milvus Vector Database (`code/milvus/`)

Standalone Milvus instance for vector similarity search and long-term memory storage.

| Property | Value |
|----------|-------|
| Ports | 19530 (gRPC), 9091 (HTTP/Health) |
| Version | 2.3.0 |
| Mode | Standalone (embedded etcd) |

---

## Prerequisites

### Required

- **Docker Desktop 4.x+** with Docker Compose v2
- **16GB+ RAM** recommended (Milvus + sentence-transformers model)
- **AWS CLI v2** configured (for ECS deployment)
- **Terraform 1.5+** (for ECS deployment)

### Local LLM Backend (choose one)

| Option | Requirements | Command |
|--------|--------------|---------|
| **vLLM** | ~80GB VRAM for Llama 3.3 70B | `python -m vllm.entrypoints.openai.api_server --model meta-llama/Llama-3.3-70B-Instruct --port 8080` |
| **Ollama** | 8GB+ RAM for smaller models | `ollama serve && ollama pull llama3.2` |
| **OpenAI API** | API key | Modify `config.yaml` |


### Optional

- **HuggingFace Token** - For private embedding models
- **Langfuse Account** - For production observability

---

## Local Development Setup


### Step 1: Clone Repository

```bash
git clone <repository-url>
cd agentic-app-starter-kit
```

### Step 2: Configure LLM Backend

**Option A: Use mlx on macos**
For example, to run llama 8B on macos with mlx use the following:

```bash
mkdir ~/llama-local
cd ~llama-local
python3 -m venv .venv
source .venv/bin/activate
pip install mlx-lm
export HUGGING_FACE_HUB_TOKEN=XXXXXXXX
mlx_lm.server --model mlx-community/Meta-Llama-3-8B-Instruct-4bit  --port 8080
```

**Option B: Local vLLM Server (GPU required)**
```bash
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.3-70B-Instruct \
    --port 8080 \
    --tensor-parallel-size 4
```

**Option C: Ollama (CPU/smaller GPU)**
```bash
# Install Ollama from https://ollama.ai
ollama serve
ollama pull llama3.2

# Update code/ai-gateway/config.yaml:
```
```yaml
model_list:
  - model_name: llama-distributed
    litellm_params:
      model: ollama/llama3.2
      api_base: http://host.docker.internal:11434
```

**Option D: OpenAI API**
```yaml
# Update code/ai-gateway/config.yaml:
model_list:
  - model_name: llama-distributed
    litellm_params:
      model: gpt-4o-mini
      api_key: os.environ/OPENAI_API_KEY
```

### Step 3: Start Services

Note: Always run with --build to ensure your local code changes in code are applied, overriding the remote images specified in the configuration.

```bash
# Build and start all containers
docker compose up --build -d

# Watch logs (Milvus takes ~90s to start)
docker compose logs -f
```

### Step 4: Verify Services

```bash
# Check all containers are running
docker compose ps

# Test agent health
curl http://localhost:8000/health

# Test Milvus health
curl http://localhost:9091/healthz

# Test AI Gateway health
curl http://localhost:4000/health
```

### Step 5: Access Application

| Service | URL |
|---------|-----|
| Streamlit UI | http://localhost:8501 |
| Agent API | http://localhost:8000 |
| AI Gateway | http://localhost:4000 |
| AI Gateway UI | http://localhost:4000/ui |
| Jaeger UI | http://localhost:16686 |
| MCP Server | http://localhost:8002 |
| Milvus | localhost:19530 |

### Step 6: Test the Agent

```bash
# Save a memory
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "My name is Alice and my favorite fruit is mango", "thread_id": "test"}'

# Recall memory
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is my name?", "thread_id": "test"}'

# Multi-step reasoning (recall + tool)
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the price of my favorite fruit?", "thread_id": "test"}'
```

### Development Workflow

```bash
# Restart a single service after code changes
docker compose restart agent

# View real-time logs
docker compose logs -f agent

# Rebuild a single service
docker compose up --build agent

# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

---

## Environment Variables Reference

### Agent Service (`code/agent/`)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OPENAI_API_KEY` | API key for LLM gateway | `sk-123456` | Yes |
| `OPENAI_BASE_URL` | LLM endpoint URL | `http://ai-gateway:4000` | Yes |
| `MODEL_NAME` | Model identifier | `llama-distributed` | Yes |
| `MILVUS_HOST` | Milvus hostname | `milvus` | Yes |
| `MILVUS_PORT` | Milvus gRPC port | `19530` | Yes |
| `MCP_HOST` | MCP server hostname | `mcp` | Yes |
| `MCP_PORT` | MCP server port | `8000` | Yes |
| `HF_TOKEN` | HuggingFace API token | - | No |
| `EMBEDDING_MODEL` | Sentence transformer model | `all-MiniLM-L6-v2` | No |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint | `http://jaeger:4318` | No |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | OTLP protocol | `http/protobuf` | No |
| `OTEL_EXPORTER_OTLP_HEADERS` | Auth headers for OTLP | - | No |
| `LANGFUSE_PUBLIC_KEY` | Langfuse public key | - | No |
| `LANGFUSE_SECRET_KEY` | Langfuse secret key | - | No |
| `LANGFUSE_BASE_URL` | Langfuse API URL | - | No |

### AI Gateway Service (`code/ai-gateway/`)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OPENAI_API_KEY` | Upstream API key | `sk-123456` | Yes |
| `LITELLM_MASTER_KEY` | LiteLLM admin key | `sk-123456` | No |
| `UI_USERNAME` | LiteLLM UI username | `admin` | No |
| `UI_PASSWORD` | LiteLLM UI password | `12345678` | No |

### App Service (`code/app/`)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `AGENT_HOST` | Agent service URL | `http://agent:8000` | Yes |
| `CHAT_ENDPOINT` | Agent chat endpoint | `http://agent:8000/chat` | Yes |
| `THREAD_ID` | Default conversation thread | `default` | No |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint | `http://jaeger:4318` | No |

---

## AWS ECS Deployment

### Architecture

```mermaid
flowchart TB
    subgraph Public_Internet [Public Internet]
        Users[Users]
    end

    subgraph AWS_Cloud [AWS Cloud]
        subgraph VPC [VPC - 10.0.0.0/16]
            subgraph Public_Subnets [Public Subnets]
                ALB[Application Load Balancer - Port 443]
                NAT[NAT Gateway]
            end

            subgraph Private_Subnets [Private Subnets]
                subgraph ECS_Cluster [ECS Cluster - Fargate]
                    AppTask[App Service]
                    AgentTask[Agent Service]
                    MCPTask[MCP Service]
                    MilvusTask[Milvus Service]
                    GatewayTask[AI Gateway Service]
                    OTELCollector[OTEL Collector]
                end
            end

            CloudMap[AWS Cloud Map - Service Discovery]
        end

        subgraph Observability [Observability]
            CWLogs[CloudWatch Logs]
            XRay[AWS X-Ray]
        end
    end

    Users --> ALB
    ALB --> AppTask
    AppTask --> AgentTask
    AgentTask --> MCPTask
    AgentTask --> MilvusTask
    AgentTask --> GatewayTask
    OTELCollector --> CWLogs
    OTELCollector --> XRay

    style ALB fill:#ff9800,color:#fff
    style AppTask fill:#ff6b6b,color:#fff
    style AgentTask fill:#4ecdc4,color:#fff
    style OTELCollector fill:#f9a825,color:#fff
```

### Step 1: Build and Push Container Images

```bash
# Authenticate to ECR Public
aws ecr-public get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin public.ecr.aws

# Build and push ARM64 images
for svc in agent app mcp ai-gateway milvus; do
  cd code/$svc
  docker build --platform linux/arm64 -t public.ecr.aws/YOUR_REGISTRY/$svc:latest .
  docker push public.ecr.aws/YOUR_REGISTRY/$svc:latest
  cd -
done
```

### Step 2: Configure Terraform Variables

Create `iac/terraform.tfvars`:

```hcl
aws_region   = "ap-southeast-2"
project_name = "agentic-app"

# IMPORTANT: Restrict ALB access to your IP
allowed_ip = "YOUR_IP/32"  # Get with: curl ifconfig.me

# Custom images (optional)
app_image       = "public.ecr.aws/YOUR_REGISTRY/app:latest"
agent_image     = "public.ecr.aws/YOUR_REGISTRY/agent:latest"
mcp_image       = "public.ecr.aws/YOUR_REGISTRY/mcp:latest"
aigateway_image = "public.ecr.aws/YOUR_REGISTRY/aigateway:latest"
milvus_image    = "public.ecr.aws/YOUR_REGISTRY/milvus:latest"

# Auto-scaling configuration
app_min_capacity   = 1
app_max_capacity   = 4
agent_min_capacity = 1
agent_max_capacity = 6
```

### Step 3: Deploy Infrastructure

```bash
cd iac

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (~10-15 minutes)
terraform apply

# Get outputs
terraform output
```

### Step 4: Verify Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test application (HTTPS with self-signed cert)
curl -k https://$ALB_DNS

# Check ECS services
aws ecs list-services \
  --cluster agentic-app-cluster \
  --region ap-southeast-2

# View service logs
aws logs tail /ecs/agentic-app/agent \
  --follow \
  --region ap-southeast-2
```

### Step 5: Force Redeploy (after image updates)

```bash
for svc in app-service agent-service mcp-service milvus-service aigateway-service; do
  aws ecs update-service \
    --cluster agentic-app-cluster \
    --service $svc \
    --force-new-deployment \
    --region ap-southeast-2
done
```

### Step 6: Cleanup

```bash
cd iac
terraform destroy
```

### Terraform Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `ap-southeast-2` |
| `project_name` | Resource name prefix | `agentic-app` |
| `allowed_ip` | CIDR for ALB access | `0.0.0.0/0` |
| `app_image` | App container image | Public ECR |
| `agent_image` | Agent container image | Public ECR |
| `mcp_image` | MCP container image | Public ECR |
| `milvus_image` | Milvus container image | Public ECR |
| `aigateway_image` | AI Gateway image | Public ECR |
| `app_min_capacity` | Min app tasks | `1` |
| `app_max_capacity` | Max app tasks | `4` |
| `agent_min_capacity` | Min agent tasks | `1` |
| `agent_max_capacity` | Max agent tasks | `6` |
| `mcp_min_capacity` | Min MCP tasks | `1` |
| `mcp_max_capacity` | Max MCP tasks | `4` |
| `aigateway_min_capacity` | Min gateway tasks | `1` |
| `aigateway_max_capacity` | Max gateway tasks | `4` |
| `enable_scheduled_scaling` | Off-peak scaling | `false` |

### Terraform Outputs

| Output | Description |
|--------|-------------|
| `alb_dns_name` | Application Load Balancer DNS |
| `ecs_cluster_name` | ECS cluster name |
| `vpc_id` | VPC ID |

---

## Observability

### Local Development (Jaeger)

Traces are sent to Jaeger by default:

| Endpoint | URL |
|----------|-----|
| Jaeger UI | http://localhost:16686 |
| OTLP gRPC | localhost:4317 |
| OTLP HTTP | localhost:4318 |

### Production (Langfuse)

To use Langfuse for production observability:

1. Create Langfuse account and get API keys

2. Generate auth header:
```bash
echo -n "pk-lf-xxx:sk-lf-xxx" | base64
```

3. Update docker-compose.yaml:
```yaml
environment:
  - OTEL_EXPORTER_OTLP_ENDPOINT=https://cloud.langfuse.com/api/public/otel/v1/traces
  - OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic <base64-output>
  - OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

### AWS (CloudWatch + X-Ray)

ECS deployment includes ADOT collector that sends:
- **Traces** → AWS X-Ray
- **Logs** → CloudWatch Logs
- **Metrics** → CloudWatch Metrics

CloudWatch Log Groups:

| Service | Log Group |
|---------|-----------|
| App | `/ecs/agentic-app/app` |
| Agent | `/ecs/agentic-app/agent` |
| MCP | `/ecs/agentic-app/mcp` |
| Milvus | `/ecs/agentic-app/milvus` |
| AI Gateway | `/ecs/agentic-app/aigateway` |
| OTEL Collector | `/ecs/agentic-app/otel-collector` |

---

## Testing

### Run End-to-End Tests

The evaluation script runs a "Happy Path" scenario: saving a secret code to memory, recalling it, and checking fruit prices.

```bash
# Ensure services are running
docker compose up -d

# Wait for Milvus to be healthy
sleep 90

# Run evaluation suite
cd code/evaluation
pip install -r requirements.txt
python e2e_evaluate_agent.py
```

### Test Cases

The evaluation suite validates:

| Test | Description |
|------|-------------|
| Health Check | Agent API availability |
| Memory Storage | Save facts to long-term memory |
| Memory Recall | Retrieve previously saved facts |
| MCP Tool Calls | External tool execution |
| Trace Collection | Verify OTEL traces in Jaeger |

### Manual API Testing

```bash
# Health check
curl http://localhost:8000/health

# Save memory
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "My favorite color is blue", "thread_id": "test"}'

# Recall memory
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is my favorite color?", "thread_id": "test"}'

# Test MCP tool
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the price of apples?", "thread_id": "test"}'

# Multi-step reasoning
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is the price of my favorite fruit?", "thread_id": "test"}'
```

---

## API Reference

### Agent API (`http://localhost:8000`)

#### POST /chat

Send a message to the agent.

**Request:**
```json
{
  "message": "Hello, my name is Alice",
  "thread_id": "user-123"
}
```

**Response:**
```json
{
  "response": "Hello Alice! I've noted your name. How can I help you today?",
  "tool_usage": [
    [{"name": "save_memory", "args": {"content": "User's name is Alice"}}]
  ]
}
```

#### GET /health

Health check endpoint.

**Response:**
```json
{"status": "ok"}
```

### MCP Server (`http://localhost:8002`)

#### GET /sse

Server-Sent Events endpoint for MCP protocol.

#### Available Tools

| Tool | Parameters | Description |
|------|------------|-------------|
| `get_fruit_price` | `fruit_name: str` | Returns price for given fruit |

---

## Troubleshooting

### Container Permission Errors

**Error:** `PermissionError: [Errno 13] Permission denied: '/home/appuser'`

**Cause:** Python packages (mem0, torch) try to write to home directory.

**Solution:** Dockerfiles set `ENV HOME=/tmp` for writable temp directory. Rebuild images:
```bash
docker compose build --no-cache
```

---

### Milvus Startup Issues

**Error:** Milvus container unhealthy or restarting

**Solution:**
```bash
# Milvus needs 60-90 seconds to start
docker compose logs milvus

# Verify health endpoint
curl http://localhost:9091/healthz
```

---

### MCP Connection Failures

**Error:** `Failed to connect to MCP server`

**Cause:** Port mismatch between host and container.

**Solution:** Agent uses internal Docker port:
```yaml
environment:
  - MCP_HOST=mcp
  - MCP_PORT=8000  # Internal port, not 8002
```

---

### OTEL/Langfuse Header Errors

**Error:** `Header format invalid!`

**Cause:** Incorrect OTEL header format.

**Solution:** Use plain format without URL encoding:
```yaml
# Correct
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic cGstbGYteHh4OnNrLWxmLXh4eA==

# Wrong (URL encoded)
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic%20cGstbGYteHh4...
```

---

### LLM Connection Issues

**Error:** Agent returns empty responses or timeouts

**Solutions:**
1. Verify LLM server is running on port 8080
2. For Mac/Windows: `host.docker.internal:8080` resolves to host
3. For Linux: Add `--add-host=host.docker.internal:host-gateway` to docker run
4. Check AI Gateway logs: `docker compose logs ai-gateway`

---

### ECS Task Failures

**Error:** Tasks failing health checks in ECS

**Common causes:**
1. **PyTorch temp files:** Containers need tmpfs mount for `/tmp`
2. **Startup time:** Increase `startPeriod` (60-90s for Milvus)
3. **Memory:** Increase task memory if OOM killed

**Debug:**
```bash
# Check task failures
aws ecs describe-services \
  --cluster agentic-app-cluster \
  --services agent-service \
  --region ap-southeast-2

# View stopped task reason
aws ecs describe-tasks \
  --cluster agentic-app-cluster \
  --tasks <task-arn> \
  --region ap-southeast-2
```

---

### Mem0 Milvus Connection Errors

**Error:** `Connection refused` or `token required`

**Solution:** Mem0 config requires `url` format and empty `token`:
```python
mem0_config = {
    "vector_store": {
        "provider": "milvus",
        "config": {
            "url": f"http://{MILVUS_HOST}:{MILVUS_PORT}",
            "token": "",  # Required even for local Milvus
        }
    }
}
```

---

## Security Considerations

⚠️ **This is a development starter kit. For production:**

### Secrets Management
- Replace hardcoded `sk-123456` with AWS Secrets Manager
- Use IAM roles instead of API keys where possible
- Rotate credentials regularly

### Network Security
- Set `allowed_ip` to your specific IP/CIDR
- All services run in private subnets (already configured)
- Enable VPC Flow Logs for audit

### Container Security
- All containers run as non-root user (`appuser`)
- `readonlyRootFilesystem=true` with tmpfs for `/tmp`
- No shell access (`-s /bin/false`)
- Minimal base images

### TLS/HTTPS
- Current setup uses self-signed certificate
- For production: Use ACM certificate with custom domain

### Data Encryption
- Enable encryption at rest for Milvus data (EBS encryption)
- Enable CloudWatch Logs encryption with KMS

---

## Project Structure

```
.
├── code/
│   ├── agent/           # LangGraph AI Agent with Mem0
│   │   ├── main.py
│   │   ├── requirements.txt
│   │   ├── Dockerfile
│   │   └── .env.example
│   ├── ai-gateway/      # LiteLLM Proxy
│   │   ├── config.yaml
│   │   └── Dockerfile
│   ├── app/             # Streamlit Frontend
│   │   ├── main.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── mcp/             # MCP Tool Server
│   │   ├── main.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── milvus/          # Milvus Dockerfile
│   │   └── Dockerfile
│   └── evaluation/      # Test suite
│       ├── e2e_evaluate_agent.py
│       └── evaluation.py
├── iac/                 # Terraform IaC for AWS ECS
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── networking.tf
│   ├── security.tf
│   ├── ecs.tf
│   ├── alb.tf
│   ├── cert.tf
│   └── autoscaling.tf
├── k8s/                 # Kubernetes manifests (alternative)
│   └── README.md
├── private/             # Build scripts and backups
├── docker-compose.yaml  # Local development
└── README.md
```

---

## Kubernetes Deployment

For Kubernetes deployment (EKS, GKE, AKS, or local), see [k8s/README.md](k8s/README.md).

---

## License

MIT

---

## TODO

- Add semantic matching in end-to-end tests (LLM as a judge)
- Add Kubernetes Helm chart
- Add CI/CD pipeline examples
