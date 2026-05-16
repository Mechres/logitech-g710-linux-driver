#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDEV_RULE_SRC="${SCRIPT_DIR}/misc/90-logitech-g710-plus.rules"
UDEV_RULE_DST="/etc/udev/rules.d/90-logitech-g710-plus.rules"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: ./install.sh [--skip-udev]

Installs the Logitech G710+ kernel module:
  1. Builds the module
  2. Installs it into the running kernel modules path
  3. Runs depmod
  4. Installs and reloads the udev rule (unless --skip-udev is used)
EOF
    exit 0
fi

SKIP_UDEV=0
if [[ "${1:-}" == "--skip-udev" ]]; then
    SKIP_UDEV=1
elif [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    echo "Use --help for usage." >&2
    exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo bash "$0" "$@"
    fi
    echo "Please run as root (or install sudo)." >&2
    exit 1
fi

# DKMS Installation (Recommended for kernel updates)
if command -v dkms >/dev/null 2>&1; then
    echo "DKMS detected. Installing module via DKMS..."
    DKMS_NAME="hid-lg-g710-plus"
    DKMS_VER="0.1"
    
    # Remove old version if exists
    dkms remove "${DKMS_NAME}/${DKMS_VER}" --all >/dev/null 2>&1 || true
    
    # Create source directory
    rm -rf "/usr/src/${DKMS_NAME}-${DKMS_VER}"
    mkdir -p "/usr/src/${DKMS_NAME}-${DKMS_VER}"
    cp -r "${SCRIPT_DIR}/src/kernel/"* "/usr/src/${DKMS_NAME}-${DKMS_VER}/"
    
    # Add, build and install
    dkms add "${DKMS_NAME}/${DKMS_VER}"
    dkms build "${DKMS_NAME}/${DKMS_VER}"
    dkms install "${DKMS_NAME}/${DKMS_VER}" --force
    echo "DKMS installation complete. Driver will survive kernel updates."
else
    echo "DKMS not found. Falling back to manual module installation..."
    make -C "${SCRIPT_DIR}/src/kernel" clean
    make -C "${SCRIPT_DIR}/src/kernel"
    make -C "${SCRIPT_DIR}/src/kernel" install
fi

echo "Building and installing daemon..."
make -C "${SCRIPT_DIR}/src/userspace" clean
make -C "${SCRIPT_DIR}/src/userspace"
make -C "${SCRIPT_DIR}/src/userspace" install
depmod -a

# Force reload the module
rmmod hid_lg_g710_plus >/dev/null 2>&1 || true
modprobe hid_lg_g710_plus

if [[ ! -f "/etc/g710d.conf" ]]; then
    echo "Installing default configuration to /etc/g710d.conf..."
    install -m 0644 "${SCRIPT_DIR}/g710d.conf.example" "/etc/g710d.conf"
fi

if [[ "${SKIP_UDEV}" -eq 0 ]]; then
    echo "Installing udev rule..."
    install -m 0644 "${UDEV_RULE_SRC}" "${UDEV_RULE_DST}"

    if command -v udevadm >/dev/null 2>&1; then
        udevadm control --reload-rules
        udevadm trigger --subsystem-match=hid
    fi
fi

if command -v systemctl >/dev/null 2>&1; then
    echo "Enabling and starting g710d service..."
    systemctl daemon-reload
    systemctl enable g710d.service
    systemctl restart g710d.service
fi

echo "Done."
