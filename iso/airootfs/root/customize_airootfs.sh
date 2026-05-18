#!/usr/bin/env bash
set -e

# Create live user
useradd -m -G wheel,audio,video,storage,optical,network,rfkill,tor -s /bin/fish liveuser
echo "liveuser:liveuser" | chpasswd
echo "root:root" | chpasswd

# Passwordless sudo for live session
cat > /etc/sudoers.d/liveuser <<'EOF'
liveuser ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/liveuser

# Enable autologin on TTY1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --noclear --autologin liveuser %I $TERM
EOF

# ── Install yay (pre-built release binary) ───────────────────────────────────
YAY_VER="12.4.2"
YAY_URL="https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz"
curl -fsSL "$YAY_URL" -o /tmp/yay.tar.gz
tar -xzf /tmp/yay.tar.gz -C /tmp
install -Dm755 "/tmp/yay_${YAY_VER}_x86_64/yay" /usr/bin/yay
rm -rf /tmp/yay.tar.gz "/tmp/yay_${YAY_VER}_x86_64"

# ── Install paru (pre-built release binary) ──────────────────────────────────
PARU_VER="2.0.4"
PARU_URL="https://github.com/Morganamilo/paru/releases/download/v${PARU_VER}/paru-v${PARU_VER}-x86_64.tar.zst"
curl -fsSL "$PARU_URL" -o /tmp/paru.tar.zst
tar --use-compress-program=unzstd -xf /tmp/paru.tar.zst -C /tmp
install -Dm755 /tmp/paru /usr/bin/paru
rm -f /tmp/paru.tar.zst /tmp/paru

# ── Enable services ──────────────────────────────────────────────────────────
systemctl enable seatd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable dnscrypt-proxy
systemctl enable nftables
systemctl enable tailscaled
systemctl enable edex-setup-live

# Set up Hyprland autostart for liveuser
mkdir -p /home/liveuser/.config/hypr
cp /etc/skel/.config/hypr/hyprland.conf /home/liveuser/.config/hypr/hyprland.conf

# Set up eDEX-DE autostart via fish config
mkdir -p /home/liveuser/.config/fish
cat > /home/liveuser/.config/fish/config.fish <<'EOF'
# eDEX-OS live environment fish config
if status is-login
    if test -z "$DISPLAY" -a "$XDG_VTNR" = "1"
        exec Hyprland
    end
end
EOF

chown -R liveuser:liveuser /home/liveuser/.config

# Initialize xdg dirs
sudo -u liveuser xdg-user-dirs-update 2>/dev/null || true

echo "==> customize_airootfs.sh complete"
