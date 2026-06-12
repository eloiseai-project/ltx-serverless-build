#!/bin/bash
# v4 = v3 + full bf16 dev model (the official/contact model; fp8 was the shortcut).
# crane append on Linux (no macOS xattr bug). Reports status to S3.
set -uo pipefail
B=l29331hf0y; EP=https://s3api-eu-ro-1.runpod.io
LOG=/v4.log; : > "$LOG"
push(){ aws s3 cp "$LOG" s3://$B/ltx-build/v4.log --endpoint-url $EP >/dev/null 2>&1 || true; }
status(){ printf '%s' "$1" | aws s3 cp - s3://$B/ltx-build/V4_STATUS --endpoint-url $EP >/dev/null 2>&1 || true; }
log(){ echo "[$(date -u +%H:%M:%S)] $*" | tee -a "$LOG"; push; }
fail(){ log "FAIL: $1"; status "$2"; push; sleep infinity; }
( while true; do push; sleep 25; done ) &

status RUNNING
log "=== v4 build: append bf16 dev onto v3 ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >>"$LOG" 2>&1
apt-get install -y -qq curl python3-pip >>"$LOG" 2>&1 || true
command -v aws >/dev/null || pip install -q awscli >>"$LOG" 2>&1
pip install -q "huggingface_hub[hf_transfer]" hf_transfer >>"$LOG" 2>&1 || true

curl -sL "https://github.com/google/go-containerregistry/releases/download/v0.20.2/go-containerregistry_Linux_x86_64.tar.gz" | tar xz -C /usr/local/bin crane 2>>"$LOG" || fail CRANE_DL FAILED_CRANE
log "crane $(crane version 2>/dev/null)"
echo "$DOCKERHUB_TOKEN" | crane auth login index.docker.io -u leettwo --password-stdin >>"$LOG" 2>&1 || fail LOGIN FAILED_LOGIN
crane manifest leettwo/ltx:v3 >/dev/null 2>>"$LOG" && log "v3 readable" || fail NO_V3 FAILED_V3

M=/staging/runpod-volume/ComfyUI/models/checkpoints; mkdir -p "$M"
log "downloading bf16 dev (46GB) via hf_transfer..."
export HF_HUB_ENABLE_HF_TRANSFER=1 HF_TOKEN="$HF_TOKEN" HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
python3 - <<PY >>"$LOG" 2>&1 || true
from huggingface_hub import hf_hub_download
import shutil
p=hf_hub_download("Lightricks/LTX-2.3","ltx-2.3-22b-dev.safetensors",local_dir="/dl")
shutil.move(p,"$M/ltx-2.3-22b-dev.safetensors")
print("downloaded",p)
PY
[ -s "$M/ltx-2.3-22b-dev.safetensors" ] || fail DL_EMPTY FAILED_DL
log "bf16 size: $(du -h "$M"/*.safetensors | cut -f1)"

tar -cf /tmp/bf16.tar -C /staging runpod-volume
log "crane append v3 -> v4 (push ~46GB to Docker Hub)..."
crane append -b leettwo/ltx:v3 -f /tmp/bf16.tar -t leettwo/ltx:v4 >>"$LOG" 2>&1 || fail APPEND FAILED_APPEND
SZ=$(crane manifest leettwo/ltx:v4 2>/dev/null | python3 -c "import json,sys;print(len(json.load(sys.stdin)['layers']),'layers')")
log "=== DONE -> leettwo/ltx:v4 ($SZ) ==="
status DONE; push; sleep infinity
