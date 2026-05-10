import sys
import urllib.request
import json
import torch
from PIL import Image
from torchvision import transforms

LABELS_URL = "https://raw.githubusercontent.com/anishathalye/imagenet-simple-labels/master/imagenet-simple-labels.json"
LABELS_CACHE = "imagenet_labels.json"


def load_labels():
    try:
        with open(LABELS_CACHE) as f:
            return json.load(f)
    except FileNotFoundError:
        urllib.request.urlretrieve(LABELS_URL, LABELS_CACHE)
        with open(LABELS_CACHE) as f:
            return json.load(f)


def preprocess(image_path):
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406],
                             std=[0.229, 0.224, 0.225]),
    ])
    img = Image.open(image_path).convert("RGB")
    return transform(img).unsqueeze(0)


def predict(model_path, image_path, top_k=3):
    model = torch.jit.load(model_path, map_location="cpu")
    model.eval()

    labels = load_labels()
    tensor = preprocess(image_path)

    with torch.no_grad():
        output = model(tensor)

    probs = torch.softmax(output[0], dim=0)
    top_probs, top_indices = torch.topk(probs, top_k)

    print(f"\nTop-{top_k} predictions for: {image_path}")
    print("-" * 40)
    for i, (prob, idx) in enumerate(zip(top_probs, top_indices), 1):
        print(f"  {i}. {labels[idx.item()]:30s} {prob.item()*100:.2f}%")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inference.py <image_path> [model_path]")
        sys.exit(1)

    image_path = sys.argv[1]
    model_path = sys.argv[2] if len(sys.argv) > 2 else "model.pt"
    predict(model_path, image_path)
