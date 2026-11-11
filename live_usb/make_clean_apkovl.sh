#!/bin/bash
# Builds localhost.apkovl.tar.gz for the Itautec W7020 (RTL8192SE, WPA2).
# IMPORTANT: only ONE *.apkovl.tar.gz may exist on the USB root, otherwise
# Alpine's initramfs ignores all of them.
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$DIR/.."
FW_DIR="${FW_DIR:-/mnt/e/firmware/rtlwifi}"

# Load credentials from .env
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | tr -d '\r' | xargs)
fi

WIFI_SSID="${WIFI_SSID:?set WIFI_SSID in .env}"
WIFI_PSK="${WIFI_PSK:?set WIFI_PSK in .env}"
TARGET_HOST_IP="${TARGET_HOST_IP:-192.168.0.16}"
TARGET_HOST_PORT="${TARGET_HOST_PORT:-9090}"

BUILD_DIR="/tmp/apkovl_root"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/etc/{wpa_supplicant,network,local.d,ssh,apk,modprobe.d}
mkdir -p "$BUILD_DIR"/etc/runlevels/{sysinit,boot,default}
mkdir -p "$BUILD_DIR/lib/firmware/rtlwifi"

# Keep Alpine default boot services (modloop, hwdrivers, mdev...)
touch "$BUILD_DIR/etc/.default_boot_services"

# Packages installed from the USB's own /apks repo at boot (offline)
cat << 'EOF' > "$BUILD_DIR/etc/apk/world"
alpine-base
openssh
wpa_supplicant
iw
EOF

[ -d "$FW_DIR" ] && cp "$FW_DIR"/* "$BUILD_DIR/lib/firmware/rtlwifi/"

echo 'itautec' > "$BUILD_DIR/etc/hostname"
cat << 'EOF' > "$BUILD_DIR/etc/hosts"
127.0.0.1   itautec localhost localhost.localdomain
::1         localhost localhost.localdomain
EOF

echo 'rtl8192se' > "$BUILD_DIR/etc/modules"

# RTL8192SE power saving drops frames right after association (DHCP never answered)
echo 'options rtl8192se ips=0 swlps=0 fwlps=0' > "$BUILD_DIR/etc/modprobe.d/rtl8192se.conf"

cat << 'EOF' > "$BUILD_DIR/etc/ssh/sshd_config"
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
KbdInteractiveAuthentication no
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# WPA2-PSK (RSN) config
cat << EOF > "$BUILD_DIR/etc/wpa_supplicant/wpa_supplicant.conf"
ctrl_interface=/var/run/wpa_supplicant
update_config=1
country=BR

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PSK"
    proto=RSN
    key_mgmt=WPA-PSK
    pairwise=CCMP TKIP
    group=CCMP TKIP
    scan_ssid=1
}
EOF
chmod 600 "$BUILD_DIR/etc/wpa_supplicant/wpa_supplicant.conf"

cat << 'EOF' > "$BUILD_DIR/etc/network/interfaces"
auto lo
iface lo inet loopback
EOF

# Shared connect script (also copied to USB root as setup.sh)
cp "$DIR/wifi_connect.sh" "$BUILD_DIR/etc/local.d/beacon.start"
sed -i "s|__HOST_IP__|$TARGET_HOST_IP|; s|__HOST_PORT__|$TARGET_HOST_PORT|; s|__SSID__|$WIFI_SSID|; s|__PSK__|$WIFI_PSK|" "$BUILD_DIR/etc/local.d/beacon.start"
cp "$BUILD_DIR/etc/local.d/beacon.start" "$DIR/setup.generated.sh"
chmod 755 "$BUILD_DIR/etc/local.d/beacon.start"

ln -sf /etc/init.d/devfs      "$BUILD_DIR/etc/runlevels/sysinit/devfs"
ln -sf /etc/init.d/modloop    "$BUILD_DIR/etc/runlevels/sysinit/modloop"
ln -sf /etc/init.d/mdev       "$BUILD_DIR/etc/runlevels/sysinit/mdev"
ln -sf /etc/init.d/hwdrivers  "$BUILD_DIR/etc/runlevels/sysinit/hwdrivers"
ln -sf /etc/init.d/modules    "$BUILD_DIR/etc/runlevels/boot/modules"
ln -sf /etc/init.d/hostname   "$BUILD_DIR/etc/runlevels/boot/hostname"
ln -sf /etc/init.d/networking "$BUILD_DIR/etc/runlevels/boot/networking"
ln -sf /etc/init.d/local      "$BUILD_DIR/etc/runlevels/default/local"

cd "$BUILD_DIR"
tar --owner=0 --group=0 -czf "$DIR/localhost.apkovl.tar.gz" etc/ lib/
rm -f "$DIR/itautec-w7020.apkovl.tar.gz"
echo "OK: $DIR/localhost.apkovl.tar.gz"
