#!/usr/bin/env bash
#
# setup-host.sh — Bootstrap a Debian 13 (Trixie) VM for Inception of Things
#
# This script installs:
#   1. Essential build tools and dependencies
#   2. VirtualBox 7.2  (from Oracle's repo — not in Debian 13 main repos)
#   3. Vagrant          (from HashiCorp .deb)
#
# It also:
#   - Blacklists KVM modules so VirtualBox gets exclusive VT-x access
#   - Verifies nested-virtualization support (VT-x visible to the guest)
#
# Usage:
#   sudo ./setup-host.sh
#
# Prerequisites (on the UBUNTU 24.04 HOST, before booting this VM):
#   VBoxManage modifyvm "<vm-name>" --nested-hw-virt on
#   (or enable "Nested VT-x/AMD-V" in the VM's System → Processor settings)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No colour

banner() { echo -e "\n${CYAN}═══════════════════════════════════════════${NC}"; }

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Must run as root ─────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    err "Please run this script with sudo:"
    echo "    sudo ./setup-host.sh"
    exit 1
fi

banner
echo -e "${CYAN}  Inception of Things — Host Setup${NC}"
echo -e "${CYAN}  Debian 13 (Trixie)${NC}"
banner

# ── Configuration ────────────────────────────────────────────────────────────
VBOX_VERSION="7.2"          # VirtualBox major.minor
VAGRANT_VERSION="2.4.9"     # Vagrant version
VAGRANT_DEB="vagrant_${VAGRANT_VERSION}-1_amd64.deb"

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Check for nested virtualisation
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[1/7] Checking for hardware virtualisation support (VT-x / AMD-V)..."

VT_COUNT=$(grep -Ec '(vmx|svm)' /proc/cpuinfo 2>/dev/null || true)
if [[ "${VT_COUNT}" -eq 0 ]]; then
    warn "No VT-x/AMD-V flags found in /proc/cpuinfo."
    warn "Nested virtualisation is probably NOT enabled on the outer VM."
    warn ""
    warn "On your Ubuntu 24.04 host, run (with the VM powered off):"
    warn "  VBoxManage modifyvm \"<vm-name>\" --nested-hw-virt on"
    warn ""
    warn "Or enable it in VirtualBox GUI:"
    warn "  Settings → System → Processor → Enable Nested VT-x/AMD-V"
    warn ""
    warn "Continuing anyway — VirtualBox will install but VMs won't start"
    warn "until nested virtualisation is enabled."
else
    info "Hardware virtualisation is available (${VT_COUNT} vCPUs with VT-x/AMD-V)."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — System update
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[2/7] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Install base dependencies
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[3/7] Installing base dependencies..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    openssh-client \
    unzip \
    vim \
    build-essential \
    dkms \
    linux-headers-"$(uname -r)"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Blacklist KVM modules (conflicts with VirtualBox)
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[4/7] Blacklisting KVM kernel modules (VirtualBox needs exclusive VT-x)..."

BLACKLIST_FILE="/etc/modprobe.d/blacklist-kvm.conf"
if [[ ! -f "${BLACKLIST_FILE}" ]]; then
    cat > "${BLACKLIST_FILE}" <<'EOF'
# Blacklist KVM so VirtualBox can use VT-x exclusively
blacklist kvm
blacklist kvm_intel
blacklist kvm_amd
EOF
    info "Created ${BLACKLIST_FILE}"

    # Unload KVM modules if they are currently loaded
    for mod in kvm_intel kvm_amd kvm; do
        if lsmod | grep -q "^${mod} "; then
            rmmod "${mod}" 2>/dev/null && info "Unloaded ${mod}" || warn "Could not unload ${mod} (may need reboot)"
        fi
    done
else
    info "KVM blacklist already in place."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Install VirtualBox from Oracle's repository
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[5/7] Installing VirtualBox ${VBOX_VERSION} from Oracle repository..."
info "      (Debian 13 Trixie removed VirtualBox from its main repos)"

VBOX_KEYRING="/usr/share/keyrings/oracle-virtualbox-2016.gpg"
VBOX_LIST="/etc/apt/sources.list.d/virtualbox.list"

# Import Oracle's GPG key
if [[ ! -f "${VBOX_KEYRING}" ]]; then
    info "Importing Oracle VirtualBox GPG key..."
    curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc \
        | gpg --dearmor -o "${VBOX_KEYRING}"
fi

# Add the repository
VBOX_REPO="deb [arch=amd64 signed-by=${VBOX_KEYRING}] https://download.virtualbox.org/virtualbox/debian trixie contrib"
if [[ ! -f "${VBOX_LIST}" ]] || ! grep -qF "trixie" "${VBOX_LIST}" 2>/dev/null; then
    info "Adding Oracle VirtualBox repository for Trixie..."
    echo "${VBOX_REPO}" > "${VBOX_LIST}"
fi

apt-get update -qq

# Install VirtualBox
if ! dpkg -l | grep -q "virtualbox-${VBOX_VERSION}"; then
    info "Installing virtualbox-${VBOX_VERSION}..."
    apt-get install -y "virtualbox-${VBOX_VERSION}"
else
    info "virtualbox-${VBOX_VERSION} is already installed."
fi

# Rebuild kernel modules (just in case)
if command -v /sbin/vboxconfig >/dev/null 2>&1; then
    info "Rebuilding VirtualBox kernel modules..."
    /sbin/vboxconfig || warn "vboxconfig had issues — you may need to reboot"
fi

# Add current (non-root) user to the vboxusers group
SUDO_USER_NAME="${SUDO_USER:-}"
if [[ -n "${SUDO_USER_NAME}" ]]; then
    if ! id -nG "${SUDO_USER_NAME}" | grep -qw vboxusers; then
        usermod -aG vboxusers "${SUDO_USER_NAME}"
        info "Added user '${SUDO_USER_NAME}' to the 'vboxusers' group."
        info "You may need to log out and back in for this to take effect."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 6 — Install Vagrant
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[6/7] Installing Vagrant ${VAGRANT_VERSION}..."

if ! command -v vagrant >/dev/null 2>&1; then
    TMPDIR_VAGRANT=$(mktemp -d)
    cd "${TMPDIR_VAGRANT}"

    info "Downloading vagrant ${VAGRANT_VERSION}..."
    wget -q "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/${VAGRANT_DEB}"

    info "Installing .deb package..."
    dpkg -i "${VAGRANT_DEB}" || apt-get install -f -y

    rm -rf "${TMPDIR_VAGRANT}"
else
    INSTALLED_VER=$(vagrant --version 2>/dev/null | awk '{print $2}')
    info "Vagrant is already installed (version ${INSTALLED_VER})."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 7 — Verify everything
# ─────────────────────────────────────────────────────────────────────────────
echo
info "[7/7] Verifying installation..."

echo
echo "  Debian version:"
echo "    $(cat /etc/debian_version)"

echo
echo "  VirtualBox:"
if command -v VBoxManage >/dev/null 2>&1; then
    echo "    $(VBoxManage --version)"
else
    err "    VBoxManage not found!"
fi

echo
echo "  Vagrant:"
if command -v vagrant >/dev/null 2>&1; then
    echo "    $(vagrant --version)"
else
    err "    vagrant not found!"
fi

echo
echo "  Kernel:"
echo "    $(uname -r)"

echo
echo "  Nested VT-x:"
if [[ "${VT_COUNT}" -gt 0 ]]; then
    echo -e "    ${GREEN}Available (${VT_COUNT} vCPUs)${NC}"
else
    echo -e "    ${YELLOW}NOT available — enable nested VT-x on the host${NC}"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
banner
echo -e "${GREEN}  ✓  Host VM setup complete!${NC}"
banner

echo
echo "  Next steps:"
echo "    1. If this is a fresh install, reboot to load VirtualBox kernel modules:"
echo "       sudo reboot"
echo "    2. After reboot, navigate to your project and run:"
echo "       cd /path/to/InceptionOfThings/p1"
echo "       vagrant up"
echo