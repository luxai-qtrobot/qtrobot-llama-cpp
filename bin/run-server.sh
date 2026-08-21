#!/bin/sh
set -eu

INSTALL_ROOT="${QTROBOT_LLAMA_CPP_ROOT:-/opt/luxai/qtrobot_llama_cpp}"
CONFIG_FILE="${LLAMA_CONFIG_FILE:-${INSTALL_ROOT}/etc/server.env}"
PRESET_DIR="${LLAMA_PRESET_DIR:-${INSTALL_ROOT}/etc/presets}"
SERVER_BIN="${LLAMA_SERVER_BIN:-/usr/local/bin/llama-server}"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "qtrobot-llama-cpp: ERROR: configuration not found: ${CONFIG_FILE}"
    exit 1
fi

set -a
. "${CONFIG_FILE}"
set +a

# Keep installations upgraded from the former single-model configuration
# working when dpkg preserves their existing server.env.
if [ -z "${LLAMA_MODEL_PRESET:-}" ]; then
    case "${LLAMA_MODEL:-}" in
        Qwen3.5-9B-Q8_0.gguf)
            LLAMA_MODEL_PRESET=qwen3.5-9b
            ;;
        Qwen3.8-27B-Q8_0.gguf)
            LLAMA_MODEL_PRESET=qwen3.8-27b
            ;;
        gemma-4-12b-it-Q8_0.gguf|gemma-4-12B-it-Q8_0.gguf)
            LLAMA_MODEL_PRESET=gemma4-12b
            ;;
    esac

    if [ -n "${LLAMA_MODEL_PRESET:-}" ]; then
        echo "qtrobot-llama-cpp: Legacy configuration mapped to preset '${LLAMA_MODEL_PRESET}'"
    fi
fi

case "${LLAMA_MODEL_PRESET:-}" in
    qwen3.5-9b|qwen3.8-27b|gemma4-12b)
        ;;
    *)
        echo "qtrobot-llama-cpp: ERROR: unknown model preset '${LLAMA_MODEL_PRESET:-}'"
        echo "qtrobot-llama-cpp: Available presets: qwen3.5-9b, qwen3.8-27b, gemma4-12b"
        exit 1
        ;;
esac

PRESET_FILE="${PRESET_DIR}/${LLAMA_MODEL_PRESET}.env"
if [ ! -f "${PRESET_FILE}" ]; then
    echo "qtrobot-llama-cpp: ERROR: model preset not found: ${PRESET_FILE}"
    exit 1
fi

set -a
. "${PRESET_FILE}"
set +a

LLAMA_MODEL_DIR="${LLAMA_MODEL_DIR:-${INSTALL_ROOT}/models}"
LLAMA_HOST="${LLAMA_HOST:-0.0.0.0}"
LLAMA_PORT="${LLAMA_PORT:-8080}"
LLAMA_N_GPU_LAYERS="${LLAMA_N_GPU_LAYERS:-999}"
LLAMA_N_PARALLEL="${LLAMA_N_PARALLEL:-2}"
LLAMA_CTX_SIZE="${LLAMA_CTX_SIZE:-65536}"

if [ -z "${LLAMA_MODEL:-}" ] || [ -z "${LLAMA_MODEL_URL:-}" ]; then
    echo "qtrobot-llama-cpp: ERROR: preset '${LLAMA_MODEL_PRESET}' has no main model"
    exit 1
fi

# Download a model file if it does not exist yet.
download_if_missing() {
    FILE="$1"
    URL="$2"
    NAME="$(basename "${FILE}")"

    [ -f "${FILE}" ] && return 0

    if [ -z "${URL}" ]; then
        echo "qtrobot-llama-cpp: ERROR: ${NAME} not found and no URL is configured"
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

echo "qtrobot-llama-cpp: Using model preset '${LLAMA_MODEL_PRESET}'"
download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_MODEL}" "${LLAMA_MODEL_URL}"

if [ -n "${LLAMA_MMPROJ:-}" ]; then
    download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_MMPROJ}" "${LLAMA_MMPROJ_URL:-}"
fi

if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    download_if_missing "${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL}" "${LLAMA_DRAFT_MODEL_URL:-}"
fi

set -- "${SERVER_BIN}" \
    --host "${LLAMA_HOST}" \
    --port "${LLAMA_PORT}" \
    -m "${LLAMA_MODEL_DIR}/${LLAMA_MODEL}"

if [ -n "${LLAMA_MMPROJ:-}" ]; then
    set -- "$@" --mmproj "${LLAMA_MODEL_DIR}/${LLAMA_MMPROJ}"
fi

if [ -n "${LLAMA_DRAFT_MODEL:-}" ]; then
    set -- "$@" --model-draft "${LLAMA_MODEL_DIR}/${LLAMA_DRAFT_MODEL}"
    [ -z "${LLAMA_SPEC_TYPE:-}" ] || set -- "$@" --spec-type "${LLAMA_SPEC_TYPE}"
    [ -z "${LLAMA_SPEC_DRAFT_N_MAX:-}" ] || \
        set -- "$@" --spec-draft-n-max "${LLAMA_SPEC_DRAFT_N_MAX}"
fi

set -- "$@" \
    -ngl "${LLAMA_N_GPU_LAYERS}" \
    -np "${LLAMA_N_PARALLEL}" \
    --jinja \
    -c "${LLAMA_CTX_SIZE}"

[ -z "${LLAMA_TEMP:-}" ] || set -- "$@" --temp "${LLAMA_TEMP}"
[ -z "${LLAMA_TOP_P:-}" ] || set -- "$@" --top-p "${LLAMA_TOP_P}"
[ -z "${LLAMA_TOP_K:-}" ] || set -- "$@" --top-k "${LLAMA_TOP_K}"
[ -z "${LLAMA_MIN_P:-}" ] || set -- "$@" --min-p "${LLAMA_MIN_P}"
[ -z "${LLAMA_PRESENCE_PENALTY:-}" ] || \
    set -- "$@" --presence-penalty "${LLAMA_PRESENCE_PENALTY}"
[ -z "${LLAMA_REPEAT_PENALTY:-}" ] || \
    set -- "$@" --repeat-penalty "${LLAMA_REPEAT_PENALTY}"
[ -z "${LLAMA_CTX_CHECKPOINTS:-}" ] || \
    set -- "$@" --ctx-checkpoints "${LLAMA_CTX_CHECKPOINTS}"
[ -z "${LLAMA_CHECKPOINT_MIN_STEP:-}" ] || \
    set -- "$@" --checkpoint-min-step "${LLAMA_CHECKPOINT_MIN_STEP}"

set -- "$@" --reasoning off

if [ "${LLAMA_WEBUI:-true}" = "false" ]; then
    set -- "$@" --webui none
fi

exec "$@"
