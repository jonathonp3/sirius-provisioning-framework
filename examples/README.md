# SPF Examples

# SPF Examples

## Implementations of the Sirius Provisioning Framework

| Example | What it shows |
|---|---|
| [`template/`](template/) | The skeleton. Copy this, rename "template" to your package name, fill in the blanks. |
| [`sirius-os-pia-installer/`](sirius-os-pia-installer/) | A production implementation. All four SPF pillars plus update detection, offline handling, and a container-based build. |
| `sirius-os-virtualization` | A minimal real-world consumer. Groups, tmpfiles, modular services — no user-to-root handoff. |

---

### 1. `sirius-os-virtualization`

One-command setup of virt-manager on atomic systems (Silverblue, Kinoite, Bazzite).

**What it does:**

- Creates `libvirt-qemu` and `virtnetwork` groups via `sysusers.d`
- Creates directories with correct permissions via `tmpfiles.d`
- Enables modular libvirt services (not legacy `libvirtd`)
- Configures the default NAT network

**SPF pillars used:** sysusers.d, tmpfiles.d. No handoff, no container.

GitHub: [`sirius-os-virtualization`](https://github.com/jonathonp3/sirius-os-virtualization)

---

### 2. `sirius-os-pia-installer`

User-level extraction and root-level deployment of PIA VPN on atomic systems.

**What it does:**

- Creates `piahnsd` and `piavpn` groups via `sysusers.d`
- Enables linger for user 1000
- Builds PIA in a Distrobox container
- Atomic handoff from user to root
- Systemd path unit triggers root deployment
- Dormant uninstaller for complete cleanup

**SPF pillars used:** all four. Also adds:

- **Update detection** — compares the installed version against the latest release (no reinstall if current)
- **Check-interval cache** — a stamp file that skips the network round trip on boots within 7 days
- **Offline handling** — exits 0 without touching the stamp when the network is down and PIA is already installed, so the next boot retries
- **Capability setting** — applies `setcap` to the daemon and DNS resolver binaries after extraction
- **Permission matching** — mirrors PIA's workstation install (chown/chgrp/chmod, SUID bit on the support tool)

**Files worth reading first:**

- [`piavpn-extract.sh`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-extract.sh) — the extraction script, including the stamp cache and offline branch
- [`piavpn-extract.timer`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-extract.timer) — the `OnBootSec=1min 30sec` timing and why
- [`piavpn-provision.sh`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/piavpn-provision.sh) — the first-boot provisioner with the kickstart removed

The full lifecycle (package layering through uninstall) is diagrammed in
[`docs/Sirius-OS PIA Installer 2.0.0-6: Full Lifecycle Timeline.md`](https://github.com/jonathonp3/sirius-os-pia-installer/blob/main/docs/).

GitHub: [`sirius-os-pia-installer`](https://github.com/jonathonp3/sirius-os-pia-installer)

---

## Contributing

If you've built something using SPF, submit a PR to add it here.

## Implementations of the Sirius Provisioning Framework

1. `sirius-os-virtualization`

One-command setup of virt-manager on atomic systems (Silverblue, Kinoite, Bazzite).

What it does:

    Creates libvirt-qemu and virtnetwork groups via sysusers.d

    Creates directories with correct permissions via tmpfiles.d

    Enables modular libvirt services (not legacy libvirtd)

    Configures the default NAT network

GitHub: `sirius-os-virtualization`

2. sirius-os-pia-installer

User-level extraction and root-level deployment of PIA VPN on atomic systems.

What it does:

    Creates piahnsd and piavpn groups via sysusers.d

    Enables linger for user 1000

    Builds PIA in a Distrobox container

    Atomic handoff from user to root

    Systemd path unit triggers root deployment

    Dormant uninstaller for complete cleanup
    

GitHub: `sirius-os-pia-installer`

Contributing

If you've built something using SPF, submit a PR to add it here!

