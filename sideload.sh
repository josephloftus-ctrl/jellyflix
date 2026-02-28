#!/usr/bin/env bash
# Jellyflix Apple TV Sideloader
# Sideloads the Jellyflix IPA to Apple TV from Linux using pymobiledevice3 + plumesign
#
# Prerequisites (one-time setup):
#   - pymobiledevice3: pipx install pymobiledevice3
#   - plumesign v2.0.0+: ~/bin/plumesign (from PlumeImpactor releases)
#   - Anisette libs: ~/.config/PlumeImpactor/lib/x86_64/{libCoreADI.so,libstoreservicescore.so}
#   - Apple ID logged in: plumesign account login
#   - avahi-daemon running: sudo systemctl start avahi-daemon
#
# First-time pairing:
#   1. On Apple TV: Settings > Remotes and Devices > Remote App and Devices
#   2. Run: sudo pymobiledevice3 remote pair
#   3. Select the Apple TV and enter PIN if prompted
#
# After pairing, just run: ./sideload.sh [path-to-ipa]

set -euo pipefail

PYMOBILEDEVICE3="${PYMOBILEDEVICE3:-pymobiledevice3}"
PLUMESIGN="${PLUMESIGN:-plumesign}"
PYTHON_VENV="$HOME/.local/share/pipx/venvs/pymobiledevice3/bin/python3"
TUNNELD_PORT=49151
DEVICE_NAME="Living Room Apple TV"
DEVICE_UDID="00008110-000A5DA20ED9801E"

# Default IPA path
DEFAULT_IPA="$HOME/Projects/builds/Jellyflix-signed.ipa"
UNSIGNED_IPA="${1:-$HOME/Projects/builds/Jellyflix-unsigned.ipa}"
SIGNED_IPA="$HOME/Projects/builds/Jellyflix-signed.ipa"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# --- Step 1: Start tunneld if not running ---
if curl -sf "http://127.0.0.1:$TUNNELD_PORT/" >/dev/null 2>&1; then
    log "Tunneld already running"
else
    log "Starting tunneld (needs sudo for tunnel interface)..."
    sudo "$PYMOBILEDEVICE3" remote tunneld \
        --no-usb --no-usbmux --no-mobdev2 --wifi \
        --port "$TUNNELD_PORT" -d
    log "Waiting for tunnel..."
    for i in $(seq 1 30); do
        if curl -sf "http://127.0.0.1:$TUNNELD_PORT/" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

# Check tunnel is connected to a device
TUNNELS=$(curl -sf "http://127.0.0.1:$TUNNELD_PORT/" 2>/dev/null)
if [ -z "$TUNNELS" ] || [ "$TUNNELS" = "{}" ]; then
    echo ""
    echo "ERROR: No device tunnel found."
    echo ""
    echo "Make sure:"
    echo "  1. Apple TV is on and connected to the same network"
    echo "  2. You've paired at least once:"
    echo "     - On Apple TV: Settings > Remotes and Devices > Remote App and Devices"
    echo "     - On this machine: sudo $PYMOBILEDEVICE3 remote pair"
    echo ""
    exit 1
fi

log "Tunnel active: $TUNNELS"

# --- Step 2: Sign the IPA ---
if [ ! -f "$UNSIGNED_IPA" ]; then
    echo "ERROR: IPA not found at $UNSIGNED_IPA"
    echo "Usage: $0 [path-to-unsigned-ipa]"
    exit 1
fi

log "Signing $UNSIGNED_IPA ..."
"$PLUMESIGN" sign \
    --package "$UNSIGNED_IPA" \
    --apple-id \
    -o "$SIGNED_IPA"
log "Signed IPA saved to $SIGNED_IPA"

# --- Step 3: Install ---
log "Installing to Apple TV..."
sudo "$PYMOBILEDEVICE3" apps install --tunnel "" "$SIGNED_IPA"
log "Done! Jellyflix is installed on your Apple TV."
