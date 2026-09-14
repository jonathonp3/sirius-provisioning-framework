# Sirius OS Template Package

An [SPF](../../docs/) template for building packages that install complex
software on Fedora Atomic systems.

Copy this repository, rename `template` to your package name, fill in the
provisioning logic, and ship it. The wiring — first-boot provisioning, atomic
handoff, dormant uninstaller — is already in place and verified against three
working SPF packages.

---

## Why This Exists

On `rpm-ostree` systems, `%post` and `%preun` scriptlets run in a sandboxed
chroot during image composition, not on the live system. They cannot:

- create groups on the running system
- write to `/var/` or configure `/etc/` at runtime
- start or enable services
- clean up state when the package is removed

SPF replaces those scriptlets with first-boot systemd services. This template
is the minimal implementation of that pattern.

---

## Quick Start

### 1. Copy the template

The template lives inside the SPF framework repository. Copy it out to start
a new project:

```bash
cp -r examples/template ~/sirius-os-myproject
cd ~/sirius-os-myproject
```

If you prefer to work from a standalone repository, clone the framework and
copy from there:

```bash
git clone https://github.com/jonathonp3/sirius-provisioning-framework
cp -r sirius-provisioning-framework/examples/template ~/sirius-os-myproject
cd ~/sirius-os-myproject
```

### 2. Rename and replace `template`

Every file name, spec path, systemd unit name, and script reference uses the
literal string `template`. Replace it with your package name:

```bash
mv sirius-os-template.spec sirius-os-myproject.spec
mv template.sysusers myproject.sysusers
# repeat for the remaining template-* files, or:

grep -rl 'template' . | xargs sed -i 's/template/myproject/g'
```

### 3. Fill in the four points of customisation

| File | What to change |
| :--- | :--- |
| `myproject.sysusers` | Declare the groups your package needs. Only list groups missing from the base image. |
| `myproject-extract.sh` | Build your artifact in a Distrobox container, then hand it off with `.tmp` → `sync` → `mv -f`. Delete this file and its `.service` / `.timer` if your package has no user-level build step. |
| `myproject-deploy.sh` | Install the artifact as root: extract the staging archive, set permissions, create symlinks, start the runtime service. |
| `myproject-uninstall-provision.sh` | Add your cleanup logic to the embedded `TASK_EOF` block. Remove every artifact your deploy script created. |

### 4. Adjust the spec

Update `Name:`, `Summary:`, `URL:`, and the `Requires:` list to match your
package. Everything else is already correct.

### 5. Build

```bash
rpmbuild -bb sirius-os-myproject.spec
```

Or publish straight to COPR:

```bash
rpmbuild -bs sirius-os-myproject.spec
copr-cli build <your-copr-project> ~/rpmbuild/SRPMS/sirius-os-myproject-*.src.rpm
```

---

## Repository Layout

```
examples/template/
├── sirius-os-template.spec              # RPM spec
├── template.sysusers                    # groups created at first boot
│
├── template-extract.sh                  # user-level extraction (optional)
├── template-extract.service             # user-level service (optional)
├── template-extract.timer               # user-level timer (optional)
│
├── template-deploy.sh                   # root-level deployment
├── template-deploy.service              # triggered by the path unit
├── template-deploy.path                 # watches for the staging archive
│
├── template-provision.sh                # first-boot provisioning
├── template-provision.service           # first-boot trigger
│
├── template-uninstall-provision.sh      # generates the dormant uninstaller
└── template-uninstall-provision.service
```

---

## What This Template Gives You

| Pillar | Where it lives in the template |
| :--- | :--- |
| **sysusers.d** | `template.sysusers` → `/usr/lib/sysusers.d/sirius-os-template.conf` |
| **Blueprint Provisioning** | Blueprints in `/usr/share/sirius/template/`, deployed to `/etc/` by `template-provision.sh` |
| **User-to-Root Handoff** | `template-extract.sh` writes to `/run/user/1000/cache/`; `template-deploy.path` triggers `template-deploy.service` |
| **Atomic Handoff** | `.tmp` → `sync` → `mv -f` in both `template-extract.sh` and the trigger pattern |
| **Dormant Uninstaller** | Generated at first boot by `template-uninstall-provision.sh` into `/etc/`, triggered by the absence of `/usr/libexec/sirius/template-provision.sh` |

---

## The Four Pillars

### sysusers.d — groups at first boot

Groups listed in `template.sysusers` are created on the live system by
`systemd-sysusers` when the new deployment boots. They do not need to be
created by a scriptlet, and they cannot be created during image composition.

Only list groups that are **missing** from the base image. Adding a group that
already exists will cause `rpm-ostree` to fail the transaction with a duplicate
definition error.

### Blueprint Provisioning — services via /etc/

Service units shipped by the RPM live in `/usr/share/sirius/template/`. They
are not installed into `/etc/systemd/system/` during the build, because `/usr/`
is read-only at runtime and files owned by the RPM disappear when the package
is removed.

Instead, `template-provision.sh` copies them into `/etc/systemd/system/` on
first boot. Files created at runtime are owned by nobody, so `rpm-ostree` leaves
them alone — which is what lets the dormant uninstaller survive package removal.

### User-to-Root Handoff — no sudo for the user

The user-level `template-extract.sh` runs as the primary user and builds the
artifact in an isolated container. It writes the finished archive into
`/run/user/1000/cache/`, which the user owns and root can read.

`template-deploy.path` watches that directory. The moment the archive appears,
it triggers the root-level `template-deploy.service`, which installs the
artifact system-wide. No sudo prompt, no manual step.

### Dormant Uninstaller — clean removal

`template-uninstall-provision.sh` runs at first boot and generates a service
plus a task script into `/etc/`. Those files are created at runtime, so
`rpm-ostree` does not track them and they survive package removal.

The generated service uses `ConditionPathExists=!/usr/libexec/sirius/template-provision.sh`
as its trigger. When the RPM is removed, that vendor file disappears from the
new deployment and the condition passes. On the next boot the uninstaller runs,
cleans up all persistent state, and removes itself.

---

## Four Points to Customise

Everything else is wiring. When you start a new project, these are the only
files you actually need to edit.

### 1. `template.sysusers`

```
# Only groups missing from the base image
g mygroup 954 - -
```

### 2. `template-extract.sh`

Build your artifact in a Distrobox container, then stage it:

```bash
distrobox create --name my-factory --image fedora:latest --yes >/dev/null
distrobox enter -n my-factory -- bash -c "
    dnf install -y build-dependencies
    make
    tar -czf /tmp/my-stage.tar.gz -C / path/to/artifacts
"

podman cp my-factory:/tmp/my-stage.tar.gz "${STAGING_TAR}.tmp"
sync "${STAGING_TAR}.tmp"
mv -f "${STAGING_TAR}.tmp" "$STAGING_TAR"
```

If your package has no user-level build step, delete `template-extract.sh`,
`template-extract.service`, and `template-extract.timer`, and remove their
`Source` / `%files` entries from the spec. You will also need to trigger
`template-deploy.service` some other way — either by hand, or from your
provisioning script.

### 3. `template-deploy.sh`

Install the staged artifact as root:

```bash
tar -xpzf "$STAGING_TAR" -C / --no-same-owner
chown -R root:root "$DEST_DIR"
ln -sf "$DEST_DIR/bin/example" /usr/local/bin/example
systemctl daemon-reload
systemctl restart example.service --no-block || true
rm -f "$STAGING_TAR"
```

### 4. `template-uninstall-provision.sh`

Replace the sample cleanup inside the `TASK_EOF` heredoc with the inverse of
your deploy script. Remove every file your deploy script created, stop every
service it started, and delete every directory under `/var/` it populated.

The trickiest case is state written by the application itself — NetworkManager
profiles, firewall rules, credential files — because the RPM is no longer
present to tell you what was written. Use your provisioning or deploy scripts
as the reference: anything they create must be cleaned up here.

---

## The Rule That Makes It Work

> A file listed in the RPM's `%files` is owned by the package. On
> `rpm-ostree remove`, it is removed from the new deployment unless the admin
> has modified it at runtime. A file created at runtime by a script is owned by
> nobody. `rpm-ostree` has no record of it, so it persists.

This is why the uninstaller is generated at first boot rather than shipped in
the RPM. If you ship it in `%files`, it will work in testing and then silently
disappear the moment a user removes the package — which is exactly when it is
needed.

---

## Verified Implementations

Three packages use this exact template. Read them if a step in the template
doesn't make sense.

| Package | Purpose |
| :--- | :--- |
| [`sirius-os-virtualization`](https://github.com/jonathonp3/sirius-os-virtualization) | libvirt and virt-manager, with a working NAT bridge |
| [`sirius-os-pia-installer`](https://github.com/jonathonp3/sirius-os-pia-installer) | Private Internet Access VPN client, built in a Distrobox container |
| [`sirius-os-protonvpn`](https://github.com/jonathonp3/sirius-os-protonvpn) | Proton VPN client, with NetworkManager kill-switch cleanup |

---

## Framework Documentation

- [SPF Package Schematic](../../docs/SPF-package-schematic.md) — the required structure
- [SPF Customization](../../docs/spf-customization.md) — building your own implementation
- [Blueprint Provisioning](../../docs/blueprint-provisioning.md)
- [User-to-Root Handoff](../../docs/user-to-root-handoff.md)
- [Atomic Handoff](../../docs/atomic-handoff.md)
- [Dormant Uninstaller](../../docs/dormant-uninstaller.md)

---

## License

MIT
