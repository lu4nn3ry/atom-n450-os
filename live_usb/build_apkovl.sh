#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$DIR/.."

# Load configuration from .env
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
elif [ -f "$ROOT_DIR/.env.example" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env.example" | xargs)
fi

WIFI_SSID="${WIFI_SSID:-WIFI_NETWORK}"
WIFI_PSK="${WIFI_PSK:-WIFI_PASSWORD}"
ROOT_PASS="${ROOT_PASS:-atom}"
TARGET_HOST_IP="${TARGET_HOST_IP:-192.168.0.16}"
TARGET_HOST_PORT="${TARGET_HOST_PORT:-9090}"

BUILD_DIR="/tmp/itautec_apkovl_build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/etc/wpa_supplicant"
mkdir -p "$BUILD_DIR/etc/network"
mkdir -p "$BUILD_DIR/etc/local.d"
mkdir -p "$BUILD_DIR/etc/runlevels/default"
mkdir -p "$BUILD_DIR/etc/runlevels/boot"
mkdir -p "$BUILD_DIR/etc/ssh"
mkdir -p "$BUILD_DIR/etc/apk"

# Hostname
echo "itautec-w7020" > "$BUILD_DIR/etc/hostname"
cat << 'EOF' > "$BUILD_DIR/etc/hosts"
127.0.0.1   localhost localhost.localdomain itautec-w7020
::1         localhost localhost.localdomain
EOF

# Generate password hash for root
ROOT_HASH=$(openssl passwd -6 "$ROOT_PASS")

cat << EOF > "$BUILD_DIR/etc/shadow"
root:$ROOT_HASH:19500:0:99999:7:::
bin:!19500:0:99999:7:::
daemon:!19500:0:99999:7:::
sshd:!19500:0:99999:7:::
nobody:!19500:0:99999:7:::
EOF
chmod 600 "$BUILD_DIR/etc/shadow"

# SSH config
cat << 'EOF' > "$BUILD_DIR/etc/ssh/sshd_config"
Port 22
PermitRootLogin yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
PrintMotd yes
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# Generate wpa_supplicant.conf
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

# Interfaces
cat << 'EOF' > "$BUILD_DIR/etc/network/interfaces"
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

# Generate beacon script
cat << EOF > "$BUILD_DIR/etc/local.d/beacon.start"
#!/bin/sh
TARGET_IP="$TARGET_HOST_IP"
TARGET_PORT="$TARGET_HOST_PORT"

echo "[AGENT] Itautec W7020 initializing network and services..."
ip link set lo up

sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true

if ip link show wlan0 >/dev/null 2>&1; then
    ip link set wlan0 up
    wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true
    udhcpc -b -i wlan0 2>/dev/null || true
fi

if ip link show eth0 >/dev/null 2>&1; then
    ip link set eth0 up
    udhcpc -b -i eth0 2>/dev/null || true
fi

rc-service sshd restart 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true

for i in \$(seq 1 30); do
    CURRENT_IP=\$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    if [ -n "\$CURRENT_IP" ]; then
        break
    fi
    sleep 1
done

if [ -z "\$CURRENT_IP" ]; then
    echo "[AGENT] No IP acquired yet."
    exit 1
fi

echo "[AGENT] Network active with IP: \$CURRENT_IP"
CPU_INFO=\$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
MEM_INFO=\$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print \$2/1024 " MB"}')
UPTIME=\$(uptime | cut -d, -f1)

PAYLOAD=\$(cat <<EOP
{
  "from": "ITAUTEC-W7020",
  "ip": "\$CURRENT_IP",
  "cpu": "\$CPU_INFO",
  "memory": "\$MEM_INFO",
  "uptime": "\$UPTIME",
  "text": "Netbook Itautec W7020 Online! IP: \$CURRENT_IP, CPU: \$CPU_INFO, RAM: \$MEM_INFO, SSH ativo (porta 22, root/$ROOT_PASS)"
}
EOP
)

wget -q --header="Content-Type: application/json" --post-data="\$PAYLOAD" "http://\${TARGET_IP}:\${TARGET_PORT}/msg" -O /dev/null 2>/dev/null || \\
curl -s -X POST -H "Content-Type: application/json" -d "\$PAYLOAD" "http://\${TARGET_IP}:\${TARGET_PORT}/msg" 2>/dev/null || true

echo "[AGENT] Beacon broadcasted successfully."
EOF
chmod 755 "$BUILD_DIR/etc/local.d/beacon.start"

# Services to start automatically
ln -sf /etc/init.d/local "$BUILD_DIR/etc/runlevels/default/local"
ln -sf /etc/init.d/sshd "$BUILD_DIR/etc/runlevels/default/sshd"
ln -sf /etc/init.d/networking "$BUILD_DIR/etc/runlevels/boot/networking"

# Packages
cat << 'EOF' > "$BUILD_DIR/etc/apk/world"
alpine-base
openssh
wpa_supplicant
wireless-tools
pciutils
usbutils
kexec-tools
EOF

# Pack into tar.gz
cd "$BUILD_DIR"
tar -czf "$DIR/itautec-w7020.apkovl.tar.gz" etc/

echo "Generated: $DIR/itautec-w7020.apkovl.tar.gz"
