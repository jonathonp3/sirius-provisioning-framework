# Blueprint Provisioning

## What It Is

Blueprint Provisioning is the practice of storing service templates in `/usr/share/` and deploying them to `/etc/` at runtime, rather than placing them directly in `/etc/` during the build process.

## Why It's Needed

On immutable systems (`rpm-ostree`), `/usr/` is read-only during runtime. If services are placed in `/usr/lib/systemd/system/`, they cannot be disabled or modified by the admin.

By storing blueprints in `/usr/share/` and deploying them to `/etc/` at first boot, we achieve:

| Benefit | Explanation |
|---|---|
| Transparency | Users can see what's running |
| Control | Users can disable or modify services |
| Auditability | The system state is clear and verifiable |


## How It Works

    RPM layers blueprint in /usr/share/

    First-boot provisioning copies blueprint to /etc/systemd/system/

    User can enable, disable, or modify the service

    On removal, dormant uninstaller cleans up


## Example: Virtualization Groups

```bash
# Blueprint in /usr/share/
g libvirt-qemu - -
g virtnetwork  - -
```
## Deployed to /etc/ at first boot via sysusers.d

Example: Service Template
```bash
# Blueprint in /usr/share/wolf-os/pia/
piavpn-deploy.service
```



