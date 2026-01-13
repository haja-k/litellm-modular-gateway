# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- Initial changelog created.

## [2026-01-13]
- Modular LiteLLM architecture finalized: LLM, Vision, Audio, Image-Gen, and Embeddings modules separated.
- All Kubernetes manifests updated for modular deployment.
- Security audit completed; sensitive data moved to .env and .env.example.
- Documentation consolidated in docs/ folder; repo structure clarified.
- Quick reference merged into main documentation; QUICK-REFERENCE.md removed.
- GitHub setup and security best practices documented.
- Outstanding: Minikube networking issues (inherited, not caused by modularization).
