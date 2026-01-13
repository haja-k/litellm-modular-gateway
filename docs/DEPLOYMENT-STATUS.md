
# Modular LiteLLM Architecture - Deployment Status

## Repository and Files Overview

### Git/GitHub
```
.gitignore          → Excludes .env and sensitive files
.env.example        → Template for users (gets committed)
.env                → Actual credentials (excluded from git)
```

### Documentation
```
README.md                        → Main entry point with security warnings
docs/SECURITY.md                 → Security configuration guide
docs/GITHUB-SETUP.md             → GitHub push instructions
docs/MODULAR-ARCHITECTURE.md     → Complete architecture guide
docs/DEPLOYMENT-STATUS.md        → Current status & troubleshooting
docs/HANDOFF.md                  → Technical history
docs/STRUCTURE.md                → Repository structure
```

### Kubernetes (k8s/)
```
22 manifest files:
  • 5 modules × 3 files (ConfigMap, Deployment, Service)
  • Shared: Postgres, Prometheus (3 files each)
  • kustomization.yaml
```

## Summary of Work Completed

### 1. Modularization of the Gateway
The LiteLLM gateway has been separated into five distinct modules, each responsible for a specific capability:

- **LLM Module** (Port 30100): Chat completions and text generation  
  - Files: `litellm-llm-configmap.yaml`, `litellm-llm-deployment.yaml`, `litellm-llm-service.yaml`
  - Models: gpt-4.1, deepseek, qwen, llama, gpt-oss
  - Replicas: 2
- **Vision Module** (Port 30200): Image-to-text  
  - Files: `litellm-vision-configmap.yaml`, `litellm-vision-deployment.yaml`, `litellm-vision-service.yaml`
  - Models: gpt-4-vision, llava, bakllava, vision-general
  - Replicas: 1
- **Audio Module** (Port 30300): Speech-to-text  
  - Files: `litellm-audio-configmap.yaml`, `litellm-audio-deployment.yaml`, `litellm-audio-service.yaml`
  - Models: whisper, whisper-large, speech-to-text
  - Replicas: 1
- **Image Generation Module** (Port 30400): Text-to-image  
  - Files: `litellm-image-gen-configmap.yaml`, `litellm-image-gen-deployment.yaml`, `litellm-image-gen-service.yaml`
  - Models: dall-e-3, stable-diffusion, image-gen
  - Replicas: 1
- **Embeddings Module** (Port 30500): Text embeddings  
  - Files: `litellm-embeddings-configmap.yaml`, `litellm-embeddings-deployment.yaml`, `litellm-embeddings-service.yaml`
  - Models: text-embedding-ada-002, nomic-embed-text, all-minilm
  - Replicas: 1

### 2. Configuration and Keys
Each module is provided with a dedicated ConfigMap and API key (e.g., `sk-{module}-module-key`). All modules share a single Postgres database, and Prometheus is configured for monitoring.

### 3. Kubernetes Manifests
Five deployment files were created, each with health checks and resource limits. Each module is exposed via a dedicated NodePort service (30100-30500). The `kustomization.yaml` file was updated to include all modules. Postgres uses port 5432, and health check delays were increased to accommodate database migrations.

### 4. Documentation
Documentation was updated and expanded, including `README-MODULAR-ARCHITECTURE.md`, the main `README.md`, `README-AI-HANDOFF.md`, and a `deploy-modular.sh` script.

### 5. Deployment
All Kubernetes manifests were applied. All five modules are present as deployments and services. Postgres and Prometheus are operational. The previous monolithic gateway has been removed.

---

## Outstanding Issues

### Cluster Networking (Pre-existing)

Despite the modularization, pods are not starting due to unresolved networking issues in the Minikube none-driver setup. These issues were present prior to the modular changes.

#### 1. DNS Resolution Failure
CoreDNS is unable to resolve service names or reach upstream DNS servers.

Observed symptoms:
- `nslookup postgres` times out
- CoreDNS logs: `read udp...->8.8.8.8:53: i/o timeout`
- Pods cannot resolve service names to connect to Postgres

Attempts to resolve:
- Patched CoreDNS to use public DNS (8.8.8.8, 1.1.1.1)
- Restarted CoreDNS
- Issue persists, likely due to firewall or iptables blocking DNS

Root cause: Likely firewall rules or iptables configuration on Oracle Linux 9 with driver=none

#### 2. Pod-to-Pod Networking
Pods are unable to reach ClusterIP services, even by direct IP.

Observed symptoms:
- `psql -h 10.100.234.197 -p 5432` times out from a test pod
- LiteLLM pods cannot connect to Postgres at `postgres:5432`
- Connection timeouts on ClusterIP addresses

Impact: All LiteLLM modules are in CrashLoopBackOff because they cannot connect to Postgres for database migrations.

---


## Potential Solutions for Networking

### Option 1: Check iptables/Firewall

The handoff notes indicate that some firewall rules were added, but further configuration may be required:

```bash
# Check current iptables rules
sudo iptables -S | grep -E "10\.(96|244)"
sudo iptables -t nat -S | grep -E "10\.(96|244)"

# Ensure IP forwarding is enabled
sudo sysctl net.ipv4.ip_forward
sudo sysctl net.bridge.bridge-nf-call-iptables

# Check if bridge netfilter is loaded
lsmod | grep br_netfilter

# Check firewalld zones
sudo firewall-cmd --list-all --zone=trusted
sudo firewall-cmd --list-all --zone=public

# May need to add OUTPUT rules for DNS
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p udp --dport 53 -j ACCEPT
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p tcp --dport 53 -j ACCEPT
sudo firewall-cmd --reload
```

### Option 2: Use Minikube with Docker Driver

Switching to the Docker driver instead of `driver=none` may resolve networking issues:

```bash
# Stop the current cluster
minikube stop

# Start with Docker driver
minikube start --driver=docker
```

Advantages:
- Improved networking reliability
- Fewer host system dependencies
Disadvantages:
- Requires running as a non-root user
- Potential differences in performance

### Option 3: Use Host Network (Not Recommended for Production)

Setting `hostNetwork: true` in deployments can bypass pod networking:

```yaml
spec:
  template:
    spec:
      hostNetwork: true  # Bypass pod networking
      dnsPolicy: ClusterFirstWithHostNet
```

---

## Current Architecture and Artifacts

### Architecture
The current setup consists of the following structure:

```
        Shared Infrastructure
        ├── Postgres :5432
        └── Prometheus :9090
            │
  ┌───────────────┬───────────────┬───────────────┐
  │               │               │
LLM Module   Vision Module   Audio Module
 :30100         :30200         :30300
  │               │               │
Image-Gen    Embeddings
 :30400         :30500
```

### Notable Benefits
- Each capability is deployed independently
- Modules can be scaled up or down as needed
- Each module can use different providers
- API keys are separated per module
- The structure is clear and maintainable

### Files Created
- 15 Kubernetes manifest files (5 modules × 3 files each)
- 3 documentation files
- 1 deployment script

---

## Testing (Post-Networking Fix)

Once networking issues are resolved, the following tests are recommended:

```bash
# Check all pods
minikube kubectl -- get pods

# Test each module’s health
curl http://127.0.0.1:30100/health  # LLM
curl http://127.0.0.1:30200/health  # Vision
curl http://127.0.0.1:30300/health  # Audio
curl http://127.0.0.1:30400/health  # Image-Gen
curl http://127.0.0.1:30500/health  # Embeddings

# List available models
curl http://127.0.0.1:30100/v1/models | jq
curl http://127.0.0.1:30200/v1/models | jq
curl http://127.0.0.1:30500/v1/models | jq

# Test LLM chat completion
curl http://127.0.0.1:30100/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-llm-module-key" \
  -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Documentation

- **[MODULAR-ARCHITECTURE.md](MODULAR-ARCHITECTURE.md)** – Architecture and usage
- **[README.md](../README.md)** – Quick start and deployment
- **[HANDOFF.md](HANDOFF.md)** – Technical context and history
- **[deploy-modular.sh](../deploy-modular.sh)** – Deployment script

---




## Conclusion

The modular LiteLLM setup is complete and deployed. The remaining task is to resolve the pre-existing Minikube networking issues (DNS and pod-to-pod communication). These issues are unrelated to the modularization work described above.

Once networking is functional, the system will provide:
- Five independent LiteLLM gateways, each dedicated to a specific AI capability
- Clear separation of concerns, replacing the previous all-in-one gateway
- Easier scaling, monitoring, and management for each module
- An architecture suitable for production and multi-tenant environments
