#!/usr/bin/bash
# User-level extraction. Runs as the primary user (UID 1000).
# Build artifacts in a container, then write them to the staging cache.
set -euo pipefail

USER_ID=$(id -u)
STAGING_DIR="/run/user/$USER_ID/cache/template"
STAGING_TAR="$STAGING_DIR/template-stage.tar.gz"
CONTAINER_NAME="template-factory"

mkdir -p "$STAGING_DIR"

cleanup() {
    if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        distrobox rm -f "$CONTAINER_NAME" --yes >/dev/null 2>&1 || :
    fi
}
trap cleanup EXIT

echo "Sirius: extracting template..."

# --- 1. Build in an isolated container --------------------------------
distrobox create --name "$CONTAINER_NAME" --image fedora:latest --yes >/dev/null
distrobox enter -n "$CONTAINER_NAME" -- bash -c "
    set -euo pipefail
    # install build dependencies, download source, build artifacts
    tar -czf /tmp/template-stage.tar.gz -C / path/to/artifacts
"

# --- 2. Atomic handoff into the staging cache -------------------------
podman cp "$CONTAINER_NAME":/tmp/template-stage.tar.gz "${STAGING_TAR}.tmp"
sync "${STAGING_TAR}.tmp"
mv -f "${STAGING_TAR}.tmp" "$STAGING_TAR"

echo "Sirius: staging archive ready for deployment"
