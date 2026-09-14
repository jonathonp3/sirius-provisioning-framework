#!/usr/bin/bash
# First-boot provisioning. Runs once per deployment.
# Responsibilities:
#   1. Deploy blueprint units from /usr/share/ into /etc/
#   2. Enable linger for the primary user
#   3. Enable and start the runtime services
#   4. Write the provisioning marker
set -euo pipefail

TARGET_USER=$(id -nu 1000 || echo "jonathon")
USER_ID=$(id -u "$TARGET_USER" || echo "1000")
MARKER="/etc/sirius-os/template-provisioned"
BLUEPRINTS="/usr/share/sirius/template"

echo "Sirius: provisioning template..."

# --- 1. Deploy blueprints to /etc/ ------------------------------------
mkdir -p /etc/systemd/system
mkdir -p /etc/systemd/user

install -m0644 "$BLUEPRINTS/template-deploy.service" /etc/systemd/system/
install -m0644 "$BLUEPRINTS/template-deploy.path"    /etc/systemd/system/
install -m0644 "$BLUEPRINTS/template-extract.service" /etc/systemd/user/
install -m0644 "$BLUEPRINTS/template-extract.timer"   /etc/systemd/user/

# --- 2. Enable linger for the primary user ----------------------------
mkdir -p /var/lib/systemd/linger
touch "/var/lib/systemd/linger/$TARGET_USER"

# --- 3. Wait for the user manager to be ready -------------------------
for i in {1..15}; do
    [ -S "/run/user/$USER_ID/systemd/private" ] && break
    [ "$i" -eq 15 ] && { echo "Sirius: timed out waiting for user manager"; exit 1; }
    sleep 1
done

# --- 4. Arm the system ------------------------------------------------
systemctl daemon-reload
systemctl enable --now template-deploy.path
systemctl enable template-deploy.service

systemctl --user -M "${TARGET_USER}@" daemon-reload
systemctl --user -M "${TARGET_USER}@" enable --now template-extract.timer

# --- 5. Write the provisioning marker ---------------------------------
mkdir -p /etc/sirius-os
touch "$MARKER"

echo "Sirius: template provisioning complete"
