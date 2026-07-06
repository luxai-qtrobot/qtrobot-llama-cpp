# qtrobot-llama-cpp

Systemd service package that runs `llama-server` (OpenAI-compatible HTTP API)
on QTrobot's Jetson AGX Orin. Ships a sensible default configuration and
downloads the default model automatically on first install.

Default model: **Gemma-4-12B-Instruct Q8\_0** + MTP draft model (~13 GB + ~1 GB)

## Prerequisites

Install the `llama-cpp` binary package first (provides `/usr/local/bin/llama-server`):

```bash
sudo dpkg -i llama-cpp_<version>_arm64.deb
sudo apt-get install -f
```

## Build the .deb

```bash
cd qtrobot-llama-cpp
bash packaging/build-deb.sh
# produces: packaging/dist/qtrobot-llama-cpp_1.0.0_arm64.deb
```

## Install

```bash
sudo dpkg -i packaging/dist/qtrobot-llama-cpp_1.0.0_arm64.deb
```

`postinst` will:
1. Download `gemma-4-12B-it-Q4_K_M.gguf` to `/opt/luxai/qtrobot_llama_cpp/models/` (if not already present)
2. Enable and start the `qtrobot-llama-cpp` systemd service

> If your Jetson has no internet access at install time, download both model files
> manually into `/opt/luxai/qtrobot_llama_cpp/models/` before starting the service:
> - `gemma-4-12B-it-Q8_0.gguf`
> - `mtp-gemma-4-12B-it-Q8_0.gguf`

## Configuration

Edit `/opt/luxai/qtrobot_llama_cpp/etc/server.env` to tune any parameter:

```env
LLAMA_MODEL=/opt/luxai/qtrobot_llama_cpp/models/gemma-4-12B-it-Q8_0.gguf
LLAMA_DRAFT_MODEL=/opt/luxai/qtrobot_llama_cpp/models/mtp-gemma-4-12B-it-Q8_0.gguf
LLAMA_HOST=0.0.0.0
LLAMA_PORT=8080
LLAMA_N_GPU_LAYERS=999
LLAMA_CTX_SIZE=4096
LLAMA_THREADS=8
LLAMA_BATCH_THREADS=8
LLAMA_REVERSE_PROMPT=<turn|>
LLAMA_WEBUI=true   # set to false to disable the built-in web UI
```

Apply changes:

```bash
sudo systemctl restart qtrobot-llama-cpp
```

To use a different model, update `LLAMA_MODEL` and restart.

## Usage

Check service status and logs:

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

From another machine on the same network, replace `localhost` with the robot's IP.

## Uninstall

```bash
sudo apt-get remove qtrobot-llama-cpp
```

The model files under `/opt/luxai/qtrobot_llama_cpp/models/` are **not** removed
automatically — delete them manually if no longer needed.
