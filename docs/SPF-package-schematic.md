# 📋 SPF Package Schematic

## 📋 Overview

Required Components for Any SPF Implementation

```
sirius-os-<package>/
├── spec/
│   └── sirius-os-<package>.spec
├── sysusers.d/
│   └── sirius-os-<package>.conf
├── tmpfiles.d/
│   └── sirius-os-<package>.conf
├── usr-share/
│   └── <package>/                    # Blueprints (templates)
│       ├── *.service
│       ├── *.timer
│       └── *.path
├── libexec/
│   ├── <package>-provision.sh
│   ├── <package>-deploy.sh           # If user-to-root handoff
│   └── <package>-uninstall-provision.sh
└── systemd/
    ├── <package>-provision.service
    └── <package>-uninstall-provision.service
```
    

## 🔧 Scripts and Their Purpose

| Script/File | Purpose | Required? |
|---|---|---|
| `<package>.sysusers` | Creates groups on the live system at first boot | ✅ Yes |
| `<package>.tmpfiles` | Creates directories with correct ownership | ✅ Yes |
| `<package>-provision.sh` | Main provisioning logic—deploys blueprints to `/etc/` | ✅ Yes |
| `<package>-provision.service` | Systemd service that triggers the provisioning script on first boot | ✅ Yes |
| `<package>-uninstall-provision.sh` | Creates the dormant uninstaller service and script | ✅ Yes |
| `<package>-uninstall-provision.service` | Systemd service that creates the dormant uninstaller | ✅ Yes |
| `<package>-deploy.sh` | Root-level deployment logic for the user-to-root handoff | ⚠️ Only if needed |
| `<package>-deploy.path` | Systemd path unit that triggers root deployment | ⚠️ Only if needed |
| `<package>-extract.sh` | User-level extraction logic for building in containers | ⚠️ Only if needed |
| `<package>-extract.timer` | User-level timer for periodic checks/updates | ⚠️ Only if needed |
| `<package>-extract.service` | User-level service that runs the extraction script | ⚠️ Only if needed |


## 📋 The SPF Lifecycle

┌─────────────────────────────────────────────────────────────────────────────┐
│                         RPM BUILD / LAYERING                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  1. RPM is built with:                                                    │
│     • sysusers.d template                                                │
│     • tmpfiles.d template                                                │
│     • Blueprints in /usr/share/                                          │
│     • Provisioning scripts in /usr/libexec/                              │
│     • Systemd services (enabled via symlink)                             │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FIRST BOOT                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  2. sysusers.d creates groups on the live system                          │
│                                                                           │
│  3. tmpfiles.d creates directories on the live system                     │
│                                                                           │
│  4. <package>-provision.service runs (ConditionPathExists=!marker)        │
│     • Copies blueprints from /usr/share/ → /etc/systemd/                  │
│     • Enables services                                                    │
│     • Creates marker file in /etc/<package>/                              │
│                                                                           │
│  5. <package>-uninstall-provision.service runs (ConditionPathExists=!file) │
│     • Creates dormant uninstaller service in /etc/systemd/               │
│     • Creates uninstall script in /etc/<package>-uninstall/              │
│     • Service condition: ConditionPathExists=!/usr/libexec/<package>-provision.sh │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RUNTIME                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  6. Services run from /etc/systemd/ (user has full control)               │
│                                                                           │
│  7. (Optional) User-level extraction via Distrobox/Podman                 │
│                                                                           │
│  8. (Optional) Atomic handoff via .tmp → sync → mv -f                    │
│                                                                           │
│  9. (Optional) Systemd path unit triggers root deployment                 │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         UNINSTALL                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  10. rpm-ostree remove <package>                                          │
│      • Package files are gone from /usr/                                 │
│      • Dormant uninstaller persists in /etc/                             │
│                                                                           │
│  11. Next boot:                                                           │
│      • ConditionPathExists=!/usr/libexec/<package>-provision.sh passes   │
│      • Dormant uninstaller runs                                          │
│      • Removes all artifacts from /etc/, /var/                           │
│      • Removes itself                                                    │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘

## 📝 Example: sirius-os-virtualization Structure

sirius-os-virtualization/
├── spec/
│   └── sirius-os-virtualization.spec
├── sysusers.d/
│   └── sirius-os-virtualization.conf
│       g libvirt-qemu - -
│       g virtnetwork  - -
├── tmpfiles.d/
│   └── sirius-os-virtualization.conf
│       d /var/lib/libvirt 0755 root virtnetwork -
│       d /var/lib/libvirt/dnsmasq 0775 root virtnetwork -
│       d /var/lib/libvirt/network 0775 root virtnetwork -
│       d /var/log/libvirt/qemu 0750 root libvirt-qemu -
├── usr-share/
│   └── virtualization/
│       ├── container-http.xml
│       ├── container-https.xml
│       ├── default-net.xml
│       └── quick-share.xml
├── libexec/
│   ├── sirius-os-virtualization-libvirt-provisioning.sh
│   └── sirius-os-virtualization-uninstall-provision.sh
└── systemd/
    ├── sirius-os-virtualization-libvirt-provision.service
    └── sirius-os-virtualization-uninstall-provision.service
    
## 📝 Example: sirius-os-pia-installer Structure

sirius-os-pia-installer/
├── spec/
│   └── sirius-os-pia-installer.spec
├── sysusers.d/
│   └── sirius-os-pia.conf
│       g piahnsd 954 - -
│       g piavpn  955 - -
├── usr-share/
│   └── pia/
│       ├── piavpn-deploy.service
│       ├── piavpn-deploy.path
│       ├── piavpn-extract.service
│       └── piavpn-extract.timer
├── libexec/
│   ├── piavpn-provision.sh
│   ├── piavpn-deploy.sh
│   ├── piavpn-extract.sh
│   └── pia-uninstall-provision.sh
└── systemd/
    ├── piavpn-provision.service
    ├── piavpn-uninstall-provision.service
    ├── piavpn-extract.timer          # Deployed to /etc/systemd/user/
    └── piavpn-deploy.path            # Deployed to /etc/systemd/system/


## 🎯 Summary: The SPF Core Pattern

| Component | Purpose |
|---|---|
| `sysusers.d` | Create groups on the live system at first boot |
| `tmpfiles.d` | Create directories with correct ownership |
| Provisioning service | Deploy blueprints to `/etc/` on first boot |
| Provisioning script | Main logic for setting up the system |
| Dormant uninstaller | Clean up everything on RPM removal |
| Blueprints | Templates stored in `/usr/share/` and deployed to `/etc/` |
| Marker files | Ensure provisioning runs only once |




## 🎯 Why SPF Works Well


| Aspect | Why It Works |
|---|---|
| Simplicity | Uses existing systemd tools—no new dependencies |
| Consistency | Same pattern across all implementations |
| Reliability | Tested on real systems (my family is using it) |
| Reproducibility | Every installation starts from a clean state |
| Transparency | Users can see and control everything in `/etc/` |
| Cleanup | Dormant uninstallers ensure complete removal, allowing for a clean reinstall |



## 💡 What Makes SPF Logical

1. RPM layers blueprints in /usr/share/
2. First-boot provisioning deploys to /etc/
3. Services run from /etc/ (user has control)
4. Dormant uninstallers clean up on removal


Each step builds on the previous one. No hacking or workarounds are required.


## 🚀 What Makes SPF Valuable

| Benefit | Explanation |
|---|---|
| Solves a real problem | `%post` scripts don't work on rpm-ostree |
| Uses standard tools | systemd, `sysusers.d`, `tmpfiles.d` |
| Proven | Two working implementations |
| Reusable | The pattern can be applied to other packages |
| Professional | Clean, auditable, self-cleaning |


## 📝 Summary Statement


The first problem was PIA VPN on Silverblue. I solved it with my systemd-based, first-boot provisioning approach.

The second problem was virt-manager on Silverblue and Bazzite. I used the same pattern for the rpm and as i predicted it worked better than my previous approach which required manual intervention from the user.

I built a framework for making Fedora Workstation and other software work on Silverblue.


## 🏆 The Journey

| Before | After |
|---|---|
| One-off fix for PIA | Reusable framework |
| Solving problems one by one | Solving problems with a pattern |
| "It works for me" | "It works for everyone" |
| Unknown | Documented and shareable |

