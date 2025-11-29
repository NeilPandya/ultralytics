# qat_yolo11n_ultralytics.py
import os

import torch
import yaml
from torch import nn
from torch.quantization import convert_fx, get_default_qat_qconfig, prepare_fx
from ultralytics.yolo.data.dataloader import create_dataloader
from ultralytics.yolo.engine.loss import ComputeLoss  # ulralytics loss util

from ultralytics import YOLO

device = "cuda" if torch.cuda.is_available() else "cpu"

# 1) Load YOLO model (raw nn.Module)
y = YOLO("yolov11n.pt")
model = y.model
model.to(device)
model.train()

# 2) Print model to inspect fusion candidates, then create a fuse map.
print(model)  # paste output back here if you want me to craft exact fuse list


# Example fuse helper — adapt module names per printed model structure
def fuse_yolo_model(mod):
    # Common pattern: layer blocks named 'm' or custom Blocks. This is a conservative pass.
    for name, m in mod.named_children():
        # if child has conv+bn attributes (common), try fusing them
        try:
            if hasattr(m, "conv") and hasattr(m, "bn"):
                torch.quantization.fuse_modules(m, ["conv", "bn"], inplace=True)
        except Exception:
            pass
        # recursively fuse
        fuse_yolo_model(m)
    return mod


model = fuse_yolo_model(model)

# 3) Prepare FX QAT
example_input = torch.randn(1, 3, 640, 640).to(device)
qconfig = get_default_qat_qconfig("fbgemm")
qconfig_dict = {"": qconfig}
# prepare_fx expects the module in eval to trace well for some models; we will set eval then prepare, then train.
model.eval()
model_qat = prepare_fx(model, qconfig_dict, example_inputs=(example_input,))
model_qat.train()
model_qat.to(device)

# 4) Create Ultralytics dataloader (train)
with open("data.yaml") as f:
    data_cfg = yaml.safe_load(f)
train_path = data_cfg["train"]

# create_dataloader signature may vary by ultralytics version; tune args if needed
train_loader = create_dataloader(
    train_path, imgsz=640, batch_size=8, stride=int(y.model.stride.max()), pad=0.0, rect=False, workers=8
)[0]

# 5) Ultralytics loss utility (ComputeLoss expects raw model)
# NOTE: ComputeLoss expects the original model to produce predictions in the expected format.
compute_loss = ComputeLoss(y.model)  # use original model for loss structure

# 6) Optimizer and training loop
optimizer = torch.optim.SGD(model_qat.parameters(), lr=1e-4, momentum=0.9, weight_decay=5e-4)

# training loop: run forward through model_qat, but compute loss with ComputeLoss using model outputs shape
for epoch in range(10):  # tune epochs
    model_qat.train()
    for batch_i, (imgs, targets, paths, _) in enumerate(train_loader):
        imgs = imgs.to(device).float() / 255.0
        # forward using QAT model
        preds = model_qat(imgs)  # may return list/tuple — matches regular model forward
        # ComputeLoss expects predictions from the original model signature; ensure compatible
        # If model_qat returns a tuple (preds, anchors) or similar, adapt accordingly.
        loss, loss_items = compute_loss(preds, targets.to(device))
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

    # optional: freeze observers near end of QAT fine-tune
    if epoch == 7:
        torch.quantization.disable_observer(model_qat)
    if epoch == 8:
        torch.quantization.disable_fake_quant(model_qat)

    print(f"Epoch {epoch} loss {loss.item():.4f}")

# 7) Convert to quantized module
model_qat.eval()
example_input = torch.randn(1, 3, 640, 640).to(device)
model_int8 = convert_fx(model_qat, example_inputs=(example_input,))
torch.save(model_int8.state_dict(), "yolo11n_qat_int8.pth")
# Optionally export via ultralytics export API (may require CPU-mode model)
# y.model = model_int8
# y.export(format="onnx", task="detect")
