#!/bin/sh
# Runs ON the Archer AX1450, fed via stdin by the NUC reconcile wrapper.
# argv: 1=PSK_B64 2=SSID 3=DAY_VALUE 4=EXPECTED_SHA 5=SSH_PORT 6=MANAGER_IP
#
# Vendor scripts expect the full PATH; non-interactive SSH gives /usr/bin:/bin.
set -u
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
PSK_B64=$1
SSID=$2
DAY_VALUE=$3
EXPECTED_SHA=$4
PORT=$5
MANAGER_IP=$6

fail() {
  echo "FAIL: $1"
  exit 1
}

# --- Persisted scheduler injection --------------------------------------
day=$(uci -q get autoreboot.reboot.day)
if [ "$day" != "$DAY_VALUE" ]; then
  # TP-Link's uci CLI rejects day sets and a failed commit leaves stale
  # deltas in /tmp/.uci that shadow the file, so rewrite the file directly.
  rm -f /tmp/.uci/autoreboot
  sed -i "s@^\(option[[:space:]]*\)day .*@\1day '$DAY_VALUE'@" /etc/config/autoreboot
  grep -q "day '$DAY_VALUE'" /etc/config/autoreboot || fail "cannot rewrite autoreboot day"
  uci -q set autoreboot.reboot.enable=on
  uci -q commit autoreboot
  /usr/bin/lua -e 'require("luci.sys.config").saveconfig()'
  /etc/init.d/auto-reboot start
  echo "REPAIRED: autoreboot injection"
fi
[ "$(uci -q get autoreboot.reboot.enable)" = "on" ] || fail "autoreboot disabled"
grep -q dut_auto_reboot /etc/crontabs/root || fail "daily cron line missing"

# --- Root channel --------------------------------------------------------
# Re-run the loader from the live day value: it re-materializes
# /etc/ax1450/bootstrap.sh from the router-config partition (so the sha
# check below validates the flash payload) and exits early when the
# listener is already up.
loader=$(uci -q get autoreboot.reboot.day | sed 's/^\* //; s/ #$//')
sh -c "$loader" || fail "loader failed"
sha=$(sha256sum /etc/ax1450/bootstrap.sh 2>/dev/null | cut -d' ' -f1)
[ "$sha" = "$EXPECTED_SHA" ] || fail "bootstrap sha mismatch: $sha"

pid=$(cat /tmp/ax1450-root.pid 2>/dev/null)
if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
  sh /etc/ax1450/bootstrap.sh
  sleep 1
  pid=$(cat /tmp/ax1450-root.pid 2>/dev/null)
  { [ -n "$pid" ] && [ -d "/proc/$pid" ]; } || fail "listener did not start"
fi

ipt() { /usr/sbin/iptables -C INPUT "$@" >/dev/null 2>&1 || /usr/sbin/iptables -I INPUT 1 "$@"; }
ipt -p tcp --dport "$PORT" -j DROP
ipt -p tcp --dport "$PORT" -s "$MANAGER_IP" -j ACCEPT
grep -q ax1450-selfheal /etc/crontabs/root 2>/dev/null || \
  printf '%s\n' '*/30 * * * * /bin/sh /etc/ax1450/bootstrap.sh # ax1450-selfheal' >> /etc/crontabs/root

# --- Wi-Fi: converge the main SSID/PSK on both bands ---------------------
psk=$(printf '%s' "$PSK_B64" | /usr/bin/openssl base64 -d -A)
changed=""
for sec in wl03 wl13; do
  [ "$(uci -q get wireless.$sec.ssid)" = "$SSID" ] || { uci set "wireless.$sec.ssid=$SSID"; changed=1; }
  [ "$(uci -q get wireless.$sec.psk_key)" = "$psk" ] || { uci set "wireless.$sec.psk_key=$psk"; changed=1; }
done
if [ -n "$changed" ]; then
  uci commit wireless
  wifi reload
  /usr/bin/lua -e 'require("luci.sys.config").saveconfig()'
  [ "$(uci -q get wireless.wl03.ssid)" = "$SSID" ] || fail "5G SSID not applied"
  [ "$(uci -q get wireless.wl13.ssid)" = "$SSID" ] || fail "2.4G SSID not applied"
  echo "APPLIED: Wi-Fi settings"
fi

echo "OK: persistence verified, Wi-Fi converged"
