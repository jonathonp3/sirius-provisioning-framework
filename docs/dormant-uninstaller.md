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


## Why the Uninstaller Must Be Generated at Runtime

This is the load-bearing principle of the Dormant Uninstaller pattern. Getting it wrong means the uninstaller silently disappears the moment the package is removed — exactly when it is needed.

### The Rule

> A file listed in the RPM's `%files` is owned by the package. On `rpm-ostree remove`, it is removed from the new deployment unless the admin has modified it at runtime. A file created at runtime by a script is owned by nobody. rpm-ostree has no record of it, so it persists.

This is why every SPF package generates its dormant uninstaller at first boot rather than shipping it in the RPM.

### The Two Categories

| Category | Who owns it | Where it lands | Survives package removal? |
| :--- | :--- | :--- | :--- |
| **Vendor files** — listed in `%files` | The RPM | `/usr/` (read-only) | ❌ Removed, unless modified |
| **Runtime files** — created by a script | Nobody | `/etc/` or `/var/` | ✅ Persist |

The **trigger** of the dormant uninstaller is a vendor file. The **uninstaller itself** is a runtime file.

### Why It Has to Be This Way

The three-way merge on `/etc/` compares:

1. **Old deployment's `/etc/`** — includes package-owned config files
2. **New deployment's `/etc/`** — the same, minus anything the removed package owned
3. **Running system's `/etc/`** — whatever the admin and runtime scripts have left there

Files created at runtime exist only in (3). They have no counterpart in (1) or (2), so the merge leaves them alone. Files owned by the removed package exist in (1), are absent from (2), and if unmodified in (3), the merge removes them.

### The Practical Consequence

If the dormant uninstaller were shipped in `%files`, it would work perfectly in testing and then silently fail the moment a user removes the package:

- The uninstaller service would be gone from the new deployment
- `ConditionPathExists` would never be evaluated
- No cleanup would run
- Persistent state (kill switch profiles, firewall rules, network configs) would be left behind

### The Rule for Every Provisioning Script

Every SPF provisioning script must generate the dormant uninstaller at first boot, not ship it. Add this comment to the top of each provisioning script as a reminder:

```bash
# The dormant uninstaller must be generated here, at first boot, not shipped
# in %files. Files owned by the RPM are removed during `rpm-ostree remove`;
# only files created at runtime persist across the deployment swap.
```

## Benefits


| Benefit | Explanation |
|---------|-------------|
| **Reliable cleanup** | Even if the package is gone, the uninstaller persists (bluebuild, bootc) |
| **Survives reboots** | Runs in the new deployment, not the old one |
| **Fail-safe** | Triggered by the package's absence |
| **Self-cleaning** | Removes itself after completion |

