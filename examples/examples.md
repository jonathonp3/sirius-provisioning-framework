# SPF Example Implementations

Three packages use the Sirius Provisioning Framework in production.
Each demonstrates a different subset of the framework's pillars, from
the smallest usable case to a full pipeline with user-to-root handoff
and update detection.

## Overview

| Package | Atomic target | Handoff | Container | Update check | Uninstaller |
|---|---|---|---|---|---|
| `sirius-os-virtualization` | Yes | No | No | No | Yes |
| `sirius-os-pia-installer` | Yes | Yes | Yes | Yes | Yes |
| `sirius-os-protonvpn` | Yes | No | No | No | Yes |

Read the sections below for what each one demonstrates and which
files to look at first.

---

## sirius-os-virtualization

**Repository:** https://github.com/jonathonp3/sirius-os-virtualization

**What it solves.** On Fedora Atomic systems, installing the
virtualization packages via `rpm-ostree install` does not create the
full runtime configuration needed for virt-manager. The
`libvirt-qemu` and `virtnetwork` groups are missing,
`virtnetworkd.service` fails with a permission error, and the default
NAT bridge (`virbr0`) never gets created.

**What SPF does.**

- `sysusers.d` creates the missing groups on the live system
- `tmpfiles.d` creates the required directories with correct
  ownership — `/var/lib/libvirt/dnsmasq` and `/var/lib/libvirt/network`
  as `root:virtnetwork 0775`, `/var/log/libvirt/qemu` as
  `root:libvirt-qemu 0750`
- First-boot provisioning enables the modular libvirt services
- The provisioning script selects an available subnet
  (`192.168.100-150.0/24`, avoiding conflicts with existing routes)
  and defines the default NAT network
- A dormant uninstaller removes the firewalld services, the libvirt
  network config, and the provisioning marker on package removal

**Pillars used:** sysusers.d, tmpfiles.d, dormant uninstaller. No
user-to-root handoff, no container.

**Read first:** the provisioning script
(`sirius-os-virtualization-libvirt-provisioning.sh`) — it's a
compact example of what first-boot provisioning looks like when it
has no user-level component.

**Result:** `virt-manager` works after a single `rpm-ostree install`
and reboot, with a working NAT bridge.

---

## sirius-os-pia-installer

**Repository:** https://github.com/jonathonp3/sirius-os-pia-installer

**What it solves.** PIA VPN is distributed as a proprietary `.run`
installer for conventional Linux systems. On Atomic, the RPM's
`%post` scriptlets cannot fetch or install it, because they run in a
build chroot with no network and no write access to `/var/`.

**What SPF does.**

- User-level extraction runs as the primary user, builds PIA in a
  Distrobox container, and stages the result in `/run/user/1000/cache/`
- An atomic handoff (`.tmp` → `sync` → `mv -f`) delivers the archive
  to a path unit's watch directory
- `piavpn-deploy.path` triggers the root-level deployment, which
  installs the binaries under `/var/opt/piavpn`, patches the systemd
  unit and desktop file, and applies capabilities
- A user-level timer fires on every boot; a marker file throttles
  the actual network check to a 7-day interval
- An offline branch exits 0 without writing the marker when the
  network is unavailable and PIA is already installed, so the next
  boot retries
- A dormant uninstaller removes the user-level state directory, the
  vendor service file, and the enablement symlinks on removal

**Pillars used:** all four, plus:

- **Update detection** — compares installed version to latest
  available; skips the container rebuild if current
- **Check-interval cache** — a stamp file that skips the network
  round trip on boots within 7 days
- **Offline handling** — exits 0 without touching the stamp when the
  network is down and PIA is installed
- **Capability setting** — applies `setcap` to the daemon and DNS
  resolver binaries after extraction
- **Permission matching** — mirrors PIA's workstation install
  (chown/chgrp/chmod, SUID bit on the support tool)

**Read first:**

- [`piavpn-extract.sh`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-extract.sh) — the extraction script, including the stamp cache, the flock guard, and the offline branch
- [`piavpn-extract.timer`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-extract.timer) — the `OnBootSec=1min 30sec` timing and why
- [`piavpn-provision.sh`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-provision.sh) — the first-boot provisioner with the kickstart removed

**Full lifecycle:** diagrammed in
[`docs/Full Lifecycle Timeline.md`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/docs/).

**Result:** PIA installs and updates on Atomic systems without user
intervention. Clean removal flushes the firewall, stops the daemons,
and deletes the persistent state directory.

---

## sirius-os-protonvpn

**Repository:** https://github.com/jonathonp3/sirius-os-protonvpn

**What it demonstrates.** This is the framework's reference
implementation for the dormant uninstaller pattern, isolated from the
other pillars. No `sysusers.d`, no container build, no user-to-root
handoff. The bug it reproduces is real and upstream, which makes it a
better teaching example than a synthetic one would be.

**What it solves.** Proton VPN's Advanced kill switch writes a
persistent NetworkManager profile to
`/etc/NetworkManager/system-connections/pvpn-killswitch-perm.nmconnection`.
On Fedora Atomic, `rpm-ostree remove` does not run `%preun`
scriptlets, so that profile survives package removal. On the next
boot, NetworkManager recreates a dummy interface with a default route
metric lower than any real connection, and the machine has no
internet — with no VPN installed and no visible cause.

**What SPF does.**

- Generates a dormant uninstaller at first boot, written into `/etc/`
  where `rpm-ostree` does not track it
- The dormant uninstaller triggers when the package's provisioning
  script disappears, meaning the RPM has been removed
- On the next boot, it deletes any `pvpn*` NetworkManager connections
  and removes orphaned dummy interfaces, restoring network access

**Pillars used:** dormant uninstaller only. The other three are
absent by design, to keep the example focused.

**Read first:** the dormant uninstaller provisioning script
(`sirius-os-protonvpn-uninstall-provision.sh`), which is short and
shows exactly what a dormant uninstaller does for a package whose
only problem is leftover runtime state.

**Result:** After removal, the machine has network access on the
next boot without user intervention.

---

## Choosing which example to follow

If your package needs...

| Need | Start with |
|---|---|
| Just groups and directories | `sirius-os-virtualization` |
| To build something from source at first boot | `sirius-os-pia-installer` |
| To clean up runtime state left behind by an upstream app | `sirius-os-protonvpn` |
| The full pattern with all pillars | `sirius-os-pia-installer`, plus `template/` as a starting point |
| A clean skeleton to fill in | `template/` |

The `template/` directory is the copy-paste starting point. The three
real implementations above are what the template becomes once you've
filled it in for a specific package.
