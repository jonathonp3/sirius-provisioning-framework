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
#
# NOTE: the provisioner does NOT kickstart the extraction script here.
# The user timer owns the first run. This is deliberate.
#
# The tempting alternative is to run `systemctl --user start
# template-extract.service --no-block` at the end of this script, so
# the first install starts immediately rather than waiting for the
# timer. Do not do this.
#
# Why it breaks:
#
#   1. --no-block returns success immediately. The provisioner cannot
#      know whether the extraction actually ran or died mid-flight.
#
#   2. On systems with a first-boot session teardown (Bazzite), the
#      UID 1000 user manager may be restarted at ~52s, killing any
#      in-flight user service. The kickstarted extraction dies
#      silently, and nothing re-arms it.
#
#   3. The ConditionPathExists on the provisioning service means it
#      will not run again on the next boot, so there is no second
#      chance.
#
# Letting the timer own the first run means the trigger is observed
# by a stable user manager on every boot, and a failed run retries
# cleanly on the next one.
#
# --- What the timer actually controls ---
#
# The timer is not, strictly, a scheduling mechanism for updates.
# It answers one question: "when in the boot should the extraction
# service be invoked?" It fires once per boot, at OnBootSec after
# the session is up.
#
# The timer does NOT answer "should an update happen right now?" That
# question belongs to the extract script. The script reads a marker
# file that records the last successful check. If the marker is
# recent, the script exits without doing any work. If it's stale (or
# absent, on first install), the script proceeds.
#
# The two decisions are separate and belong in separate places:
#
#   - The timer decides WHEN in the boot. A short delay (1min 30sec
#     in the PIA example) clears the session-teardown window on
#     Bazzite. A long delay (15min in this template) means the
#     extraction fires well after login, useful for packages whose
#     build is expensive and shouldn't compete with the desktop
#     starting up.
#
#   - The script decides WHETHER to run. A marker file throttles the
#     actual extraction to the package's release cadence (weekly for
#     a quarterly-releasing upstream, monthly for an annual one). The
#     timer fires on every boot; the script skips most of them.
#
# This split means the timer is cheap to tune. Changing OnBootSec
# only changes *when* the extraction runs, not how often. Changing
# the marker interval in the script only changes *how often*, not
# when. Neither change requires touching the other file.
#
# A reader tempted to make the timer "run weekly" by setting
# OnCalendar=weekly and OnBootSec=7d will find the behavior wrong on
# first install (nothing runs until the calendar trigger, or 7 days
# after boot) and awkward to tune. The correct pattern is: fire the
# timer every boot, let the script's marker decide whether the fire
# results in work.
systemctl daemon-reload
systemctl enable --now template-deploy.path
systemctl enable template-deploy.service

systemctl --user -M "${TARGET_USER}@" daemon-reload
systemctl --user -M "${TARGET_USER}@" enable --now template-extract.timer
systemctl daemon-reload
systemctl enable --now template-deploy.path
systemctl enable template-deploy.service

systemctl --user -M "${TARGET_USER}@" daemon-reload
systemctl --user -M "${TARGET_USER}@" enable --now template-extract.timer
systemctl daemon-reload
systemctl enable --now template-deploy.path
systemctl enable template-deploy.service

systemctl --user -M "${TARGET_USER}@" daemon-reload
systemctl --user -M "${TARGET_USER}@" enable --now template-extract.timer

# --- 5. Write the provisioning marker ---------------------------------
mkdir -p /etc/sirius-os
touch "$MARKER"

echo "Sirius: template provisioning complete"
