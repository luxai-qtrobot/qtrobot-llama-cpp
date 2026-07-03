#!/bin/sh
set -a
. /opt/luxai/qtrobot_llama_cpp/etc/server.env
set +a

exec /usr/local/bin/llama-server \
    -m "${LLAMA_MODEL}" \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    -ngl "${LLAMA_N_GPU_LAYERS}" \
    -c "${LLAMA_CTX_SIZE}" \
    -t "${LLAMA_THREADS}" \
    -tb "${LLAMA_BATCH_THREADS}" \
    --slots \
    -np "${LLAMA_PARALLEL}" \
    --flash-attn \
    --no-context-shift \
    --special \
    -r "${LLAMA_REVERSE_PROMPT}"
