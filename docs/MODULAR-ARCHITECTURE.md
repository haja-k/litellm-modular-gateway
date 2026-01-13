# LiteLLM Modular Gateway Architecture

## Overview

This deployment uses **modular LiteLLM gateway architecture** where different AI capabilities are separated into independent modules, each with its own:
- Dedicated deployment and replicas
- Separate configuration and model list
- Unique endpoint/port
- Independent quota management
- Isolated monitoring and logging

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                     │
│  ┌──────────┐    ┌────────────┐    ┌────────────┐          │
│  │ Postgres │    │ Prometheus │    │   Schema   │          │
│  │  :5432   │    │   :9090    │    │  ConfigMap │          │
│  └──────────┘    └────────────┘    └────────────┘          │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ (Shared by all modules)
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼──────┐    ┌────────▼────────┐   ┌──────▼───────┐
│  LLM Module  │    │ Vision Module   │   │Audio Module  │
│              │    │                 │   │              │
│ :30100       │    │ :30200          │   │ :30300       │
│ 2 replicas   │    │ 1 replica       │   │ 1 replica    │
└──────────────┘    └─────────────────┘   └──────────────┘

┌──────────────────┐    ┌──────────────────┐
│ Image-Gen Module │    │Embeddings Module │
│                  │    │                  │
│ :30400           │    │ :30500           │
│ 1 replica        │    │ 1 replica        │
└──────────────────┘    └──────────────────┘
```

## Modules

### 1. LLM Module (Port 30100)
**Purpose**: Text generation and chat completions  
**Endpoints**: `/v1/chat/completions`, `/v1/completions`  
**Models**: 
- gpt-4.1
- deepseek
- qwen
- llama
- gpt-oss

**Backend**: Ollama (via `host.minikube.internal:11434`)

### 2. Vision Module (Port 30200)
**Purpose**: Image-to-text and vision capabilities  
**Endpoints**: `/v1/chat/completions` (with image inputs)  
**Models**:
- gpt-4-vision
- llava
- bakllava
- vision-general

**Backend**: Ollama LLaVA models (via `host.minikube.internal:11434`)

### 3. Audio Module (Port 30300)
**Purpose**: Speech-to-text transcription and translation  
**Endpoints**: `/v1/audio/transcriptions`, `/v1/audio/translations`  
**Models**:
- whisper
- whisper-large
- speech-to-text

**Backend**: Whisper-compatible API (requires setup at `host.minikube.internal:8000`)

### 4. Image Generation Module (Port 30400)
**Purpose**: Text-to-image generation  
**Endpoints**: `/v1/images/generations`  
**Models**:
- dall-e-3
- stable-diffusion
- image-gen

**Backend**: Image generation API (requires setup at `host.minikube.internal:7860`)

### 5. Embeddings Module (Port 30500)
**Purpose**: Text embeddings for semantic search and RAG  
**Endpoints**: `/v1/embeddings`  
**Models**:
- text-embedding-ada-002
- nomic-embed-text
- all-minilm
- embeddings

**Backend**: Ollama embedding models (via `host.minikube.internal:11434`)

## Deployment

### Quick Start

1. **Deploy all modules**:
   ```bash
   minikube kubectl -- apply -k k8s/
   ```

2. **Check status**:
   ```bash
   minikube kubectl -- get pods
   minikube kubectl -- get services
   ```

3. **Wait for all pods to be ready**:
   ```bash
   minikube kubectl -- wait --for=condition=ready pod -l module=llm --timeout=120s
   minikube kubectl -- wait --for=condition=ready pod -l module=vision --timeout=120s
   minikube kubectl -- wait --for=condition=ready pod -l module=audio --timeout=120s
   minikube kubectl -- wait --for=condition=ready pod -l module=image-gen --timeout=120s
   minikube kubectl -- wait --for=condition=ready pod -l module=embeddings --timeout=120s
   ```

### Deploy Individual Modules

You can deploy modules selectively:

```bash
# Deploy only LLM module
minikube kubectl -- apply -f k8s/postgres-*.yaml
minikube kubectl -- apply -f k8s/prometheus-*.yaml
minikube kubectl -- apply -f k8s/litellm-llm-*.yaml

# Deploy only Vision module
minikube kubectl -- apply -f k8s/litellm-vision-*.yaml

# Deploy only Audio module
minikube kubectl -- apply -f k8s/litellm-audio-*.yaml
```

## Usage Examples

### LLM Module (Chat Completions)
```bash
# Via NodePort
curl http://127.0.0.1:30100/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-llm-module-key" \
  -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Via ClusterIP (from within cluster)
curl http://litellm-llm-gateway:4000/v1/chat/completions ...
```

### Vision Module (Image Understanding)
```bash
curl http://127.0.0.1:30200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-vision-module-key" \
  -d '{
    "model": "gpt-4-vision",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What is in this image?"},
        {"type": "image_url", "image_url": {"url": "https://..."}}
      ]
    }]
  }'
```

### Audio Module (Speech-to-Text)
```bash
curl http://127.0.0.1:30300/v1/audio/transcriptions \
  -H "Authorization: Bearer sk-audio-module-key" \
  -F "file=@audio.mp3" \
  -F "model=whisper"
```

### Image Generation Module
```bash
curl http://127.0.0.1:30400/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-image-gen-module-key" \
  -d '{
    "model": "dall-e-3",
    "prompt": "A beautiful sunset over mountains",
    "n": 1,
    "size": "1024x1024"
  }'
```

### Embeddings Module
```bash
curl http://127.0.0.1:30500/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-embeddings-module-key" \
  -d '{
    "model": "text-embedding-ada-002",
    "input": "Your text here"
  }'
```

## Health Checks

Each module has its own health endpoint:

```bash
# LLM Module
curl http://127.0.0.1:30100/health

# Vision Module
curl http://127.0.0.1:30200/health

# Audio Module
curl http://127.0.0.1:30300/health

# Image Generation Module
curl http://127.0.0.1:30400/health

# Embeddings Module
curl http://127.0.0.1:30500/health
```

## Model Lists

View available models per module:

```bash
# LLM models
curl http://127.0.0.1:30100/v1/models

# Vision models
curl http://127.0.0.1:30200/v1/models

# Audio models
curl http://127.0.0.1:30300/v1/models

# Image generation models
curl http://127.0.0.1:30400/v1/models

# Embedding models
curl http://127.0.0.1:30500/v1/models
```

## Configuration

Each module has its own ConfigMap in `k8s/litellm-{module}-configmap.yaml`:

- **litellm-llm-configmap.yaml** - LLM models configuration
- **litellm-vision-configmap.yaml** - Vision models configuration
- **litellm-audio-configmap.yaml** - Audio models configuration
- **litellm-image-gen-configmap.yaml** - Image generation models configuration
- **litellm-embeddings-configmap.yaml** - Embeddings models configuration

### Updating a Module's Configuration

1. Edit the ConfigMap file
2. Apply the changes:
   ```bash
   minikube kubectl -- apply -f k8s/litellm-{module}-configmap.yaml
   ```
3. Restart the module:
   ```bash
   minikube kubectl -- rollout restart deploy/litellm-{module}-gateway
   ```

### Adding Backend Providers

Each module points to backend inference servers. Update the `api_base` in the ConfigMaps:

**For LLM/Vision/Embeddings** (currently using Ollama):
- Ollama: `http://host.minikube.internal:11434`
- vLLM: `http://host.minikube.internal:8000/v1`
- OpenAI: `https://api.openai.com/v1` (requires API key)

**For Audio** (requires Whisper-compatible server):
- LocalAI: `http://host.minikube.internal:8080/v1`
- faster-whisper-server: `http://host.minikube.internal:8000/v1`
- OpenAI: `https://api.openai.com/v1` (requires API key)

**For Image Generation** (requires image gen server):
- Stable Diffusion WebUI API: `http://host.minikube.internal:7860/v1`
- ComfyUI: `http://host.minikube.internal:8188/v1`
- OpenAI: `https://api.openai.com/v1` (requires API key)

## Monitoring

All modules send metrics to the shared Prometheus instance:

```bash
# Prometheus UI (via NodePort)
http://127.0.0.1:30900

# Query metrics for specific module
http://127.0.0.1:30900/graph?g0.expr=litellm_requests_total{module="llm"}
```

## Scaling

Scale individual modules based on demand:

```bash
# Scale LLM module (high traffic)
minikube kubectl -- scale deploy/litellm-llm-gateway --replicas=4

# Scale Vision module
minikube kubectl -- scale deploy/litellm-vision-gateway --replicas=2

# Scale Audio module
minikube kubectl -- scale deploy/litellm-audio-gateway --replicas=2
```

## Authentication

Each module has its own master key defined in the ConfigMap:
- LLM: `sk-llm-module-key`
- Vision: `sk-vision-module-key`
- Audio: `sk-audio-module-key`
- Image-Gen: `sk-image-gen-module-key`
- Embeddings: `sk-embeddings-module-key`

**Change these keys in production!**

## Troubleshooting

### Module not responding
```bash
# Check pod status
minikube kubectl -- get pods -l module=llm

# Check logs
minikube kubectl -- logs -l module=llm --tail=50

# Restart module
minikube kubectl -- rollout restart deploy/litellm-llm-gateway
```

### Backend connection issues
```bash
# Test backend from within cluster
minikube kubectl -- run test --image=curlimages/curl:latest --rm -it -- \
  curl http://host.minikube.internal:11434/api/tags
```

### DNS issues
```bash
# Test service discovery
minikube kubectl -- run dnstest --image=busybox:1.36 --rm -it -- \
  nslookup litellm-llm-gateway
```

## Benefits of Modular Architecture

1. **Isolation**: Each module can be updated, scaled, and monitored independently
2. **Resource Optimization**: Allocate resources based on module-specific needs
3. **Clear Separation**: Different teams can manage different modules
4. **Flexibility**: Enable/disable modules without affecting others
5. **Security**: Separate API keys and quotas per module
6. **Performance**: Distribute load across specialized endpoints
7. **Debugging**: Easier to identify issues in specific capabilities

## Migration from Monolithic

The old monolithic gateway (`litellm-gateway`) has been replaced with 5 specialized modules. Update your client code:

**Before** (monolithic):
```
http://127.0.0.1:30500/v1/chat/completions  # All models
```

**After** (modular):
```
http://127.0.0.1:30100/v1/chat/completions  # LLM models
http://127.0.0.1:30200/v1/chat/completions  # Vision models
http://127.0.0.1:30300/v1/audio/transcriptions  # Audio models
http://127.0.0.1:30400/v1/images/generations  # Image generation
http://127.0.0.1:30500/v1/embeddings  # Embeddings
```

## Next Steps

1. Set up backend inference servers (Ollama, Whisper, etc.)
2. Update ConfigMaps with real backend endpoints
3. Change default API keys
4. Set up proper monitoring dashboards
5. Configure resource limits based on usage
6. Set up ingress/load balancer for production
