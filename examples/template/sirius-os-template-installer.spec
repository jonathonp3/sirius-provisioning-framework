%define debug_package %{nil}

Name:           sirius-os-template
Version:        1.0.0
Release:        1%{?dist}
Summary:        SPF template package for Sirius OS
License:        MIT
URL:            https://github.com/jonathonp3/sirius-os-template
BuildArch:      noarch

# --- SOURCES ---
Source0:        template.sysusers
Source1:        template-extract.sh
Source2:        template-extract.service
Source3:        template-extract.timer
Source4:        template-deploy.sh
Source5:        template-deploy.service
Source6:        template-deploy.path
Source7:        template-provision.sh
Source8:        template-provision.service
Source9:        template-uninstall-provision.sh
Source10:       template-uninstall-provision.service
Source11:       README.md

# --- BUILD REQUIREMENTS ---
BuildRequires:  systemd-rpm-macros

# --- RUNTIME REQUIREMENTS ---
Requires:       systemd

%description
SPF template package. Demonstrates the four-pillar Sirius Provisioning
Framework pattern: sysusers.d groups, blueprint provisioning into /etc/,
user-to-root handoff, and a dormant uninstaller generated at first boot.

This package installs no software. It is a starting point: copy it, rename
"template" to your package name, and fill in the provisioning logic.

%prep
# nothing to unpack

%build
# nothing to build

%install
install -Dpm0644 %{SOURCE0}  %{buildroot}%{_sysusersdir}/sirius-os-template.conf
install -Dpm0755 %{SOURCE1}  %{buildroot}%{_libexecdir}/sirius-os/template-extract.sh
install -Dpm0644 %{SOURCE2}  %{buildroot}%{_datadir}/sirius-os/template/template-extract.service
install -Dpm0644 %{SOURCE3}  %{buildroot}%{_datadir}/sirius-os/template/template-extract.timer
install -Dpm0755 %{SOURCE4}  %{buildroot}%{_libexecdir}/sirius-os/template-deploy.sh
install -Dpm0644 %{SOURCE5}  %{buildroot}%{_datadir}/sirius-os/template/template-deploy.service
install -Dpm0644 %{SOURCE6}  %{buildroot}%{_datadir}/sirius-os/template/template-deploy.path
install -Dpm0755 %{SOURCE7}  %{buildroot}%{_libexecdir}/sirius-os/template-provision.sh
install -Dpm0644 %{SOURCE8}  %{buildroot}%{_unitdir}/template-provision.service
install -Dpm0755 %{SOURCE9}  %{buildroot}%{_libexecdir}/sirius-os/template-uninstall-provision.sh
install -Dpm0644 %{SOURCE10} %{buildroot}%{_unitdir}/template-uninstall-provision.service
install -Dpm0644 %{SOURCE11} %{buildroot}%{_docdir}/%{name}/README.md

# Enable provisioners via static symlinks in the vendor layer
mkdir -p %{buildroot}%{_unitdir}/multi-user.target.wants
ln -s ../template-provision.service \
    %{buildroot}%{_unitdir}/multi-user.target.wants/template-provision.service
ln -s ../template-uninstall-provision.service \
    %{buildroot}%{_unitdir}/multi-user.target.wants/template-uninstall-provision.service

%files
%doc %{_docdir}/%{name}/README.md

%{_sysusersdir}/sirius-os-template.conf

%{_libexecdir}/sirius-os/template-extract.sh
%{_libexecdir}/sirius-os/template-deploy.sh
%{_libexecdir}/sirius-os/template-provision.sh
%{_libexecdir}/sirius-os/template-uninstall-provision.sh

%dir %{_datadir}/sirius-os/template
%{_datadir}/sirius-os/template/template-extract.service
%{_datadir}/sirius-os/template/template-extract.timer
%{_datadir}/sirius-os/template/template-deploy.service
%{_datadir}/sirius-os/template/template-deploy.path

%{_unitdir}/template-provision.service
%{_unitdir}/template-uninstall-provision.service
%{_unitdir}/multi-user.target.wants/template-provision.service
%{_unitdir}/multi-user.target.wants/template-uninstall-provision.service

%changelog
* Mon Sep 21 2026 Jonathon P <jonathon@sirius-os> - 1.0.0-1
- Initial SPF template
- Namespace standardized on /usr/share/sirius-os/ and /usr/libexec/sirius-os/
- Atomic handoff for unit file deployment in template-provision.sh
- ConditionPathExists on template-deploy.service to skip on removal boot
- Enablement symlink removal in the dormant uninstaller
- Ship README.md as %doc
