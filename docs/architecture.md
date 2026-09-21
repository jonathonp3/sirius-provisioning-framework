# SPF Architecture

## Overview

The Sirius Provisioning Framework (SPF) is built on four core principles that work together to create a complete, self-contained system on top of rpm-ostree.

## The Four Pillars

1. **Blueprint Provisioning** — Service templates stored in `/usr/share/` and deployed to `/etc/` at runtime
2. **User-to-Root Handoff** — Secure, event-driven handoff via Systemd Path Units
3. **Dormant Uninstaller Pattern** — Automatic, complete cleanup on RPM removal
4. **Atomic Handoff** — Reliable, zero-corruption file transfers (`.tmp` → `sync` → `mv -f`)

## Why This Architecture Works

In a standard RPM system, `%post` scripts run on the live system. In `rpm-ostree`, they run in a temporary build environment. SPF solves this by moving post-installation logic to first-boot systemd provisioning.

## Key Components

| Component | Purpose |
|-----------|---------|
| `sysusers.d` | Creates groups on the live system at first boot |
| `tmpfiles.d` | Creates directories with correct ownership |
| Systemd services | Enables and starts services on the live system |
| Dormant uninstallers | Cleanup on RPM removal, not tracked by rpm-ostree |
