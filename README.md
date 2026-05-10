# MLOps Lesson 3 — ML Model Containerization

PyTorch MobileNet V2 inference service packaged in two Docker images: fat and slim.

## Project Structure

```
.
├── install_dev_tools.sh   # environment setup script
├── export_model.py        # downloads and exports MobileNet V2 to TorchScript
├── inference.py           # runs top-3 image classification
├── model.pt               # TorchScript model (MobileNet V2)
├── imagenet_labels.json   # ImageNet class labels
├── Dockerfile.fat         # single-stage image (~3.17 GB)
├── Dockerfile.slim        # multi-stage optimized image (~1.04 GB)
└── report.md              # fat vs slim comparison and analysis
```

## 1. Environment Setup

```bash
chmod +x install_dev_tools.sh
./install_dev_tools.sh
```

Installs Docker, Docker Compose, Python ≥ 3.9, pip, torch, torchvision, pillow, Django.
Idempotent — safe to run multiple times. Logs to `install.log`.

## 2. Export the Model

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install torch torchvision
python export_model.py        # produces model.pt
```

## 3. Run Inference Locally

```bash
source .venv/bin/activate
python inference.py <path/to/image.jpg>
# optionally pass a custom model path:
python inference.py image.jpg model.pt
```

Example output:
```
Top-3 predictions for: image.jpg
----------------------------------------
  1. golden retriever              82.31%
  2. Labrador retriever            10.54%
  3. kuvasz                         1.12%
```

## 4. Build Docker Images

```bash
# fat image (~3.17 GB)
docker build -f Dockerfile.fat -t ml-inference:fat .

# slim image (~1.04 GB)
docker build -f Dockerfile.slim -t ml-inference:slim .
```

## 5. Run Inference in Docker

```bash
# fat
docker run --rm -v $(pwd)/image.jpg:/app/image.jpg ml-inference:fat /app/image.jpg

# slim
docker run --rm -v $(pwd)/image.jpg:/app/image.jpg ml-inference:slim /app/image.jpg
```

Replace `image.jpg` with any JPEG/PNG file on your machine.

## Image Comparison

| | fat | slim |
|---|---|---|
| Size | 3.17 GB | 1.04 GB |
| Layers | 13 | 9 |
| Build approach | single-stage | multi-stage |

See `report.md` for full analysis.
