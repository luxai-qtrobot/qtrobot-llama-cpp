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

# Multimodal projection file (optional)
if [ -n "${LLAMA_MMPROJ:-}" ]; then
    download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_MMPROJ}" "${LLAMA_MMPROJ_URL:-}" || exit 1
fi

# Draft model (optional)
if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL}" "${LLAMA_DRAFT_MODEL_URL:-}" || exit 1
fi

# Build optional arg groups
MMPROJ_ARGS=""
if [ -n "${LLAMA_MMPROJ:-}" ]; then
    MMPROJ_ARGS="--mmproj ${LLAMA_MODEL_DIR}/${LLAMA_MMPROJ}"
fi

DRAFT_ARGS=""
if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    DRAFT_ARGS="--model-draft ${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL} --spec-type draft-mtp --spec-draft-n-max 4"
fi

WEBUI_ARGS=""
if [ "${LLAMA_WEBUI:-true}" = "false" ]; then
    WEBUI_ARGS="--webui none"
fi

exec /usr/local/bin/llama-server \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    -m "${LLAMA_MODEL_DIR}/${LLAMA_MODEL}" \
    ${MMPROJ_ARGS} \
    ${DRAFT_ARGS} \
    -ngl "${LLAMA_N_GPU_LAYERS}" \
    -np 2 \
    --jinja \
    -c "${LLAMA_CTX_SIZE}" \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64 \
    --reasoning off \
    ${WEBUI_ARGS}
