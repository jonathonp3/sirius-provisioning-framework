#!/usr/bin/bash
# User-level extraction. Runs as the primary user (UID 1000).
# Build artifacts in a container, then write them to the staging cache.
set -euo pipefail

# --- CONFIGURATION ----------------------------------------------------
USER_ID=$(id -u)
STAGING_DIR="/run/user/$USER_ID/cache/template"
STAGING_TAR="$STAGING_DIR/template-stage.tar.gz"
CONTAINER_NAME="template-factory"

mkdir -p "$STAGING_DIR"

# --- CONCURRENCY GUARD ------------------------------------------------
# The timer fires once per boot, but a user can also run the service
# manually (systemctl --user start). Without a guard, a manual start
# during a timer-initiated run would double-fire the container build.
# The flock guard makes concurrent runs safe: the second one exits 0.
#
# Use the staging directory for the lock file so it's cleared on
# logout and lives in RAM.
LOCK="$STAGING_DIR/.extract.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "Sirius: extraction already running; exiting"
    exit 0
fi

# --- DECIDE WHETHER TO RUN --------------------------------------------
# The timer fires on every boot. This script decides whether to do
# work. Two common reasons to skip:
#
#   1. A recent successful run — the last check was recent enough
#      that re-running now would just do the same thing. Use a marker
#      file whose mtime records the last success.
#
#   2. The installed version is already current — the extraction
#      would produce the same artifact that's already deployed. Use a
#      version file and compare it against the latest available.
#
# The two checks are independent. A version check answers "is the
# artifact I have the right one?" A time check answers "have I
# looked recently enough?" For a first-install package you want
# both: the version check is correctness, the time check is
# politeness.
#
# --- Choosing the interval ---
#
# The stamp interval is a politeness setting, not a freshness setting.
# A shorter interval means the script looks for updates more often; it
# does not mean updates arrive sooner. What it controls is how many
# network round trips the package makes for a given release cadence.
#
# Calibrate against the upstream release cadence:
#
#   - If the upstream releases weekly, use a 1-3 day stamp. Checking
#     more often than the release cadence is wasted traffic.
#
#   - If the upstream releases every few months (like PIA, which
#     ships every 3-5 months), a 7-day stamp is a good default. It
#     means one network check per week, which is fresh enough to
#     catch a new release within days and light enough to look like
#     a normal user, not a scraper.
#
#   - If the upstream releases annually, a 30-day stamp is fine.
#
# The pia-installer uses 7 days for a package that releases every
# 3-5 months. That's weekly checks for a quarterly release — the
# right order of magnitude. A tighter interval would waste traffic;
# a looser one risks running a stale version for weeks.
#
# IMPORTANT: only write the marker on success. If the network is
# down, the container build fails, or the staging handoff fails,
# leave the marker untouched. That way the next boot retries. A
# failed run that advances the marker is the bug that makes a
# package appear to install silently but do nothing.
#
# Example: 7-day time cache. Uncomment and adapt.
#
# STAMP_DIR="$HOME/.local/state/sirius-os/template"
# STAMP_FILE="$STAMP_DIR/.last-check"
# CHECK_INTERVAL=$((7 * 24 * 3600))  # 7 days, tuned to a quarterly release cadence
#
# if [[ -f "$STAMP_FILE" ]]; then
#     LAST=$(stat -c %Y "$STAMP_FILE" 2>/dev/null || echo 0)
#     NOW=$(date +%s)
#     AGE=$(( NOW - LAST ))
#     if (( AGE < CHECK_INTERVAL )); then
#         echo "Sirius: last check was $(( AGE / 86400 ))d ago; skipping"
#         exit 0
#     fi
# fi

# --- CLEANUP ON EXIT --------------------------------------------------
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

# --- 3. Record success ------------------------------------------------
# Only write the marker after the staging tar has landed. If any step
# above failed, the marker stays absent (or stale), and the next boot
# retries.
#
# The stamp file records the moment the check *succeeded*, not the
# moment it started. If you write the stamp at the top of the script
# (before the build), a failed build would still advance the timer,
# and the next boot would skip a check that should have retried.
#
# mkdir -p "$STAMP_DIR"
# touch "$STAMP_FILE"

echo "Sirius: staging archive ready for deployment"
