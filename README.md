# qtrobot-llama-cpp

Systemd service package that runs `llama-server` (OpenAI-compatible HTTP API)
on QTrobot's Jetson AGX Orin. Models are downloaded automatically on first start.

Default model: **Gemma 4 12B IT Q8\_0** with multimodal projection and MTP draft

## Prerequisites

Install the `llama-cpp` binary package first (provides `/usr/local/bin/llama-server`):

```bash
sudo dpkg -i llama-cpp_<version>_arm64.deb
sudo apt-get install -f
```

The MTP draft model requires a llama.cpp build from after 2026-06-07.

## Build the .deb

```bash
cd qtrobot-llama-cpp
bash packaging/build-deb.sh
# produces: packaging/dist/qtrobot-llama-cpp_1.0.4_arm64.deb
```

## Install

```bash
sudo dpkg -i packaging/dist/qtrobot-llama-cpp_1.0.4_arm64.deb
```

The package installs instantly. On first start, the service downloads the
configured models automatically before launching `llama-server`. Watch progress:

```bash
sudo journalctl -u qtrobot-llama-cpp -f
```

If a download fails (network issue etc.), the service exits and systemd retries
after 5 seconds. To stop the retry loop: `sudo systemctl stop qtrobot-llama-cpp`.

> To pre-place models manually (e.g. no internet on the robot), copy them into
> `/opt/luxai/qtrobot_llama_cpp/models/` before starting the service — the
> download step is skipped if the file already exists.

## Configuration

Edit `/opt/luxai/qtrobot_llama_cpp/etc/server.env` and restart the service to apply:

```bash
sudo systemctl restart qtrobot-llama-cpp
```

```env
# Model directory
LLAMA_MODEL_DIR=/opt/luxai/qtrobot_llama_cpp/models

# Main model — filename only, relative to LLAMA_MODEL_DIR
LLAMA_MODEL=gemma-4-12b-it-Q8_0.gguf
LLAMA_MODEL_URL=https://huggingface.co/unsloth/gemma-4-12b-it-GGUF/resolve/main/gemma-4-12b-it-Q8_0.gguf

# Multimodal projection file - leave empty to disable image/multimedia support
LLAMA_MMPROJ=mmproj-BF16.gguf
LLAMA_MMPROJ_URL=https://huggingface.co/unsloth/gemma-4-12b-it-GGUF/resolve/main/mmproj-BF16.gguf

# Draft model for speculative decoding — leave empty to disable
LLAMA_DRAFT_MODEL=mtp-gemma-4-12b-it.gguf
LLAMA_DRAFT_MODEL_URL=https://huggingface.co/unsloth/gemma-4-12b-it-GGUF/resolve/main/mtp-gemma-4-12b-it.gguf

LLAMA_HOST=0.0.0.0
LLAMA_PORT=8080
LLAMA_N_GPU_LAYERS=999
LLAMA_CTX_SIZE=65536

# Set to false to disable the built-in web UI
LLAMA_WEBUI=true
```

**To switch models:** update `LLAMA_MODEL`, `LLAMA_MODEL_URL`, and restart.
The new model will be downloaded automatically on next start if not already present.

**To disable speculative decoding:** clear `LLAMA_DRAFT_MODEL=` and restart.
The `--model-draft` flag is omitted entirely when the draft model is unset.

The default launch uses two parallel slots, Jinja chat templates, a 65,536-token
context, temperature `1.0`, top-p `0.95`, top-k `64`, and up to four MTP draft
tokens. Reasoning output is disabled with `--reasoning off`. The main model is
the Q8\_0 file configured above; the Q4 filename shown in some upstream examples
is a different quantization.

## Usage

```bash
sudo systemctl status qtrobot-llama-cpp
sudo journalctl -u qtrobot-llama-cpp -f
```

The server exposes an OpenAI-compatible API on port 8080:

```bash
# Health check
curl http://localhost:8080/health

# Chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Replace `localhost` with the robot's IP to reach it from another machine.
The built-in web UI is available at `http://<robot-ip>:8080` when `LLAMA_WEBUI=true`.

## Uninstall

```bash
sudo apt-get remove qtrobot-llama-cpp
```

Model files under `/opt/luxai/qtrobot_llama_cpp/models/` are **not** removed
automatically — delete them manually if no longer needed.
