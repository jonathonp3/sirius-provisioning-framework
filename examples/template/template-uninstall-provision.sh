#!/usr/bin/bash
# Generates the dormant uninstaller.
#
# IMPORTANT: The uninstaller service and task file must be created here, at
# first boot, not shipped in %files. Files owned by the RPM are removed from
# the new deployment during `rpm-ostree remove`; only files created at runtime
# persist across the deployment swap. See docs/dormant-uninstaller.md.
set -euo pipefail

SERVICE_FILE="/etc/systemd/system/template-uninstall.service"
TASK_FILE="/etc/template-uninstall/template-uninstaller.sh"

if [ -e "$SERVICE_FILE" ] || [ -e "$TASK_FILE" ]; then
    echo "Sirius: dormant uninstaller already provisioned; skipping"
    exit 0
fi

echo "Sirius: provisioning dormant cleanup infrastructure..."

mkdir -p /etc/template-uninstall

# --- 1. The cleanup task ----------------------------------------------
cat <<'TASK_EOF' > "$TASK_FILE"
#!/bin/bash
set -euo pipefail

echo "Sirius: cleaning up template state"

# Stop and disable runtime units
systemctl disable --now example.service 2>/dev/null || true
systemctl disable --now template-deploy.path 2>/dev/null || true

# Remove persistent state under /var/
rm -rf /var/opt/template

# Remove files placed under /etc/ by the provisioning script
rm -f /etc/sirius-os/template-provisioned

# Remove the deployed blueprints
rm -f /etc/systemd/system/template-deploy.service
rm -f /etc/systemd/system/template-deploy.path
rm -f /etc/systemd/user/template-extract.service
rm -f /etc/systemd/user/template-extract.timer

# Remove user-level units deployed into user sessions
TARGET_USER=$(id -nu 1000 || echo "jonathon")
systemctl --user -M "${TARGET_USER}@" disable --now template-extract.timer 2>/dev/null || true

# Remove the uninstaller itself
rm -f /etc/systemd/system/multi-user.target.wants/template-uninstall.service
rm -f /etc/systemd/system/template-uninstall.service
rm -f /etc/template-uninstall/template-uninstaller.sh
rmdir /etc/template-uninstall 2>/dev/null || true

systemctl daemon-reload
echo "Sirius: template cleanup complete"
TASK_EOF

chmod +x "$TASK_FILE"

# --- 2. The trigger service -------------------------------------------
cat <<'SERVICE_EOF' > "$SERVICE_FILE"
[Unit]
Description=Sirius OS: clean up template after package removal
# Trigger: the vendor provisioning script is absent, meaning the RPM was removed
ConditionPathExists=!/usr/libexec/sirius/template-provision.sh
DefaultDependencies=no
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/bash /etc/template-uninstall/template-uninstaller.sh

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# --- 3. Enable the dormant uninstaller --------------------------------
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf "$SERVICE_FILE" /etc/systemd/system/multi-user.target.wants/template-uninstall.service

echo "Sirius: dormant uninstaller installed"
