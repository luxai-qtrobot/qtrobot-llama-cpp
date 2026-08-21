# qtrobot-llama-cpp

Systemd service package for running the OpenAI-compatible `llama-server` on
QTrobot's Jetson AGX Orin. The selected model and its matching vision projector
and draft model are downloaded automatically on first use.

The default preset is **Qwen3.5 9B Q8_0**, selected for responsive multimodal
conversation, reliable instruction following, and tool calling.

## Prerequisites

Install the QTrobot `llama-cpp` binary package first. It provides
`/usr/local/bin/llama-server`:

```bash
sudo apt install ./llama-cpp_<version>_arm64.deb
```

The optional Qwen3.8 and Gemma presets use MTP speculative decoding and require
a llama.cpp build from after 2026-06-07.

## Build the Debian package

```bash
cd qtrobot-llama-cpp
bash packaging/build-deb.sh
```

This creates:

```text
packaging/dist/qtrobot-llama-cpp_1.0.5_arm64.deb
```

## Install

```bash
sudo apt install ./packaging/dist/qtrobot-llama-cpp_1.0.5_arm64.deb
```

The service starts automatically. On its first start, it downloads only the
files required by the selected preset. Follow its progress with:

```bash
sudo journalctl -u qtrobot-llama-cpp -f
```

If a download is interrupted, the partial file is removed and systemd retries.
To stop the retry loop:

```bash
sudo systemctl stop qtrobot-llama-cpp
```

## Model presets

| Preset | Main model | Vision projector | Draft model |
|---|---|---|---|
| `qwen3.5-9b` (default) | `Qwen3.5-9B-Q8_0.gguf` | `mmproj-qwen3.5-BF16.gguf` | None |
| `qwen3.8-27b` | `Qwen3.8-27B-Q8_0.gguf` | `mmproj-qwen3.8-BF16.gguf` | `mtp-Qwen3.8-27B-Q4_0.gguf` |
| `gemma4-12b` | `gemma-4-12b-it-Q8_0.gguf` | `mmproj-gemma4-BF16.gguf` | `mtp-gemma-4-12b-it.gguf` |

Each preset contains the correct download URLs and runtime parameters for that
model. Projectors have model-specific local filenames because their upstream
files are all named `mmproj-BF16.gguf` but are not interchangeable.

### Switch models

Edit the service configuration:

```bash
sudo nano /opt/luxai/qtrobot_llama_cpp/etc/server.env
```

Change only `LLAMA_MODEL_PRESET`, for example:

```env
LLAMA_MODEL_PRESET=qwen3.8-27b
```

Then restart the service:

```bash
sudo systemctl restart qtrobot-llama-cpp
sudo journalctl -u qtrobot-llama-cpp -f
```

Missing files for the newly selected preset are downloaded automatically.
Previously downloaded models remain available, so switching back does not
download them again.

## Server configuration

The persistent machine configuration is stored at:

```text
/opt/luxai/qtrobot_llama_cpp/etc/server.env
```

Its defaults are:

```env
LLAMA_MODEL_PRESET=qwen3.5-9b
LLAMA_MODEL_DIR=/opt/luxai/qtrobot_llama_cpp/models

LLAMA_HOST=0.0.0.0
LLAMA_PORT=8080
LLAMA_N_GPU_LAYERS=999
LLAMA_N_PARALLEL=2
LLAMA_CTX_SIZE=65536
LLAMA_WEBUI=true
```

Model-specific definitions are installed under
`/opt/luxai/qtrobot_llama_cpp/etc/presets/`. They include the model URLs,
sampling settings, vision projector, optional draft model, and any model-specific
context settings. Normally, users only need to change the preset selector.

The Qwen presets use the recommended non-thinking sampling settings:
temperature `0.7`, top-p `0.8`, top-k `20`, min-p `0.0`, presence penalty
`1.5`, and repeat penalty `1.0`. Qwen3.5 additionally uses 32 recurrent context
checkpoints with a minimum step of 512 tokens. Gemma retains its established
temperature `1.0`, top-p `0.95`, and top-k `64` settings.

All presets use two parallel slots, Jinja chat templates, a 65,536-token total
context, full GPU offload, and `--reasoning off`.

## Pre-place models for offline installation

To avoid downloading on the robot, copy the selected preset's files into:

```text
/opt/luxai/qtrobot_llama_cpp/models/
```

Stop the service while copying the files, then start it again:

```bash
sudo systemctl stop qtrobot-llama-cpp
# Copy the model files into /opt/luxai/qtrobot_llama_cpp/models/
sudo systemctl start qtrobot-llama-cpp
```

Use the exact local filenames from the model table. The service skips each file
that already exists. Do not reuse a projector from another model, even when its
original download name is also `mmproj-BF16.gguf`.

When upgrading an existing Gemma installation, its generic
`mmproj-BF16.gguf` may be renamed while the service is stopped, but only when
that file came from the Unsloth Gemma repository used by this package:

```bash
sudo mv /opt/luxai/qtrobot_llama_cpp/models/mmproj-BF16.gguf \
  /opt/luxai/qtrobot_llama_cpp/models/mmproj-gemma4-BF16.gguf
```

Do not rename a projector downloaded for another Gemma release or repository.

## Usage

```bash
sudo systemctl status qtrobot-llama-cpp
sudo systemctl restart qtrobot-llama-cpp
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
    "model": "local-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Replace `localhost` with the robot's IP to connect from another machine. The
built-in web UI is available at `http://<robot-ip>:8080` when
`LLAMA_WEBUI=true`.

## Uninstall

```bash
sudo apt remove qtrobot-llama-cpp
```

Downloaded files under `/opt/luxai/qtrobot_llama_cpp/models/` are intentionally
kept so they can be reused after reinstalling. Remove them manually only when
you no longer need them.
