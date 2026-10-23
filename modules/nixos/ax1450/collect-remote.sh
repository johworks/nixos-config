#!/bin/sh
# Read-only snapshot. Never commit config, reload Wi-Fi or write AP flash.
set -eu
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

printf '@uptime\n'
cat /proc/uptime
printf '@load\n'
cat /proc/loadavg
printf '@memory\n'
cat /proc/meminfo
printf '@netdev\n'
cat /proc/net/dev

for band in 2g 5g; do
  case "$band" in 2g) dev=wl1; iface=wl1.1 ;; 5g) dev=wl0; iface=wl0.1 ;; esac
  printf '@bss %s\n' "$band"
  bss=$(wl -i "$iface" bss 2>/dev/null) || bss=unavailable
  printf '%s\n' "$bss"
  [ "$bss" = up ] || continue

  printf '@clients %s\n' "$band"
  if assoc=$(wl -i "$iface" assoclist 2>/dev/null); then
    printf '%s\n' "$assoc" | awk '$1 == "assoclist" {n++} END {print n+0}'
    printf '@rssi %s\n' "$band"
    # Bound work even if a future firmware raises the association limit.
    printf '%s\n' "$assoc" | head -n 128 | while read -r label mac; do
      [ "$label" = assoclist ] || continue
      [ "${#mac}" -eq 17 ] || continue
      case "$mac" in *[!0-9A-Fa-f:]*) continue ;; esac
      wl -i "$iface" rssi "$mac" 2>/dev/null || true
    done
  else
    printf 'unavailable\n'
  fi

  printf '@chanspec %s\n' "$band"
  wl -i "$dev" chanspec 2>/dev/null || true
  printf '@noise %s\n' "$band"
  wl -i "$dev" noise 2>/dev/null || true
  printf '@counters %s\n' "$band"
  wl -i "$dev" counters 2>/dev/null || true
done
