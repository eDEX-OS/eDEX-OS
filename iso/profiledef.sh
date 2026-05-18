#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="eDEX-OS"
iso_label="EDEX_OS_$(date +%Y%m)"
iso_publisher="eDEX-OS Project <https://github.com/eDEX-OS>"
iso_application="eDEX-OS Linux"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/bin/edex-tor-mode"]="0:0:755"
  ["/usr/bin/edex-setup-live"]="0:0:755"
)
