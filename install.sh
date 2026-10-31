#!/usr/bin/env bash
#
# install.sh - build and install the patched Fusion-MPT SAS driver
# (mptbase, mptscsih, mptsas) on RHEL 9 for LSI SAS1068E controllers
# such as the Dell SAS 6/iR.
#
# Usage (from inside the cloned repo folder):
#   ./install.sh
#
# Run it again after every kernel update to rebuild for the new kernel.

# Stop on errors, on unset variables, and on failures inside pipes.
set -euo pipefail

KVER="$(uname -r)"
MODDIR="/lib/modules/${KVER}/extra"
MODULES=(mptbase mptscsih mptsas)

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# --- 0. Make sure we are running as root -------------------------------
# If not, run this same script again through sudo.
if [[ "${EUID}" -ne 0 ]]; then
    say "Not running as root, re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# --- 0b. Make sure we are inside the repo folder ----------------------
# Move to the folder that contains this script, so the relative paths
# below (the .c files and the Makefile) work wherever it is run from.
cd "$(dirname "$(readlink -f "$0")")"

for f in Makefile mptbase.c mptscsih.c mptsas.c; do
    [[ -f "$f" ]] || die "Missing $f. Run this script from inside the mptsas-el9 folder."
done

# --- 1. Check for the controller --------------------------------------
say "Checking for an LSI SAS1068E controller..."
if lspci | grep -qi "SAS1068"; then
    lspci | grep -i "SAS1068"
else
    warn "No SAS1068 controller found by lspci."
    read -r -p "Continue anyway? [y/N] " answer
    [[ "${answer,,}" == "y" ]] || die "Stopped. This driver is only for SAS1068E controllers."
fi

# --- 2. Check Secure Boot ---------------------------------------------
# An unsigned module will not load if Secure Boot is enabled.
say "Checking Secure Boot..."
if command -v mokutil >/dev/null 2>&1; then
    SB_STATE="$(mokutil --sb-state 2>&1 || true)"
    echo "${SB_STATE}"
    if grep -qi "enabled" <<<"${SB_STATE}" && ! grep -qi "disabled" <<<"${SB_STATE}"; then
        warn "Secure Boot is enabled. The module will be rejected when loaded."
        warn "Disable Secure Boot in the BIOS, or sign the module yourself."
        read -r -p "Continue anyway? [y/N] " answer
        [[ "${answer,,}" == "y" ]] || die "Stopped because Secure Boot is enabled."
    fi
else
    echo "mokutil not installed, skipping the Secure Boot check."
fi

# --- 3. Install build tools -------------------------------------------
say "Installing build tools (gcc, make, kernel headers for ${KVER})..."
if ! dnf install -y gcc make elfutils-libelf-devel "kernel-devel-${KVER}"; then
    die "Could not install kernel-devel-${KVER}. Try: dnf update kernel, reboot, then run this script again."
fi

# The kernel build folder must exist for the build to work.
[[ -d "/lib/modules/${KVER}/build" ]] || die "/lib/modules/${KVER}/build is missing. The kernel-devel version does not match the running kernel."

# --- 4. Build ----------------------------------------------------------
say "Building the modules for kernel ${KVER}..."
make clean >/dev/null 2>&1 || true
make

for m in "${MODULES[@]}"; do
    [[ -f "${m}.ko" ]] || die "Build failed: ${m}.ko was not created. Look for the first 'error:' line above."
done

# --- 5. Install --------------------------------------------------------
say "Installing modules to ${MODDIR}..."
mkdir -p "${MODDIR}"
for m in "${MODULES[@]}"; do
    cp "${m}.ko" "${MODDIR}/"
done

say "Updating the module database (depmod)..."
depmod -a

# --- 6. Load at boot ---------------------------------------------------
say "Setting the driver to load at every boot..."
echo "mptsas" > /etc/modules-load.d/mptsas.conf

# --- 7. Load now -------------------------------------------------------
say "Loading the driver..."
modprobe scsi_transport_sas
if ! modprobe -v mptsas; then
    die "modprobe failed. If the message mentions 'Key was rejected', Secure Boot is blocking the module. Otherwise run: dmesg | tail -30"
fi

# --- 8. Verify ---------------------------------------------------------
say "Checking the result..."
echo
echo "Loaded modules:"
lsmod | grep -E "^mpt" || true
echo
echo "Controller and its driver:"
lspci -k | grep -A 3 -i "SAS1068" || true
echo
echo "Block devices:"
lsblk

cat <<'EOF'

Done.

If lspci shows "Kernel driver in use: mptsas", the driver is working.

If no new disks (sdb, sdc, ...) appear in lsblk, the SAS 6/iR only shows
disks that belong to a RAID volume. Reboot, press Ctrl+C at the SAS 6/iR
banner, and create a volume (RAID 0, 1 or 1E). Creating a volume ERASES
the disks.

After any kernel update, run ./install.sh again.
EOF
