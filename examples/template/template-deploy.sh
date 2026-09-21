#!/usr/bin/bash
# Root-level deployment. Runs as root, triggered by template-deploy.path
# when the staging archive appears.
set -euo pipefail

STAGING_TAR="/run/user/1000/cache/template/template-stage.tar.gz"
DEST_DIR="/var/opt/template"

if [[ ! -f "$STAGING_TAR" ]]; then
    echo "Sirius: no staging archive; nothing to deploy"
    exit 0
fi

echo "Sirius: deploying template..."

# --- 1. Prepare the destination ---------------------------------------
mkdir -p "$DEST_DIR"

# --- 2. Extract the archive -------------------------------------------
tar -xpzf "$STAGING_TAR" -C / --no-same-owner

# --- 3. Integration: symlinks, permissions, service activation --------

# Example: link binaries into /usr/local/bin
# ln -sf "$DEST_DIR/bin/example" /usr/local/bin/example

# Example: set ownership and permissions
# chown -R root:root "$DEST_DIR"

# Example: activate the runtime service
# systemctl daemon-reload
# systemctl restart example.service --no-block || true

# --- 4. Clean up the trigger file -------------------------------------
rm -f "$STAGING_TAR"
rm -f "${STAGING_TAR}.tmp"

echo "Sirius: template deployment complete"
