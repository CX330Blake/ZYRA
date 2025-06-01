#!/bin/bash

set -euo pipefail

INSTALL_PATH="/usr/local/bin/zyra"
REPO="CX330Blake/ZYRA"
ARCHIVE_NAME="zyra-linux-x86_64"

# Ensure curl is installed
if ! command -v curl &>/dev/null; then
    echo "[-] curl is required but not installed."
    exit 1
fi

# If zyra already exists, remove it
if [ -f "$INSTALL_PATH" ]; then
    echo "[!] zyra already exists at $INSTALL_PATH, removing..."
    sudo rm -f "$INSTALL_PATH"
fi

echo "[!] Downloading zyra from latest GitHub release..."

# Fetch download URL
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest |
    grep "browser_download_url" |
    grep "${ARCHIVE_NAME}" |
    cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "[-] Failed to find download URL for ${ARCHIVE_NAME}"
    exit 1
fi

# Download to temp file
TMP_FILE=$(mktemp /tmp/zyra.XXXXXX)
curl -L "$DOWNLOAD_URL" -o "$TMP_FILE"

# Move and set permission
sudo mv "$TMP_FILE" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

# Validate install
if [ -x "$INSTALL_PATH" ]; then
    echo "[+] zyra installed to $INSTALL_PATH"
    echo "$("$INSTALL_PATH" --version 2>/dev/null || echo unknown)"
else
    echo "[-] zyra install failed."
    exit 1
fi
