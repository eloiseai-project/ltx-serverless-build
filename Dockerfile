# LTX-2.3 i2v serverless — models + nodes baked in, NO network volume (region-agnostic).
# Base = the same comfy-gen worker we already run for WAN (ComfyUI at /ComfyUI, handler from
# Hearmeman24/remote-comfy-gen-handler, entrypoint /start_script.sh).
# Build for linux/amd64 (RunPod serverless arch). Push to leettwo/ltx:v1.
FROM hearmeman/comfyui-serverless:v17

# Base already ships huggingface_hub + hf-xet (fast Xet downloads). Do NOT set
# HF_HUB_ENABLE_HF_TRANSFER without the hf_transfer pkg — it hard-errors `hf download`.

# --- LTX-2.3 models, PINNED, baked in (ONE layer to keep builder disk sane) ---
# The existing comfy-gen handler resolves models via baked extra_model_paths.yaml
# (base_path: /runpod-volume/ComfyUI/models) AND a hardcoded preflight scan of that path.
# With NO volume mounted, /runpod-volume is just image filesystem, so we bake models THERE to
# match the existing convention exactly (zero handler changes).
ARG M=/runpod-volume/ComfyUI/models
RUN mkdir -p $M/unet $M/loras $M/vae $M/text_encoders $M/latent_upscale_models && \
    dl() { hf download "$1" "$2" --local-dir /tmp/dl >/dev/null && mv "/tmp/dl/$2" "$3"/ && rm -rf /tmp/dl; }; \
    dl Kijai/LTX2.3_comfy diffusion_models/ltx-2.3-22b-dev_transformer_only_bf16.safetensors $M/unet && \
    dl Kijai/LTX2.3_comfy loras/ltx-2.3-22b-distilled-1.1_lora-dynamic_fro09_avg_rank_111_bf16.safetensors $M/loras && \
    dl Comfy-Org/ltx-2 split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors $M/text_encoders && \
    dl Kijai/LTX2.3_comfy vae/LTX23_video_vae_bf16.safetensors $M/vae && \
    dl Lightricks/LTX-2.3 ltx-2.3-spatial-upscaler-x2-1.1.safetensors $M/latent_upscale_models && \
    rm -rf /tmp/dl

# Expose the same tree at /ComfyUI/models so a direct ComfyUI run (no handler) resolves too.
RUN rm -rf /ComfyUI/models && ln -s /runpod-volume/ComfyUI/models /ComfyUI/models

# --- custom nodes, baked (do NOT rely on cold-start runtime install) ---
# Idempotent: the base image already ships some of these (e.g. VideoHelperSuite), so clone
# only what's missing, then install each node's requirements.
RUN cd /ComfyUI/custom_nodes && \
    for repo in Lightricks/ComfyUI-LTXVideo Kosinkadink/ComfyUI-VideoHelperSuite kijai/ComfyUI-KJNodes; do \
      d=$(basename "$repo"); \
      [ -d "$d" ] || git clone --depth 1 "https://github.com/$repo.git"; \
      [ -f "$d/requirements.txt" ] && pip install --no-cache-dir -r "$d/requirements.txt" || true; \
    done

# Keep the base image's extra_model_paths.yaml (points at /runpod-volume/ComfyUI/models, baked above).
# Entrypoint + handler inherited from the base image — no changes.
