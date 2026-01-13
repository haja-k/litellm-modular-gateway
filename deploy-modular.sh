#!/bin/bash
# Deploy Modular LiteLLM Architecture

set -e

# Use minikube kubectl
KUBECTL="minikube kubectl --"

echo "=========================================="
echo "Deploying Modular LiteLLM Architecture"
echo "=========================================="
echo ""

echo "📦 Step 1: Removing old monolithic deployment (if exists)..."
$KUBECTL delete deploy litellm-gateway --ignore-not-found=true
$KUBECTL delete svc litellm-gateway --ignore-not-found=true
$KUBECTL delete configmap litellm-config --ignore-not-found=true
echo "✅ Old deployment cleaned up"
echo ""

echo "📦 Step 2: Deploying modular architecture..."
$KUBECTL apply -k k8s/
echo "✅ Modular architecture deployed"
echo ""

echo "⏳ Step 3: Waiting for pods to be ready..."
$KUBECTL wait --for=condition=ready pod -l module=llm --timeout=120s || true
$KUBECTL wait --for=condition=ready pod -l module=vision --timeout=120s || true
$KUBECTL wait --for=condition=ready pod -l module=audio --timeout=120s || true
$KUBECTL wait --for=condition=ready pod -l module=image-gen --timeout=120s || true
$KUBECTL wait --for=condition=ready pod -l module=embeddings --timeout=120s || true
echo ""

echo "📊 Deployment Status:"
echo "===================="
$KUBECTL get pods
echo ""
$KUBECTL get services
echo ""

echo "=========================================="
echo "✅ Modular LiteLLM Architecture Deployed!"
echo "=========================================="
echo ""
echo "Module Endpoints:"
echo "  • LLM Module:        http://127.0.0.1:30100"
echo "  • Vision Module:     http://127.0.0.1:30200"
echo "  • Audio Module:      http://127.0.0.1:30300"
echo "  • Image-Gen Module:  http://127.0.0.1:30400"
echo "  • Embeddings Module: http://127.0.0.1:30500"
echo ""
echo "Test commands:"
echo "  curl http://127.0.0.1:30100/health"
echo "  curl http://127.0.0.1:30100/v1/models"
echo ""
echo "📖 See README-MODULAR-ARCHITECTURE.md for complete documentation"
