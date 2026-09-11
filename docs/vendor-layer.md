# Vendor Layer vs. Runtime Layer

## The Principle

**Vendor-layer services should only be used to enable provisioning scripts—not to run services directly.**

## Why This Matters

| Location | Purpose | User Control |
|----------|---------|--------------|
| `/usr/lib/systemd/system/` | Vendor-layer (read-only) | ❌ Cannot be disabled or modified |
| `/etc/systemd/system/` | Runtime layer (writable) | ✅ Full control |

## SPF's Approach

1. **Vendor layer** (`/usr/lib/systemd/system/`): Contains only the minimal provisioning trigger
2. **First boot**: Provisioning copies templates from `/usr/share/` to `/etc/`
3. **Runtime** (`/etc/systemd/system/`): Services run from here, user can disable or modify


## Example


Vendor layer (minimal trigger)
```bash
/usr/lib/systemd/system/sirius-os-virtualization-libvirt-provision.service
```

Runtime layer (full service)
```bash
/etc/systemd/system/virtnetworkd.service
```

| Benefit | Explanation |
|---|---|
| Transparency | Users can see what's running |
| Control | Users can disable or modify services |
| Auditability | Clear separation between vendor and user configuration |
| Self-healing | If files are missing from `/etc/`, provisioning can restore them |


