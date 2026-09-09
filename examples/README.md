SPF Examples
Implementations of the Sirius Provisioning Framework
1. sirius-os-virtualization

One-command setup of virt-manager on atomic systems (Silverblue, Kinoite, Bazzite).

What it does:

    Creates libvirt-qemu and virtnetwork groups via sysusers.d

    Creates directories with correct permissions via tmpfiles.d

    Enables modular libvirt services (not legacy libvirtd)

    Configures the default NAT network

GitHub: sirius-os-virtualization
2. sirius-os-pia-installer

User-level extraction and root-level deployment of PIA VPN on atomic systems.

What it does:

    Creates piahnsd and piavpn groups via sysusers.d

    Enables linger for user 1000

    Builds PIA in a Distrobox container

    Atomic handoff from user to root

    Systemd path unit triggers root deployment

    Dormant uninstaller for complete cleanup

GitHub: sirius-os-pia-installer
Contributing

If you've built something using SPF, submit a PR to add it here!
