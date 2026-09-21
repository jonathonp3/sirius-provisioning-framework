# SPF Customization

## The Framework Is a Foundation

SPF is not just a fix for virtualization. It is a **framework** for managing complex software lifecycles on immutable systems. The foundation is there for easy adoption and customization.

---

## What SPF Provides

| Component | Purpose |
|-----------|---------|
| **Blueprint Provisioning** | Store templates in `/usr/share/`, deploy to `/etc/` at runtime |
| **User-to-Root Handoff** | Secure, event-driven handoff via systemd path units |
| **Dormant Uninstaller** | Complete cleanup on RPM removal |
| **Atomic Handoff** | Reliable file transfer (`.tmp` → `sync` → `mv -f`) |
| **sysusers.d** | Create groups on the live system |
| **tmpfiles.d** | Create directories with correct permissions |
| **First-boot provisioning** | Run scripts on the live system, not in a chroot |

---

## What Can Be Built with SPF

| Application | How SPF Helps |
|-------------|---------------|
| **Virtualization** | Groups, directories, services, bridge |
| **VPN (PIA)** | User extraction, atomic handoff, root deployment |
| **Development tools** | Custom services, directories, groups |
| **System utilities** | Provisioning on first boot |
| **Any complex software** | Blueprint-based deployment |

---

## How to Build Your Own SPF Implementation

### Step 1: Follow the Schematic

https://github.com/jonathonp3/sirius-provisioning-framework/blob/main/docs/SPF-package-schematic.md
Use the [SPF Package Schematic](SPF-package-schematic.md) as your template:

```
sirius-os-<package>/
├── spec/          # RPM spec file
├── sysusers.d/    # Group creation
├── tmpfiles.d/    # Directory creation
├── usr-share/     # Blueprints (templates)
├── libexec/       # Provisioning scripts
└── systemd/       # Provisioning services
```

### Step 2: Identify What's Missing

Ask:
- What groups need to exist on the live system?
- What directories need correct permissions?
- What services need to be enabled?
- What cleanup is needed on removal?

### Step 3: Create the Provisioning Logic

| File | Purpose |
|------|---------|
| `sysusers.d/<package>.conf` | Create missing groups |
| `tmpfiles.d/<package>.conf` | Create directories |
| `libexec/<package>-provision.sh` | Deploy blueprints to `/etc/` |
| `libexec/<package>-uninstall-provision.sh` | Create dormant uninstaller |
| `systemd/<package>-provision.service` | Trigger provisioning on first boot |

### Step 4: Test on the Live System

| Test | What to Verify |
|------|----------------|
| **Reboot** | Services start correctly |
| **Groups** | Created on the live system |
| **Directories** | Correct permissions |
| **Uninstall** | Clean removal, no artifacts |
| **Reinstall** | Works from clean state |

---

## For Bazzite Developers

| Option | Effort | Result |
|--------|--------|--------|
| **Adopt SPF directly** | Low | ✅ Works |
| **Fork SPF, customize** | Medium | ✅ Works, branded |
| **Learn from SPF, build own** | Higher | ✅ Works, fully integrated |

**The framework is ready. The examples are there. The documentation is complete.**

---

## The Foundation Is There

SPF provides:

- **A proven pattern** — Tested on real systems
- **A working example** — `sirius-os-virtualization`, `sirius-os-pia-installer`
- **A documented schematic** — [SPF Package Schematic](SPF-package-schematic.md)
- **A reusable structure** — Copy, adapt, deploy


## SPF Customization

<u>The Framework Is a Foundation</u>

SPF is not just a fix for virtualization. It is a framework for managing complex software lifecycles on immutable systems. The foundation is there for easy adoption and customization.

| Component | Purpose |
|---|---|
| Blueprint Provisioning | Store templates in `/usr/share/`, deploy to `/etc/` at runtime |
| User-to-Root Handoff | Secure, event-driven handoff via systemd path units |
| Dormant Uninstaller | Complete cleanup on RPM removal |
| Atomic Handoff | Reliable file transfer (`.tmp` → `sync` → `mv -f`) |
| `sysusers.d` | Create groups on the live system |
| `tmpfiles.d` | Create directories with correct permissions |
| First-boot provisioning | Run scripts on the live system, not in a chroot |



| Application | How SPF Helps |
|---|---|
| Virtualization | Groups, directories, services, and bridges |
| VPN (PIA) | User extraction, atomic handoff, and root deployment |
| Development tools | Custom services, directories, and groups |
| System utilities | Provisioning on first boot |
| Any complex software | Blueprint-based deployment |


How to Build Your Own SPF Implementation


Step 1: Follow the Schematic

Use the SPF Package Schematic as your template.
Step 2: Identify What's Missing

Ask yourself:

    What groups need to exist on the live system?

    What directories need correct permissions?

    What services need to be enabled?

    What cleanup is needed on removal?

    

Step 3: Create the Provisioning Logic

| File | Purpose |
|---|---|
| `sysusers.d/<package>.conf` | Create missing groups |
| `tmpfiles.d/<package>.conf` | Create directories |
| `libexec/<package>-provision.sh` | Deploy blueprints to `/etc/` |
| `libexec/<package>-uninstall-provision.sh` | Create dormant uninstaller |
| `systemd/<package>-provision.service` | Trigger provisioning on first boot |


Step 4: Test on the Live System

| Test | What to Verify |
|---|---|
| Reboot | Services start correctly |
| Groups | Created on the live system |
| Directories | Correct permissions |
| Uninstall | Clean removal with no artifacts |
| Reinstall | Works from a clean state |


For Developers

| Option | Effort | Result |
|---|---|---|
| Adopt SPF directly | Low | ✅ Works |
| Fork SPF and customize | Medium | ✅ Works, branded |
| Learn from SPF and build your own | Higher | ✅ Works, fully integrated |

The framework is ready with examples and the documentation is complete.


## The Foundation Is There

SPF provides:

    A proven pattern       Tested on real systems
    A working example      sirius-os-virtualization, sirius-os-pia-installer
    A documented schematic SPF Package Schematic
    A reusable structure   Copy, adapt, deploy


| Document | Purpose |
|---|---|
| `SPF-package-schematic.md` | The structure and required components |
| `SPF-customization.md` | How to build your own SPF implementation |


🎯 Summary

Document                 Purpose
-----------------------  --------------------------------------------
SPF-package-schematic.md The structure and required components
SPF-customization.md     How to build your own SPF implementation

| Document | Purpose |
|---|---|
| `SPF-package-schematic.md` | The structure and required components |
| `SPF-customization.md` | How to build your own SPF implementation |

