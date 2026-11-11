#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$DIR/.."
FW_DIR="/mnt/d/research_moto_e32/firmware_rtl"

# Load credentials from .env
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

WIFI_SSID="${WIFI_SSID:-LNET}"
WIFI_PSK="${WIFI_PSK:-Lolip0p!}"
ROOT_PASS="${ROOT_PASS:-atom}"
TARGET_HOST_IP="${TARGET_HOST_IP:-192.168.0.16}"
TARGET_HOST_PORT="${TARGET_HOST_PORT:-9090}"

BUILD_DIR="/tmp/apkovl_root"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/etc/wpa_supplicant"
mkdir -p "$BUILD_DIR/etc/network"
mkdir -p "$BUILD_DIR/etc/local.d"
mkdir -p "$BUILD_DIR/etc/runlevels/default"
mkdir -p "$BUILD_DIR/etc/runlevels/boot"
mkdir -p "$BUILD_DIR/etc/ssh"
mkdir -p "$BUILD_DIR/etc/apk"
mkdir -p "$BUILD_DIR/lib/firmware/rtlwifi"

# Copy firmware files
if [ -d "$FW_DIR" ]; then
    cp "$FW_DIR"/* "$BUILD_DIR/lib/firmware/rtlwifi/"
fi

echo 'localhost' > "$BUILD_DIR/etc/hostname"
cat << 'EOF' > "$BUILD_DIR/etc/hosts"
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain
EOF

# Password hash for root: atom
cat << 'EOF' > "$BUILD_DIR/etc/shadow"
root:$6$hprmU5/LnCORVKH7$ip5.hv2kvmaMteDypnNjINe.k9Nuj6MxqId1eOnvTw6FFKcylPTXCjeC62mi18pRumoCoB8VDvbXqZVt6VPSj.:19500:0:99999:7:::
bin:!19500:0:99999:7:::
daemon:!19500:0:99999:7:::
sshd:!19500:0:99999:7:::
nobody:!19500:0:99999:7:::
EOF
chmod 600 "$BUILD_DIR/etc/shadow"

# Modules to auto-load on boot
cat << 'EOF' > "$BUILD_DIR/etc/modules"
rtl8192se
EOF

cat << 'EOF' > "$BUILD_DIR/etc/ssh/sshd_config"
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
ChallengeResponseAuthentication no
PrintMotd yes
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# Wi-Fi config
cat << EOF > "$BUILD_DIR/etc/wpa_supplicant/wpa_supplicant.conf"
ctrl_interface=/var/run/wpa_supplicant
update_config=1
country=BR

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PSK"
    key_mgmt=WPA-PSK
    priority=1
}
EOF
chmod 600 "$BUILD_DIR/etc/wpa_supplicant/wpa_supplicant.conf"

cat << 'EOF' > "$BUILD_DIR/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

cat << EOF > "$BUILD_DIR/etc/local.d/beacon.start"
#!/bin/sh
echo '[AGENT] Subindo modulo rtl8192se e rede...'
modprobe rtl8192se 2>/dev/null || true
sleep 1

ip link set lo up
ip link set wlan0 up 2>/dev/null || true
ip link set eth0 up 2>/dev/null || true

killall wpa_supplicant 2>/dev/null || true
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true
udhcpc -b -i wlan0 2>/dev/null || true
udhcpc -b -i eth0 2>/dev/null || true

/etc/init.d/sshd restart 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true

for i in \$(seq 1 25); do
    CURRENT_IP=\$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    if [ -n "\$CURRENT_IP" ]; then
        break
    fi
    sleep 1
done

if [ -n "\$CURRENT_IP" ]; then
    PAYLOAD="{\"from\":\"ITAUTEC-W7020\",\"ip\":\"\$CURRENT_IP\",\"text\":\"Netbook Conectado! IP: \$CURRENT_IP\"}"
    wget -q --post-data="\$PAYLOAD" "http://$TARGET_HOST_IP:$TARGET_HOST_PORT/msg" -O /dev/null 2>/dev/null || true
fi
EOF
chmod 755 "$BUILD_DIR/etc/local.d/beacon.start"

ln -sf /etc/init.d/local "$BUILD_DIR/etc/runlevels/default/local"
ln -sf /etc/init.d/sshd "$BUILD_DIR/etc/runlevels/default/sshd"
ln -sf /etc/init.d/networking "$BUILD_DIR/etc/runlevels/boot/networking"

cd "$BUILD_DIR"
tar --owner=0 --group=0 -czf "$DIR/localhost.apkovl.tar.gz" etc/ lib/
cp "$DIR/localhost.apkovl.tar.gz" "$DIR/itautec-w7020.apkovl.tar.gz"

echo "Apkovl successfully generated with RTL8192SE firmware and modules!"
