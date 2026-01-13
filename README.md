
# LiteLLM Modular Minikube Deployment

## Overview
This repository provides a modular LiteLLM gateway architecture. Each AI capability is deployed as an independent module, with its own endpoint, configuration, and quota management. The monolithic gateway is replaced by the following specialized modules:

- **LLM Module** (Port 30100): Chat completions and text generation
- **Vision Module** (Port 30200): Image-to-text
- **Audio Module** (Port 30300): Speech-to-text
- **Image Generation Module** (Port 30400): Text-to-image
- **Embeddings Module** (Port 30500): Text embeddings for retrieval-augmented generation (RAG) and search

For detailed architecture, see **[MODULAR-ARCHITECTURE.md](docs/MODULAR-ARCHITECTURE.md)**.

---


## Table of Contents
1. Quick Start
2. Architecture
3. Module Endpoints
4. Prerequisites
5. Deployment
6. Configuration
7. Minikube Setup

---


## Quick Start

```bash
# 1. Configure environment variables
cp .env.example .env
nano .env  # Update with credentials

# 2. Deploy all modules
minikube kubectl -- apply -k k8s/

# 3. Check status
minikube kubectl -- get pods
minikube kubectl -- get services

# 4. Test LLM module
curl http://127.0.0.1:30100/v1/models

# 5. Test Vision module
curl http://127.0.0.1:30200/v1/models

# 6. Test Embeddings module
curl http://127.0.0.1:30500/v1/models
```

---


## Architecture

Each module is deployed as an independent LiteLLM gateway. The architecture is as follows:

```
Shared: Postgres (DB) + Prometheus (Metrics)
  │
  ├─► LLM Module (:30100) - 2 replicas
  ├─► Vision Module (:30200) - 1 replica
  ├─► Audio Module (:30300) - 1 replica
  ├─► Image-Gen Module (:30400) - 1 replica
  └─► Embeddings Module (:30500) - 1 replica
```

### Key Features
- Independent scaling of modules based on demand
- Separate configuration and models per module
- Fault isolation for easier debugging
- Distinct API keys and quotas for each module
- Modules can be enabled or disabled independently

---


## Module Endpoints

| Module | Port | Purpose | Example Endpoint |
|--------|------|---------|-----------------|
| LLM | 30100 | Chat completions, text generation | `/v1/chat/completions` |
| Vision | 30200 | Image-to-text, vision models | `/v1/chat/completions` (with images) |
| Audio | 30300 | Speech-to-text transcription | `/v1/audio/transcriptions` |
| Image-Gen | 30400 | Text-to-image generation | `/v1/images/generations` |
| Embeddings | 30500 | Text embeddings | `/v1/embeddings` |

### Example Usage

**LLM Module:**
```bash
curl http://127.0.0.1:30100/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-llm-module-key" \
  -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Vision Module:**
```bash
curl http://127.0.0.1:30200/v1/chat/completions \
  -H "Authorization: Bearer sk-vision-module-key" \
  -d '{
    "model": "llava",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What's in this image?"},
        {"type": "image_url", "image_url": {"url": "..."}}
      ]
    }]
  }'
```

**Embeddings Module:**
```bash
curl http://127.0.0.1:30500/v1/embeddings \
  -H "Authorization: Bearer sk-embeddings-module-key" \
  -d '{
    "model": "text-embedding-ada-002",
    "input": "Your text here"
  }'
```

---


## Prerequisites
- Linux server with Docker and systemd
- Sudo/root access
- Oracle Linux 9.x or compatible
- Minikube v1.37.0+
- Backend inference servers (Ollama, Whisper, etc.) – see Configuration

---


## Deployment

### 1. Deploy All Modules
```bash
# Apply all modules
minikube kubectl -- apply -k k8s/

# Wait for pods to be ready
minikube kubectl -- get pods -w
```

### 2. Verify Deployment
```bash
# Check all pods
minikube kubectl -- get pods

# Check all services
minikube kubectl -- get services

# Test each module’s health
curl http://127.0.0.1:30100/health  # LLM
curl http://127.0.0.1:30200/health  # Vision
curl http://127.0.0.1:30300/health  # Audio
curl http://127.0.0.1:30400/health  # Image-Gen
curl http://127.0.0.1:30500/health  # Embeddings
```

### 3. View Model Lists
```bash
# LLM models
curl http://127.0.0.1:30100/v1/models | jq

# Vision models
curl http://127.0.0.1:30200/v1/models | jq

# Embeddings models
curl http://127.0.0.1:30500/v1/models | jq
```

---


## Configuration

### Backend Services

Each module requires a backend inference server. The ConfigMaps in `k8s/` should be updated to reference the appropriate backend:

**LLM Module** (`litellm-llm-configmap.yaml`):
- Default: Ollama at `http://host.minikube.internal:11434`
- Models: llama2, deepseek-coder, qwen

**Vision Module** (`litellm-vision-configmap.yaml`):
- Default: Ollama LLaVA at `http://host.minikube.internal:11434`
- Models: llava, bakllava

**Audio Module** (`litellm-audio-configmap.yaml`):
- Required: Whisper-compatible API at `http://host.minikube.internal:8000/v1`
- Options: LocalAI, faster-whisper-server, OpenAI API

**Image-Gen Module** (`litellm-image-gen-configmap.yaml`):
- Required: Image generation API at `http://host.minikube.internal:7860/v1`
- Options: Stable Diffusion WebUI, ComfyUI, OpenAI API

**Embeddings Module** (`litellm-embeddings-configmap.yaml`):
- Default: Ollama at `http://host.minikube.internal:11434`
- Models: nomic-embed-text, all-minilm

### Updating Configuration

1. Edit the ConfigMap file:
  ```bash
  nano k8s/litellm-llm-configmap.yaml
  ```

2. Apply changes:
  ```bash
  minikube kubectl -- apply -f k8s/litellm-llm-configmap.yaml
  ```

3. Restart the module:
  ```bash
  minikube kubectl -- rollout restart deploy/litellm-llm-gateway
  ```

### Scaling Modules

Modules can be scaled independently based on traffic:

```bash
# Scale LLM module for high traffic
minikube kubectl -- scale deploy/litellm-llm-gateway --replicas=4

# Scale Vision module
minikube kubectl -- scale deploy/litellm-vision-gateway --replicas=2
```

---


## Monitoring

Prometheus collects metrics from all modules. Example queries:

```bash
# Access Prometheus (if NodePort configured)
curl http://127.0.0.1:30900/metrics

# Check module-specific metrics
# litellm_requests_total{module="llm"}
# litellm_requests_total{module="vision"}
```

---


## Troubleshooting

### Module Not Responding
```bash
# Check pod status
minikube kubectl -- get pods -l module=llm

# View logs
minikube kubectl -- logs -l module=llm --tail=100

# Restart deployment
minikube kubectl -- rollout restart deploy/litellm-llm-gateway
```

### Backend Connection Errors
```bash
# Test backend from within the cluster
minikube kubectl -- run test --image=curlimages/curl:latest --rm -it -- \
  curl http://host.minikube.internal:11434/api/tags
```

### Check Service Endpoints
```bash
# Get ClusterIP addresses
minikube kubectl -- get svc

# Test internal connectivity
minikube kubectl -- run test --image=busybox:1.36 --rm -it -- \
  wget -qO- http://litellm-llm-gateway:4000/health
```

---


## Minikube Setup

The following steps install and configure Minikube:

### 1. Install Minikube
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 2. Install cri-dockerd (for driver=none)
```bash
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir -p bin
go build -o bin/cri-dockerd main.go
sudo install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
sudo cp packaging/systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.service
```

### 3. Install CNI Plugins
```bash
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.3.0.tgz
```

### 4. Start Minikube
```bash
minikube start --driver=none --container-runtime=docker \
  --cri-socket=/var/run/cri-dockerd.sock
```

### 5. Configure Firewall (Oracle Linux 9)
```bash
sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/12
sudo firewall-cmd --permanent --zone=public --add-port=30000-32767/tcp
sudo firewall-cmd --reload
```

---


## Module Reference

| Module | ConfigMap | Deployment | Service | NodePort |
|--------|-----------|------------|---------|----------|
| LLM | litellm-llm-configmap.yaml | litellm-llm-deployment.yaml | litellm-llm-service.yaml | 30100 |
| Vision | litellm-vision-configmap.yaml | litellm-vision-deployment.yaml | litellm-vision-service.yaml | 30200 |
| Audio | litellm-audio-configmap.yaml | litellm-audio-deployment.yaml | litellm-audio-service.yaml | 30300 |
| Image-Gen | litellm-image-gen-configmap.yaml | litellm-image-gen-deployment.yaml | litellm-image-gen-service.yaml | 30400 |
| Embeddings | litellm-embeddings-configmap.yaml | litellm-embeddings-deployment.yaml | litellm-embeddings-service.yaml | 30500 |

---


## Documentation

- **[Complete Architecture Guide](docs/README-MODULAR-ARCHITECTURE.md)** – Module details
- **[Security Configuration](docs/SECURITY.md)** – Security setup
- **[Deployment Status](docs/DEPLOYMENT-STATUS.md)** – Deployment status and troubleshooting
- **[Handoff Notes](docs/HANDOFF.md)** – Technical context and history
- **Kubernetes manifests**: `k8s/` directory

---


## Security Notice

This repository contains placeholder credentials for demonstration purposes only.

Before deploying to production:
1. Copy `.env.example` to `.env` and update all credentials
2. Generate secure API keys: `openssl rand -hex 32`
3. Update ConfigMaps with real keys or use Kubernetes Secrets
4. See [docs/SECURITY.md](docs/SECURITY.md) for detailed security configuration

Current placeholder keys:
- Database: `litellm` / `litellm` (username/password)
- Module API keys: `sk-{module}-module-key` (in ConfigMaps)

Never commit `.env` to git.

---



## About

This modular LiteLLM deployment provides a clear separation of AI capabilities into specialized modules. Each module is independently scalable and manageable. The architecture replaces the monolithic gateway with distinct endpoints for LLM, vision, audio, image generation, and embeddings.

- Clear organization: Separate endpoints for each capability
- Independent scaling: Each module can be scaled based on its own traffic
- Flexible backends: Each module can use a different inference provider
- Improved monitoring: Metrics and logs are tracked per module
- Security isolation: Different API keys and quotas for each capability

For questions or contributions, open a GitHub issue.


