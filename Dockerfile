# LTX-2.3 i2v serverless worker — SMALL image: nodes baked, models come from the mounted
# network volume l29331hf0y (runpod-slim/ComfyUI/models, already staged). No model download
# in the build, so it finishes well within RunPod's 30-min GitHub-build limit.
FROM hearmeman/comfyui-serverless:v17

# Bake only the custom nodes (idempotent — base already ships VideoHelperSuite).
RUN cd /ComfyUI/custom_nodes && \
    for repo in Lightricks/ComfyUI-LTXVideo Kosinkadink/ComfyUI-VideoHelperSuite kijai/ComfyUI-KJNodes; do \
      d=$(basename "$repo"); \
      [ -d "$d" ] || git clone --depth 1 "https://github.com/$repo.git"; \
      [ -f "$d/requirements.txt" ] && pip install --no-cache-dir -r "$d/requirements.txt" || true; \
    done
# Models + extra_model_paths.yaml come from the volume mount at runtime — nothing else to bake.
