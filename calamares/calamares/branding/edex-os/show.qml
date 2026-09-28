/* eDEX-OS installer slideshow */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function slideText(title, lines) {
        return { title: title, lines: lines }
    }

    Repeater {
        model: [
            { title: "Welcome to eDEX-OS", lines: ["privacy-focused  //  performance-tuned  //  sci-fi shell", "CachyOS kernel and x86-64-v3/v4 optimised packages"] },
            { title: "eDEX-DE", lines: ["A Rust + wgpu shell drawn on Hyprland", "terminal, file browser, dashboard, on-screen keyboard", "SUPER+Space launcher · SUPER+, settings · SUPER+P privacy"] },
            { title: "Privacy built in", lines: ["Tor: SOCKS5 or fail-closed transparent mode", "Tailscale mesh VPN with exit nodes", "WireGuard and OpenVPN through NetworkManager", "dnscrypt-proxy with DNSSEC, deny-inbound firewall"] },
            { title: "After installation", lines: ["Log in through the eDEX greeter", "Settings → Security to enrol a fingerprint", "yay / paru for the AUR"] }
        ]
        Slide {
            anchors.fill: parent
            Image { anchors.fill: parent; source: "/usr/share/edex-os/calamares/slide-bg.png"; fillMode: Image.PreserveAspectCrop }
            Column {
                anchors.centerIn: parent
                spacing: 18
                Text { text: modelData.title; color: "#00d4ff"; font.pixelSize: 36; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Repeater {
                    model: modelData.lines
                    Text { text: modelData; color: "#c8e6ff"; opacity: 0.85; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
        }
    }

    function onActivate() { }
    function onLeave() { }
}
