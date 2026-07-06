#!/usr/bin/env bash
# Build qtrobot-llama-cpp .deb from source tree.
#
# Usage (run from repo root):
#   bash packaging/build-deb.sh [output_dir]
#
# Default output_dir: ./packaging/dist

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"

PKG_NAME="qtrobot-llama-cpp"
VERSION="1.0.2"
ARCH="${ARCH:-$(dpkg --print-architecture)}"
DEB_NAME="${PKG_NAME}_${VERSION}_${ARCH}.deb"

PREFIX="/opt/luxai/qtrobot_llama_cpp"
STAGING="${SCRIPT_DIR}/staging"

echo "==> Building ${DEB_NAME}"

# ---------------------------------------------------------------------------
# Clean and populate staging tree
# ---------------------------------------------------------------------------
rm -rf "${STAGING}"
mkdir -p \
    "${STAGING}${PREFIX}/bin" \
    "${STAGING}${PREFIX}/etc" \
    "${STAGING}${PREFIX}/models" \
    "${STAGING}/lib/systemd/system" \
    "${STAGING}/DEBIAN"

install -m 0755 "${REPO_DIR}/bin/run-server.sh"             "${STAGING}${PREFIX}/bin/run-server.sh"
install -m 0644 "${REPO_DIR}/config/server.env"             "${STAGING}${PREFIX}/etc/server.env"
install -m 0644 "${SCRIPT_DIR}/qtrobot-llama-cpp.service"   "${STAGING}/lib/systemd/system/qtrobot-llama-cpp.service"

# ---------------------------------------------------------------------------
# DEBIAN control files
# ---------------------------------------------------------------------------
INSTALLED_SIZE=$(du -sk "${STAGING}" | awk '{print $1}')

cat > "${STAGING}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: LuxAI <support@luxai.com>
Installed-Size: ${INSTALLED_SIZE}
Description: QTrobot LLM service — llama.cpp server wrapper
 Systemd service that runs llama-server (OpenAI-compatible HTTP API)
 with sensible defaults for the Jetson AGX Orin.
 .
 Default model: Gemma-4-12B-Instruct Q8_0 + MTP draft (downloaded on first install).
 Config: ${PREFIX}/etc/server.env
 .
 Requires llama-server in /usr/local/bin (install llama-cpp first).
EOF

install -m 0755 "${SCRIPT_DIR}/postinst" "${STAGING}/DEBIAN/postinst"
install -m 0755 "${SCRIPT_DIR}/prerm"    "${STAGING}/DEBIAN/prerm"

# ---------------------------------------------------------------------------
# Build the .deb
# ---------------------------------------------------------------------------
mkdir -p "${OUTPUT_DIR}"
DEB_PATH="${OUTPUT_DIR}/${DEB_NAME}"

echo "==> Building .deb..."
dpkg-deb --build --root-owner-group "${STAGING}" "${DEB_PATH}"

rm -rf "${STAGING}"

echo ""
echo "Done: ${DEB_PATH}"
echo ""
echo "Install with:"
echo "  sudo dpkg -i ${DEB_PATH}"
