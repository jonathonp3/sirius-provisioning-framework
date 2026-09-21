# User-to-Root Handoff

## What It Is

User-to-Root Handoff is a secure, event-driven pattern for transferring artifacts from user space to root space without requiring sudo privileges from the user.


## The Problem

Many complex software installations require:

    User-level extraction — Building artifacts in containers

    Root-level deployment — Installing system-wide

The challenge is moving artifacts from user to root without:

    Giving the user sudo privileges

    Creating security vulnerabilities

    Requiring manual intervention


## The Solution: Systemd Path Units

```bash
[Unit]
Description=Watch for staging archive

[Path]
PathExists=/run/user/1000/cache/app/artifact.tar.gz

[Install]
WantedBy=multi-user.target
```

## How It Works

1. User builds artifact in Distrobox container
2. User writes artifact to /run/user/1000/cache/
3. Systemd path unit detects the file
4. Systemd triggers root-level service
5. Root reads and deploys the artifact
6. Root cleans up the trigger file


## The Secure Handoff


| Step | Who  | What                                             |
|------|------|--------------------------------------------------|
| 1    | User | Builds artifact in an isolated container        |
| 2    | User | Writes to `/run/user/1000/cache/` (user-owned)  |
| 3    | Root | systemd path unit triggers                      |
| 4    | Root | Reads and deploys the artifact                  |
| 5    | Root | Cleans up the trigger file                      |


| Benefit   | Explanation                                      |
|-----------|--------------------------------------------------|
| Zero-sudo | User doesn't need root privileges                |
| Secure    | User can't modify system directories             |
| Event-driven | Immediate trigger, no polling                 |
| Reliable  | Atomic handoff ensures integrity                 |


## Example: PIA VPN Handoff

```bash
# User extracts PIA in Distrobox
distrobox enter -n pia-factory -- bash -c "
    tar -czf /tmp/pia-stage.tar.gz opt/piavpn
"
```

User writes to cache
```bash
podman cp pia-factory:/tmp/pia-stage.tar.gz /run/user/1000/cache/pia-vpn/pia-stage.tar.gz.tmp
sync /run/user/1000/cache/pia-vpn/pia-stage.tar.gz.tmp
mv -f /run/user/1000/cache/pia-vpn/pia-stage.tar.gz.tmp /run/user/1000/cache/pia-vpn/pia-stage.tar.gz
```

Root path unit triggers
```bash
[Path]
PathExists=/run/user/1000/cache/pia-vpn/pia-stage.tar.gz
```

Root deploys
```bash
tar -xpzf /run/user/1000/cache/pia-vpn/pia-stage.tar.gz -C /
systemctl start piavpn.service
```


