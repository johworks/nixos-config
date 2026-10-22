#!/bin/sh
# Runs ON the Archer AX1450. The NUC sends PSK_B64 and public settings as
# shell assignments over stdin before this script, never in process argv.
set -eu
umask 077
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

work=$(mktemp -d /tmp/ax1450-reconcile.XXXXXX)
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM

psk=$(printf '%s' "$PSK_B64" | /usr/bin/openssl base64 -d -A) || fail "cannot decode Wi-Fi password"
[ "${#psk}" -ge 8 ] && [ "${#psk}" -le 64 ] || fail "invalid Wi-Fi password length"
case "$psk" in
  *'
'*) fail "Wi-Fi password must be a single line" ;;
esac

# Decode into a private temporary file, check the pin, then install and run.
# Never execute the loader or flash contents before validating the hash.
/usr/bin/nvrammanager -r "$work/payload.b64" -p router-config >/dev/null || fail "cannot read bootstrap partition"
/usr/bin/openssl base64 -d -A -in "$work/payload.b64" -out "$work/bootstrap.sh" || fail "cannot decode bootstrap"
sha=$(sha256sum "$work/bootstrap.sh")
[ "${sha%% *}" = "$EXPECTED_SHA" ] || fail "bootstrap sha mismatch"
mkdir -p /etc/ax1450
chmod 700 /etc/ax1450
cp "$work/bootstrap.sh" /etc/ax1450/bootstrap.sh
chmod 600 /etc/ax1450/bootstrap.sh
sh /etc/ax1450/bootstrap.sh || fail "bootstrap failed"
pid=$(cat /tmp/ax1450-root.pid 2>/dev/null || true)
[ -n "$pid" ] && [ -d "/proc/$pid" ] || fail "listener did not start"

# TP-Link rejects `uci set` for day. Own this single-section scheduler
# file directly; boot restores vendor indentation and UCI may have stale
# deltas that would otherwise shadow the repaired file.
rm -f /tmp/.uci/autoreboot
if [ "$(uci -q get autoreboot.reboot.day || true)" != "$DAY_VALUE" ] ||
   [ "$(uci -q get autoreboot.reboot.enable || true)" != "on" ] ||
   [ "$(uci -q get autoreboot.reboot.cycle || true)" != "week" ] ||
   [ "$(uci -q get autoreboot.reboot.time || true)" != "03:11" ]; then
  touch /etc/ax1450/save-pending
  {
    printf "config default 'reboot'\n"
    printf "  option enable 'on'\n  option cycle 'week'\n  option time '03:11'\n"
    printf "  option day '%s'\n" "$DAY_VALUE"
  } > "$work/autoreboot"
  cp "$work/autoreboot" /etc/config/autoreboot
  [ "$(uci -q get autoreboot.reboot.day)" = "$DAY_VALUE" ] || fail "cannot rewrite autoreboot day"
  [ "$(uci -q get autoreboot.reboot.enable)" = "on" ] || fail "cannot enable autoreboot"
  [ "$(uci -q get autoreboot.reboot.cycle)" = "week" ] || fail "cannot set autoreboot cycle"
  [ "$(uci -q get autoreboot.reboot.time)" = "03:11" ] || fail "cannot set autoreboot time"
  echo "REPAIRED: autoreboot settings"
fi

# A bare vendor reboot line also contains dut_auto_reboot. Check the entire
# line, including the loader and comment that suppresses the actual reboot.
expected_cron="11 3 * * $DAY_VALUE sh /usr/sbin/dut_auto_reboot"
cron=$(grep -F dut_auto_reboot /etc/crontabs/root || true)
if [ "$cron" != "$expected_cron" ]; then
  /etc/init.d/auto-reboot start || fail "cannot regenerate scheduler cron"
  cron=$(grep -F dut_auto_reboot /etc/crontabs/root || true)
  [ "$cron" = "$expected_cron" ] || fail "scheduler cron mismatch"
  echo "REPAIRED: scheduler cron"
fi

ipt() { /usr/sbin/iptables -C INPUT "$@" >/dev/null 2>&1 || /usr/sbin/iptables -I INPUT 1 "$@"; }
ipt -p tcp --dport "$PORT" -j DROP
ipt -p tcp --dport "$PORT" -s "$MANAGER_IP" -j ACCEPT
if ! grep -qF '*/30 * * * * /bin/sh /etc/ax1450/bootstrap.sh # ax1450-selfheal' /etc/crontabs/root; then
  printf '%s\n' '*/30 * * * * /bin/sh /etc/ax1450/bootstrap.sh # ax1450-selfheal' >> /etc/crontabs/root
fi

wifi_config_matches() {
  for sec in wl03 wl13; do
    [ "$(uci -q get wireless.$sec.ssid)" = "$SSID" ] || return 1
    [ "$(uci -q get wireless.$sec.psk_key)" = "$psk" ] || return 1
  done
}

wifi_runtime_matches() {
  for sec in wl03 wl13; do
    iface=$(uci -q get wireless.$sec.ifname) || return 1
    # The vendor apply path writes Broadcom runtime NVRAM before bringing
    # up each BSS. UCI alone only tells us the desired settings were stored.
    [ "$(nvram get "${iface}_ssid")" = "$SSID" ] || return 1
    [ "$(nvram get "${iface}_wpa_psk")" = "$psk" ] || return 1
    [ "$(wl -i "$iface" bss)" = "up" ] || return 1
  done
}

uci_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

if ! wifi_config_matches || ! wifi_runtime_matches || [ -e /etc/ax1450/wifi-pending ]; then
  # Keep retrying commit/apply after a failed run, even when UCI already
  # contains the desired values. Mark flash saves separately so a failed
  # save can be retried without another Wi-Fi interruption.
  touch /etc/ax1450/wifi-pending /etc/ax1450/save-pending
  ssid_quoted=$(uci_quote "$SSID")
  psk_quoted=$(uci_quote "$psk")
  uci -q batch <<BATCH || fail "cannot set Wi-Fi settings"
set wireless.wl03.ssid=$ssid_quoted
set wireless.wl13.ssid=$ssid_quoted
set wireless.wl03.psk_key=$psk_quoted
set wireless.wl13.psk_key=$psk_quoted
BATCH
  uci -q commit wireless || fail "cannot commit Wi-Fi settings"
  wifi_config_matches || fail "Wi-Fi settings did not commit"
  # Vendor output can contain credentials; keep it private and report only
  # the failed operation. The runtime checks also catch silent apply errors.
  wifi reload > "$work/wifi-reload.log" 2>&1 || fail "Wi-Fi reload failed"
  wifi_runtime_matches || fail "Wi-Fi runtime settings did not apply"
  rm -f /etc/ax1450/wifi-pending
  echo "APPLIED: Wi-Fi settings"
fi

if [ -e /etc/ax1450/save-pending ]; then
  /usr/bin/lua -e 'require("luci.sys.config").saveconfig()' > "$work/saveconfig.log" 2>&1 || fail "cannot persist settings to flash"
  rm -f /etc/ax1450/save-pending
  echo "SAVED: settings persisted"
fi

echo "OK: persistence verified, Wi-Fi converged"
