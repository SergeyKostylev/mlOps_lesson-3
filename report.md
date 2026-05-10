# Docker Image Comparison Report

## Images Overview

| Parameter        | `ml-inference:fat` | `ml-inference:slim` |
|------------------|--------------------|---------------------|
| Base image       | `python:3.9`       | `python:3.9-slim`   |
| Build approach   | Single-stage       | Multi-stage         |
| Image size       | **3.17 GB**        | **1.04 GB**         |
| Layers count     | 13                 | 9                   |
| Build time       | ~45 s              | ~35 s               |
| apt tools        | curl, wget, git, vim, build-essential, libgl1 | none |
| Inference result | identical          | identical           |

Size reduction: **3.05x** (from 3.17 GB to 1.04 GB)

---

## Fat Image Problems

### 1. Unnecessary system tools
The fat image installs `curl`, `wget`, `git`, `vim`, `build-essential` — none of these are required
at inference time. They exist only for development convenience but add ~312 MB to the final image.

### 2. Full Debian base
`python:3.9` is built on full Debian and includes compilers, header files, package managers and
locale data that are irrelevant for running a PyTorch model. The base alone is ~900 MB.

### 3. pip cache and build artifacts
Without `--no-cache-dir` the fat image retains pip's download cache inside the image layer,
wasting additional disk space.

### 4. More attack surface
Every extra binary (`vim`, `git`, `build-essential`) is a potential entry point for a compromised
container. Fewer tools = smaller attack surface.

---

## Optimization Suggestions

### 1. Multi-stage build (already applied in slim)
Separate the build environment (where packages are compiled/downloaded) from the runtime
environment. Only the compiled Python packages are copied to the final stage — no compilers,
no apt cache.

### 2. Use `python:3.9-slim` or `python:3.9-alpine` as runtime base
- `slim` drops most Debian extras → saves ~500 MB vs full image
- `alpine` is even smaller (~50 MB base) but requires careful dependency management for
  C-extension packages like torch

### 3. Use Google Distroless
`gcr.io/distroless/python3` contains only the Python runtime and no shell, package manager
or OS utilities. Ideal for production inference — minimal attack surface, smallest footprint.

### 4. TorchScript + torch-lite / ONNX Runtime
- **TorchScript** (already used here) removes the need for Python model definition code
- **ONNX Runtime** (~50 MB) can replace the full PyTorch (~700 MB) for inference-only containers
- **torch-lite / ExecuTorch** targets edge devices with even smaller binaries

### 5. Pin and audit dependencies
Use `pip install --no-deps` with an explicit `requirements.txt` to avoid pulling in transitive
dependencies that are not needed at runtime (e.g. `networkx`, `sympy` are torch build-time deps
not needed for inference).
