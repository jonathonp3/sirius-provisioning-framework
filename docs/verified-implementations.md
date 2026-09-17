# Verified Implementations

Three packages use the SPF pattern in production. This page documents what
each one demonstrates and, where applicable, the specific failure it was
built to solve.

| Package | Demonstrates |
| :--- | :--- |
| [`sirius-os-virtualization`](https://github.com/jonathonp3/sirius-os-virtualization) | Groups, directories, and a working NAT bridge via first-boot provisioning |
| [`sirius-os-pia-installer`](https://github.com/jonathonp3/sirius-os-pia-installer) | User-level extraction via Distrobox, atomic handoff, monthly update timer |
| [`sirius-os-protonvpn`](https://github.com/jonathonp3/sirius-os-protonvpn) | Full reproduction of a runtime-state failure and its automated cleanup |

---

## sirius-os-virtualization

### What it solves

On Fedora Atomic systems, installing the virtualization packages via
`rpm-ostree install` does not create the full runtime configuration needed
for virtualization to work. The `libvirt-qemu` and `virtnetwork` groups are
missing, `virtnetworkd.service` fails with a permission error, and the
default NAT bridge (`virbr0`) is never created.

### What SPF does

- `sysusers.d` creates the missing groups on the live system
- `tmpfiles.d` creates the required directories with correct ownership
- First-boot provisioning enables the modular libvirt services
- The provisioning script starts the default network, creating `virbr0`

### Result

`virt-manager` works after a single `rpm-ostree install` and reboot, with a
working NAT bridge. Clean removal is handled by a dormant uninstaller that
strips the firewalld service definitions, libvirt network configs, and
provisioning marker.

---

## sirius-os-pia-installer

### What it solves

PIA VPN is distributed as a proprietary `.run` installer for conventional
Linux systems. On Atomic systems, the RPM's `%post` scriptlets cannot fetch
or install it, because they run in a build chroot with no network and no
write access to `/var/`.

### What SPF does

- User-level extraction runs as the primary user, builds PIA in a Distrobox
  container, and stages the result in `/run/user/1000/cache/`
- An atomic handoff (`.tmp` → `sync` → `mv -f`) delivers the archive to the
  path unit's watch directory
- `piavpn-deploy.path` triggers the root-level deployment, which installs
  the binaries under `/var/opt/piavpn` and enables the runtime service
- A monthly timer checks for updates and re-runs the extraction if needed

### Result

PIA installs and updates on Atomic systems without user intervention. Clean
removal flushes the firewall, stops the daemons, and deletes the persistent
state directory.

---

## sirius-os-protonvpn

### What it solves

Two problems, one of which is reproduced end to end below.

**1. The release RPM is pinned.** Installing `protonvpn-stable-release` from
a URL creates a `LocalPackage` in `rpm-ostree`, which never updates on
`rpm-ostree upgrade`. This package ships `protonvpn-stable.repo` so the
repository definition is owned and versioned by the package once installed —
but the repository must be seeded before the first install, because
`rpm-ostree` resolves `Requires:` against the currently booted deployment
and cannot read a `.repo` file from a package staged in the same transaction.

**2. The Advanced kill switch leaves persistent state.** When the Advanced
kill switch is enabled, the Proton app writes a NetworkManager connection
profile to `/etc/`. Removing the package does not remove the profile. On the
next boot, NetworkManager recreates a dummy interface with a route metric
lower than any real connection, and the machine has no internet.


### Prerequisite

The Proton repository must be seeded before the first install. This is a
`rpm-ostree` constraint, not a packaging choice: dependency resolution runs
against the repositories visible on the currently booted deployment, so a
`.repo` file shipped inside an RPM cannot satisfy that RPM's own `Requires:`
in the same transaction.

```bash
sudo tee /etc/yum.repos.d/protonvpn-stable.repo <<'EOF'
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-$releasever-stable
enabled=1
gpgcheck=1
gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc
EOF
```

After the repository is seeded, sudo rpm-ostree install sirius-os-protonvpn
resolves everything in a single transaction with full GPG verification. The
shipped .repo file, marked %config(noreplace), takes over ownership of
the path going forward.


### Why the alternative approaches are not used

| Approach | Repo visible at install | GPG verified | Manual step |
| :--- | :--- | :--- | :--- |
| Seed the repo file first (`tee`) | Yes | Yes | One `tee` command |
| COPR Runtime Dependencies | Yes | No (`gpgcheck=0` forced) | None |
| Ship repo inside the RPM | Only after reboot | Yes | Install + reboot first |


COPR's Runtime Dependencies feature hardcodes gpgcheck=0 for external
repositories, because COPR has no way to know or configure an external
repository's GPG key. Installing Proton's packages without signature
verification is not acceptable for a VPN client.

Shipping the repo file inside the RPM does not help either: the file lands
on disk during the install transaction, but rpm-ostree has already resolved
Requires: by then. The user would need to install, reboot, then install
proton-vpn-gnome-desktop in a second transaction — two reboots instead of
one, and no security benefit over the tee step.


### Reproduction of the second problem

Tested on a clean Fedora Silverblue 44 install

Step 1 — Install Proton VPN from the upstream repository

```bash
sudo tee /etc/yum.repos.d/protonvpn-stable.repo <<'EOF'
[protonvpn-fedora-stable]
name=Proton VPN Fedora Stable repository
baseurl=https://repo.protonvpn.com/fedora-$releasever-stable
enabled=1
gpgcheck=1
gpgkey=https://repo.protonvpn.com/fedora-$releasever-stable/public_key.asc
EOF

sudo rpm-ostree install proton-vpn-gnome-desktop
sudo systemctl reboot
```


Step 2 — Enable the Advanced kill switch

Launch the app, log in, connect to any server, disconnect, then:

Settings → Kill switch → Advanced

Confirm the persistent profile exists:

```bash
nmcli -t -f NAME,TYPE,FILENAME connection show | grep pvpn
```

Expected:

```bash
pvpn-killswitch-perm:dummy:/etc/NetworkManager/system-connections/pvpn-killswitch-perm.nmconnection
```

Step 3 — Remove the package and reboot

```bash
rpm-ostree remove proton-vpn-gnome-desktop
systemctl reboot
```

Step 4 — Observe the failure

```bash
ping -c1 1.1.1.1
# 100% packet loss

ip -br link | grep pvpn
# pvpnksintrf1 UNKNOWN ...
```

Step 5 — Confirm the fix

```bash
sudo nmcli connection delete pvpn-killswitch-perm
ping -c1 1.1.1.1
# 1 received, 0% packet loss
```

The dormant uninstaller in sirius-os-protonvpn runs step 5 automatically on
the first boot after the package is removed.


### What SPF does after the seed

The package does not bootstrap the repository. That is handled by the tee step described above.

Once the repository is available, sirius-os-protonvpn provides:

- `protonvpn-stable.repo`, shipped and owned as `%config(noreplace)`, so the repository 
   definition is versioned with the package
- A first-boot provisioning service for setup tasks that RPM scriptlets 
  cannot perform under `rpm-ostree`.
- A dormant uninstaller, generated at first boot, that removes the persistent 
  NetworkManager kill-switch profile during the boot following package removal.

### Result

After the one-time repository seed, sirius-os-protonvpn installs in a single transaction with full GPG verification.

Everything is tracked under `LayeredPackages` ; no `LocalPackages` are created. When the package is removed, the dormant uninstaller:

- Deletes any pvpn* NetworkManager connections.
- Removes orphaned dummy interfaces.
- Restores network access without user intervention.

