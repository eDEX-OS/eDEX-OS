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

# Enable services
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
