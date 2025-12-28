#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/install-vm.sh [--disk /dev/vda] [--host vm] [--repo /path/to/repo] [--yes]

Partitions the target disk for UEFI, installs NixOS using the flake host,
then reboots. Defaults are VM-oriented and can be extended later.
USAGE
}

DISK="/dev/vda"
HOST="vm"
REPO_DIR=""
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk)
      DISK="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$REPO_DIR" ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root (sudo)." >&2
  exit 1
fi

required_cmds=(parted mkfs.vfat mkfs.ext4 mount umount nixos-generate-config nixos-install install cp rm reboot)
missing_cmds=()
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_cmds+=("$cmd")
  fi
done
if [[ ${#missing_cmds[@]} -ne 0 ]]; then
  echo "Missing required commands: ${missing_cmds[*]}" >&2
  echo "Make sure you're running from the NixOS installer environment." >&2
  exit 1
fi

if [[ ! -d "$REPO_DIR/hosts/$HOST" ]]; then
  echo "Host directory not found: $REPO_DIR/hosts/$HOST" >&2
  exit 1
fi

if [[ ! -b "$DISK" ]]; then
  echo "Disk not found: $DISK" >&2
  exit 1
fi

if [[ $ASSUME_YES -ne 1 ]]; then
  echo "This will ERASE $DISK and install NixOS using host '$HOST'."
  read -r -p "Type the disk path to continue: " confirm
  if [[ "$confirm" != "$DISK" ]]; then
    echo "Aborted." >&2
    exit 1
  fi
fi

if [[ "$DISK" =~ [0-9]$ ]]; then
  PART_BOOT="${DISK}p1"
  PART_ROOT="${DISK}p2"
else
  PART_BOOT="${DISK}1"
  PART_ROOT="${DISK}2"
fi

umount -R /mnt >/dev/null 2>&1 || true

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 100%

mkfs.vfat -F32 -n boot "$PART_BOOT"
mkfs.ext4 -F -L nixos "$PART_ROOT"

mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot
mount "$PART_BOOT" /mnt/boot

nixos-generate-config --root /mnt

install -m 0644 \
  /mnt/etc/nixos/hardware-configuration.nix \
  "$REPO_DIR/hosts/$HOST/hardware-configuration.nix"

rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
cp -a "$REPO_DIR/." /mnt/etc/nixos/

nixos-install --flake "$REPO_DIR#$HOST"
reboot
