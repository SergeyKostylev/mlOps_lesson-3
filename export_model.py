import torch
import torchvision.models as models

model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.DEFAULT)
model.eval()

example_input = torch.rand(1, 3, 224, 224)
scripted = torch.jit.trace(model, example_input)
scripted.save("model.pt")

print("Model saved to model.pt")
