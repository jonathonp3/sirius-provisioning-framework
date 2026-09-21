#!/usr/bin/bash
# First-boot provisioning. Runs once per deployment.
#
# Responsibilities:
#   1. Deploy blueprint units from /usr/share/sirius-os/ into /etc/
#   2. Enable linger for the primary user
#   3. Enable and start the runtime services
#   4. Write the provisioning marker
#
# Blueprints are deployed with an atomic handoff: copy to a .tmp file,
# then rename with mv -f. cp truncates the destination before writing,
# and systemd can scan the directory mid-write, seeing a partial file
# and failing to enable the unit. The rename is atomic, so systemd sees
# either the complete file or nothing.
set -euo pipefail

TARGET_USER=$(id -nu 1000 || echo "jonathon")
USER_ID=$(id -u "$TARGET_USER" || echo "1000")
MARKER="/etc/sirius-os/template-provisioned"
BLUEPRINTS="/usr/share/sirius-os/template"

echo "Sirius: provisioning template..."

# --- 1. Deploy blueprints to /etc/ (atomic handoff) -------------------
mkdir -p /etc/systemd/system
mkdir -p /etc/systemd/user

cp "$BLUEPRINTS/template-deploy.service" \
   /etc/systemd/system/.template-deploy.service.tmp
mv -f /etc/systemd/system/.template-deploy.service.tmp \
      /etc/systemd/system/template-deploy.service

cp "$BLUEPRINTS/template-deploy.path" \
   /etc/systemd/system/.template-deploy.path.tmp
mv -f /etc/systemd/system/.template-deploy.path.tmp \
      /etc/systemd/system/template-deploy.path

cp "$BLUEPRINTS/template-extract.service" \
   /etc/systemd/user/.template-extract.service.tmp
mv -f /etc/systemd/user/.template-extract.service.tmp \
      /etc/systemd/user/template-extract.service

cp "$BLUEPRINTS/template-extract.timer" \
   /etc/systemd/user/.template-extract.timer.tmp
mv -f /etc/systemd/user/.template-extract.timer.tmp \
      /etc/systemd/user/template-extract.timer

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
