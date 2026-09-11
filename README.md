# Sirius Provisioning Framework (SPF)

A declarative, systemd-based framework for automating complex software lifecycles on immutable Linux systems (Silverblue, Kinoite, Bazzite). Bypasses rpm-ostree limitations with first-boot provisioning, dormant uninstallers, and atomic handoff.

---

## Official Description

The Sirius Provisioning Framework is a declarative, systemd-based architecture for automating complex software lifecycles on immutable Linux systems. It is a self-contained framework that sits on top of rpm-ostree, solving the problem of managing stateful software on read-only filesystems.

---

## The Problem It Solves

In a standard RPM system, the package installs and the `%post` scripts run immediately on the live system. In `rpm-ostree`, the package is "layered" into a new deployment image, and those scripts run in a temporary environment (chroot) during the build process—not on the actual running machine.

This creates a critical limitation: **`%post` scripts are unable to run in the new deployment, leaving an incomplete installation, as is the case with virtualization.**

---

## The Current Workaround: A Security Compromise

To work around the broken bridge, users often resort to `macvtap` as a workaround—a direct bridge to the physical network that bypasses the broken default network. However, this exposes VMs directly to the LAN, compromising the isolation that NAT provides. A VM by default should be isolated, not tied to a specific physical interface like a router.

| Aspect | Default NAT (Proper) | `macvtap` (Workaround) |
|--------|----------------------|------------------------|
| **Network isolation** | ✅ VM is behind NAT | ❌ VM is directly on LAN |
| **LAN access** | ❌ VM cannot reach other devices | ✅ VM can reach all devices |
| **Security** | ✅ Protected by NAT | ❌ Exposed to LAN |
| **Portability** | ✅ Works on any network | ❌ Tied to specific interface |
| **DHCP** | ✅ Built into libvirt | ❌ Relies on router DHCP |
| **Default state** | ✅ Should work out of the box | ❌ Hack to bypass broken system |

---

## How SPF Fixes This

SPF solves this by moving post-installation logic from `%post` scripts to **first-boot systemd provisioning**:
- `sysusers.d` creates any missing groups on the live system at first boot
- `tmpfiles.d` creates directories with correct ownership
- Provisioning services enable and start the modular libvirt daemons
- The dormant uninstaller ensures complete cleanup on removal
---

## The SPF Design Philosophy

> A core principle of the Sirius Provisioning Framework is that **provisioning services are enabled in `/etc/`—not the vendor layer—giving the admin complete control to disable them if required**.

| Approach | Location | User Control |
|----------|----------|--------------|
| **Vendor-layer only** | `/usr/lib/systemd/system/` | ❌ Cannot be disabled (read-only) |
| **SPF approach** | `/etc/systemd/system/` | ✅ Full control (writable) |

Vendor-layer services are used **only to enable provisioning scripts**—they are the minimal trigger that deploys the full provisioning system to `/etc/` at first boot. After that, the user is in control.

---

## Core Principles

1. **Blueprint Provisioning** — Service templates stored in `/usr/share/` and deployed to `/etc/` at runtime
2. **User-to-Root Handoff** — Secure, event-driven handoff via Systemd Path Units
3. **Dormant Uninstaller Pattern** — Automatic, complete cleanup on RPM removal
4. **Atomic Handoff** — Reliable, zero-corruption file transfers (`.tmp` → `sync` → `mv -f`)

---

## Implementations

### 1. `sirius-os-virtualization`

**The problem:** On Silverblue, Kinoite, and Bazzite installations, installing the virtualization packages does not provide the complete system configuration required for virtualization to function correctly. The `libvirt-qemu` and `virtnetwork` groups are missing, causing `virtnetworkd.service` to fail with permission errors which prevents the default `virbr0` bridge from being created.

**What SPF does:**

1. Uses `sysusers.d` to create the `libvirt-qemu` and `virtnetwork` groups.
2. Uses `tmpfiles.d` to create the required directories with the correct ownership.
3. Enables the modular `libvirt` services through the provisioning script.
4. Configures the default NAT network.

| Issue | Without SFP | With SFP |
|---|---|---|
| **`libvirt-qemu` group** | ❌ Missing | ✅ Created |
| **`virtnetwork` group** | ❌ Missing | ✅ Created |
| **`virtnetworkd.service`** | ❌ Fails: permission denied | ✅ Running |
| **`virbr0` bridge** | ❌ Missing | ✅ Exists |

**Testing scope:** The RPM is intended for Silverblue, Kinoite, and Bazzite installations where the virtualization stack needs to be installed and configured after deployment. 


**Installation:**

```bash
sudo curl -Lo /etc/yum.repos.d/_copr_jonathonp3-sirius-os.repo \
  https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/repo/fedora-44/jonathonp3-sirius-os-fedora-44.repo
sudo rpm-ostree install sirius-os-virtualization
sudo systemctl reboot
```

###  Verification:

Check groups exist (SPF created these on first boot):
```bash
getent group libvirt-qemu
getent group virtnetwork
```

Check directories have correct permissions (tmpfiles.d created these):
```bash
ls -la /var/lib/libvirt/
```

Check modular services are running (SPF enabled these):
```bash
sudo systemctl status virtnetworkd.service --no-pager
sudo systemctl status virtqemud.service --no-pager
sudo systemctl status virtstoraged.service --no-pager
sudo systemctl status virtlogd.service --no-pager
```

Check bridge exists (this is the default NAT network):
```bash
ip -4 addr show virbr0
```

Check default network is active and autostart is enabled:
```bash
sudo virsh net-list --all
```

Open virt-manager:
```bash
virt-manager
```

### 2. `sirius-os-pia-installer`

The Challenge: PIA VPN is a proprietary binary that must be fetched from upstream, built in an isolated environment, and deployed system-wide—all while respecting the immutable nature of the host system.

What SPF Does:

    sysusers.d creates the groups: piahnsd (954), piavpn (955)

    Provisioning deploys units to /etc/

    Linger enabled for user 1000

    User extraction service builds PIA in Distrobox

    Atomic handoff (.tmp → sync → mv -f)

    Systemd path unit triggers root deployment

    Dormant uninstaller ensures complete cleanup

### Installation:

```bash
sudo curl -Lo /etc/yum.repos.d/_copr_jonathonp3-sirius-os.repo \
  https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/repo/fedora-44/jonathonp3-sirius-os-fedora-44.repo
sudo rpm-ostree install sirius-os-pia-installer
sudo systemctl reboot
```

### Verification:
Check root deployment watcher is active
```bash
sudo systemctl status piavpn-deploy.path --no-pager
```

Check PIA binaries exist:
```bash
ls -la /usr/local/bin/piactl
ls -la /var/opt/piavpn/bin/
```

Check PIA service is running:
```bash
sudo systemctl status piavpn.service --no-pager
```

Check PIA is connected (You need to login first):
```bash
piactl get connectionstate
```

Check VPN IP (should show VPN IP, not your real IP):
```bash
piactl get vpnip
```

Check public IP (your real IP, for comparison):
```bash
piactl get pubip
```

Check for updates (manual trigger):
```bash
piactl get availableupdates
```

Check log for extraction/deployment:
```bash
journalctl --user -u piavpn-extract.service -n 20 --no-pager
sudo journalctl -u piavpn-deploy.service -n 20 --no-pager
```

Check installed version:
```bash
piactl --version
```

Check version file (deployed version):
```bash
cat /var/opt/piavpn/share/version.txt
```

## A Note on AI-Assisted Development

This project was developed with the assistance of AI tools, but it was not produced by AI independently.

I developed the ideas, made the engineering decisions, designed the architecture, and remained responsible for integrating and validating the final result. I used AI to explore documentation, explain detailed coding examples when needed, suggest alternative approaches, and help me become familiar with different coding implementations.

AI tools were not able to solve every technical problem in the project. At times, especially during the early development of the SFP framework, they had an incomplete understanding of the software’s design and underlying requirements. For example, the purpose of the provisioning script for the uninstaller is create a dormant uninstaller service that would not be tracked by rpm-ostree.

Resolving problems such as this required human reasoning: understanding the system, identifying underlying issues, testing each hypothesis, and changing the approach when necessary.

I therefore view AI-assisted development as a collaborative process. AI contributes suggestions and accelerates exploration, while I provide the direction, judgement, verification, and final decisions. I read and evaluate all generated code to ensure that I understand it and that it behaves as expected. I modify or replace it whenever necessary, and I remain responsible for the resulting project.


## AI Tools Used

I have not tested advanced LLMs — only the free versions.

Despite this limitation, the free versions were sufficient to:

| Use Case | What AI Provided |
|---|---|
| Exploration | Documentation and unfamiliar concepts |
| Code Generation | Examples and implementation suggestions |
| Problem Solving | Potential approaches to problems |
| Debugging | Cryptic errors requiring human reasoning |
| Documentation | Refinement and clarification |
| System Analysis | Deep overview of processes |


Using Free Tools Effectively

Using free tools does not diminish the outcome. It demonstrates that effective AI-assisted development does not require expensive tools. Clear thinking, careful evaluation, and a willingness to test and iterate is enough.

To best use free tools, I suggest you:

    Read everything the AI provides — `Evaluate what is true and what is not'

    Investigate as many possibilities as you can — Explore alternatives

    Document your journey — The more information you provide, the smarter it gets. Vibe coding is a complete waste of time and unproductive.

For me, AI-assisted development is a two-way street. The AI learns from the project. The more information I provide and document ( I keep detailed notes) as well as the avenues taken, the smarter it gets. This was the magic sauce for myself in getting this and other projects up and running and completed. 


## What This Means for SPF

| Aspect | Reality |
|--------|---------|
| **AI tools used** | Free versions only |
| **Cost** | Zero |
| **Effectiveness** | Sufficient for the task provided you are prepared to spend a lot of time on the project and do some serious problem solving |
| **Limitations** | Can produce incorrect code, can become confused with repetition and redundancy |
| **Human role** | Direction, testing, code evaluation and integration |

The result is a stable framework built with free tools, human judgement, and a lot of testing.

The purpose of AI assisted development for myself is to learn as much as I can about the inner workings of the Linux operating system. This project needed to be readable, have logic, be not overwhelming and must be reproducible without fragility.

License

GPLv3

## Links

- [GitHub Organization](https://github.com/jonathonp3)
- [COPR Repository](https://copr.fedorainfracloud.org/coprs/jonathonp3/sirius-os/)
- [sirius-os-virtualization](https://github.com/jonathonp3/sirius-os-virtualization)
- [sirius-os-pia-installer](https://github.com/jonathonp3/sirius-os-pia-installer)

