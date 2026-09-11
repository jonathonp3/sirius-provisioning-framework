# Dormant Uninstaller Pattern

## What It Is

The Dormant Uninstaller Pattern is a fail-safe mechanism that ensures complete system cleanup when an RPM is removed, even though the removal happens in a different deployment.

Why It's Needed

When you rpm-ostree remove a package, the new deployment no longer contains that package. If the uninstall script were part of the package, it would be gone, leaving no way to clean up the system's state.

How It Works

1. Provisioning creates a "dormant" uninstaller service in /etc/
2. The service uses ConditionPathExists=!/usr/libexec/package.sh
3. When the RPM is removed, the condition passes
4. The service runs on the next boot, removing system changes.
5. The service removes itself after completion


## Key Condition
ini

[Unit]
Description=Package Uninstall
ConditionPathExists=!/usr/libexec/package.sh

This condition is the key: the service only runs when the package is missing.

## Complete Flow

Phase 1: RPM Installed
    → Provisioning creates dormant uninstaller

Phase 2: RPM Removed (rpm-ostree remove)
    → Package files are gone
    → Dormant uninstaller persists in /etc/

Phase 3: Next Boot
    → ConditionPathExists passes (package is gone)
    → Uninstaller runs
    → Everything is cleaned up
    → Uninstaller removes itself

Phase 4: System is Clean
    → No artifacts remain
    → Reinstall is reliable

## Example: PIA VPN Uninstaller
ini

[Unit]
Description=Sirius-OS PIA VPN Uninstall
ConditionPathExists=!/usr/libexec/piavpn-deploy.sh

[Service]
Type=oneshot
User=root
ExecStart=/bin/bash /etc/piavpn-uninstall/pia-uninstaller.sh

## Benefits

| Benefit | Explanation |
|---------|-------------|
| **Reliable cleanup** | Even if the package is gone, the uninstaller persists (bluebuild, bootc) |
| **Survives reboots** | Runs in the new deployment, not the old one |
| **Fail-safe** | Triggered by the package's absence |
| **Self-cleaning** | Removes itself after completion |

