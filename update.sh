set -eou pipefail

# Checks that user is running as root
if [[ "${EUID}" -ne 0 ]]; then
    say "Not running as root, re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Makes sure user is running the program in the repo folder
cd "$(dirname "$(readlink -f "$0")")"

for f in Makefile mptbase.c mptscsih.c mptsas.c; do
    [[ -f "$f" ]] || die "Missing $f. Run this script from inside the mptsas-el9 folder."
done
# Checks for device 
say "Checking for an LSI SAS1068E controller..."
if lspci | grep -qi "SAS1068"; then
    lspci | grep -i "SAS1068"
else
    warn "No SAS1068 controller found by lspci."
    read -r -p "Continue anyway? [y/N] " answer
    [[ "${answer,,}" == "y" ]] || die "Stopped. This driver is only for SAS1068E controllers."
fi
# Checks for secure boot
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

# Builds the stuff
say "Building the modules for kernel ${KVER}..."
make clean >/dev/null 2>&1 || true
make

for m in "${MODULES[@]}"; do
    [[ -f "${m}.ko" ]] || die "Build failed: ${m}.ko was not created. Look for the first 'error:' line above."
done

# Installs the stuff
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