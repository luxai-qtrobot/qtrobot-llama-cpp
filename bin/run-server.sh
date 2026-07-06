#!/bin/sh
set -a
. /opt/luxai/qtrobot_llama_cpp/etc/server.env
set +a

# Download a model file if it doesn't exist yet.
# Requires a URL to be set; exits 1 on failure so systemd retries.
download_if_missing() {
    FILE="$1"
    URL="$2"
    NAME="$(basename "${FILE}")"

    [ -f "${FILE}" ] && return 0

    if [ -z "${URL}" ]; then
        echo "qtrobot-llama-cpp: ERROR: ${NAME} not found and no URL configured in server.env"
        return 1
    fi

    echo "qtrobot-llama-cpp: Downloading ${NAME} ..."
    if curl -fLs --no-progress-meter --connect-timeout 15 --max-time 7200 --retry 2 \
            -o "${FILE}.part" "${URL}"; then
        mv "${FILE}.part" "${FILE}"
        echo "qtrobot-llama-cpp: ${NAME} ready."
    else
        rm -f "${FILE}.part"
        echo "qtrobot-llama-cpp: ERROR: failed to download ${NAME}"
        return 1
    fi
}

mkdir -p "${LLAMA_MODEL_DIR}"

# Main model (required)
download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_MODEL}" "${LLAMA_MODEL_URL:-}" || exit 1

# Draft model (optional — skipped entirely if LLAMA_DRAFT_MODEL is unset or empty)
if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL}" "${LLAMA_DRAFT_MODEL_URL:-}" || exit 1
fi

# Build optional arg groups
DRAFT_ARGS=""
if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    DRAFT_ARGS="--model-draft ${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL} --spec-type draft-mtp --spec-draft-n-max 3 --spec-draft-p-min 0.40"
fi

WEBUI_ARGS=""
if [ "${LLAMA_WEBUI:-true}" = "false" ]; then
    WEBUI_ARGS="--webui none"
fi

exec /usr/local/bin/llama-server \
    -m "${LLAMA_MODEL_DIR}/${LLAMA_MODEL}" \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    -ngl "${LLAMA_N_GPU_LAYERS}" \
    -c "${LLAMA_CTX_SIZE}" \
    -t "${LLAMA_THREADS}" \
    -tb "${LLAMA_BATCH_THREADS}" \
    --flash-attn on \
    --special \
    -r "${LLAMA_REVERSE_PROMPT}" \
    ${DRAFT_ARGS} \
    ${WEBUI_ARGS}
