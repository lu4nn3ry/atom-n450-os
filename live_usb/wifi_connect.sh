#!/bin/sh
# Itautec W7020 - RTL8192SE + WPA2 + SSH. Works at boot (local.d) or manually: sh /media/*/setup.sh
LOG=/var/log/wifi_connect.log
log() { echo "[wifi] $*"; echo "[wifi] $*" >> "$LOG"; }

HOST_IP="__HOST_IP__"
HOST_PORT="__HOST_PORT__"
case "$HOST_IP" in __*) HOST_IP=192.168.0.16; HOST_PORT=9090;; esac

# 1. Ensure required packages (installed offline from the USB /apks repo)
need=""
command -v wpa_supplicant >/dev/null 2>&1 || need="$need wpa_supplicant"
command -v sshd           >/dev/null 2>&1 || [ -x /usr/sbin/sshd ] || need="$need openssh"
command -v iw             >/dev/null 2>&1 || need="$need iw"
if [ -n "$need" ]; then
    for r in /media/*/apks; do
        [ -d "$r" ] || continue
        log "Instalando:$need (repo $r)"
        apk add --no-network --allow-untrusted --repositories-file /dev/null -X "$r" $need && break
    done
fi
command -v wpa_supplicant >/dev/null 2>&1 || { log "ERRO: wpa_supplicant nao instalado"; exit 1; }

# 2. Driver with power saving disabled
mkdir -p /etc/modprobe.d
echo 'options rtl8192se ips=0 swlps=0 fwlps=0' > /etc/modprobe.d/rtl8192se.conf
for f in /media/*/firmware/rtlwifi/*.bin; do
    [ -f "$f" ] && [ ! -f "/lib/firmware/rtlwifi/$(basename "$f")" ] && { mkdir -p /lib/firmware/rtlwifi; cp "$f" /lib/firmware/rtlwifi/ 2>/dev/null; }
done
if ! ls /sys/class/net | grep -q '^wl'; then
    modprobe rtl8192se 2>/dev/null
    sleep 3
fi
rfkill unblock all 2>/dev/null || true

WLAN_IF=$(ls /sys/class/net | grep '^wl' | head -n 1)
[ -z "$WLAN_IF" ] && { log "ERRO: sem interface wireless. dmesg:"; dmesg | grep -i rtl | tail -n 10; exit 1; }
log "Interface: $WLAN_IF"

ip link set lo up
ip link set "$WLAN_IF" up
iw dev "$WLAN_IF" set power_save off 2>/dev/null || true

# 3. WPA2 association
mkdir -p /etc/wpa_supplicant
if [ ! -s /etc/wpa_supplicant/wpa_supplicant.conf ]; then
cat << 'EOF' > /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=/var/run/wpa_supplicant
update_config=1
country=BR

network={
    ssid="__SSID__"
    psk="__PSK__"
    proto=RSN
    key_mgmt=WPA-PSK
    pairwise=CCMP TKIP
    group=CCMP TKIP
    scan_ssid=1
}
EOF
fi

killall wpa_supplicant udhcpc 2>/dev/null
sleep 1
rm -rf /var/run/wpa_supplicant
wpa_supplicant -B -D nl80211,wext -i "$WLAN_IF" -c /etc/wpa_supplicant/wpa_supplicant.conf

CONNECTED=0
i=0
while [ $i -lt 30 ]; do
    i=$((i+1))
    STATE=$(wpa_cli -i "$WLAN_IF" status 2>/dev/null | sed -n 's/^wpa_state=//p')
    log "($i/30) wpa_state=$STATE"
    [ "$STATE" = "COMPLETED" ] && { CONNECTED=1; break; }
    sleep 1
done
if [ $CONNECTED -ne 1 ]; then
    log "ERRO: WPA2 nao autenticou. Redes visiveis:"
    wpa_cli -i "$WLAN_IF" scan_results 2>/dev/null | head -n 15
    exit 1
fi
log "Associado: $(wpa_cli -i "$WLAN_IF" status | sed -n 's/^ssid=//p')"

# 4. DHCP (with static fallback)
udhcpc -i "$WLAN_IF" -t 8 -T 3 -n -q -S
IP=$(ip -4 addr show "$WLAN_IF" | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}')
if [ -z "$IP" ]; then
    log "DHCP falhou; IP estatico 192.168.0.88"
    ip addr add 192.168.0.88/24 dev "$WLAN_IF"
    ip route replace default via 192.168.0.1 dev "$WLAN_IF"
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    IP=192.168.0.88
fi
ping -c 2 -W 2 192.168.0.1 >/dev/null 2>&1 && log "Gateway OK" || log "AVISO: gateway nao responde"

# 5. SSH (root password: atom)
echo "root:atom" | chpasswd 2>/dev/null
SSH_OK=0
if [ -x /usr/sbin/sshd ]; then
    ssh-keygen -A >/dev/null 2>&1
    rc-service sshd restart >/dev/null 2>&1 || /usr/sbin/sshd
    sleep 1
    netstat -tln 2>/dev/null | grep -q ':22 ' && SSH_OK=1
fi

# 6. Beacon to PC
wget -q -O /dev/null --post-data="{\"from\":\"ITAUTEC-W7020\",\"ip\":\"$IP\",\"ssh\":$SSH_OK,\"text\":\"Netbook online: $IP (ssh=$SSH_OK)\"}" "http://$HOST_IP:$HOST_PORT/msg" 2>/dev/null

echo "======================================================"
echo " IP DO NETBOOK: $IP"
[ $SSH_OK -eq 1 ] && echo " SSH OK: ssh root@$IP  (senha: atom)" || echo " SSH NAO SUBIU (veja $LOG)"
echo "======================================================"
