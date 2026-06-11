# ltx-serverless-build
Dockerfile for the LTX-2.3 i2v serverless worker (`leettwo/ltx:v1`).
Models (LTX-2.3 dev bf16 + distilled LoRA + gemma + VAEs + spatial upscaler) and the
LTX/VHS/KJ ComfyUI nodes are baked in, so the serverless endpoint needs NO network volume
(region-agnostic). Built on RunPod's native GitHub build. No secrets here — S3 creds for
output upload are set as endpoint env vars, not in the image.
