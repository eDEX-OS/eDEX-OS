/* eDEX-OS Calamares Slideshow */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide()
    }
    Timer {
        id: advanceTimer
        interval: 5000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#000000" }
        Column {
            anchors.centerIn: parent; spacing: 20
            Text { text: "Welcome to eDEX-OS"; color: "#00e5ff"; font.pixelSize: 36; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Privacy-focused • Performance-tuned • Sci-fi aesthetic"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#000000" }
        Column {
            anchors.centerIn: parent; spacing: 16
            Text { text: "Privacy Built In"; color: "#00e5ff"; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Tor (SOCKS5 + transparent proxy)"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Tailscale mesh VPN"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "WireGuard & OpenVPN via NetworkManager"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "dnscrypt-proxy DNS-over-HTTPS with DNSSEC"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#000000" }
        Column {
            anchors.centerIn: parent; spacing: 16
            Text { text: "eDEX-DE Desktop"; color: "#00e5ff"; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Sci-fi Hyprland interface built with Tauri + Preact"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Press Ctrl+Shift+P to open the Privacy Control Panel"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#000000" }
        Column {
            anchors.centerIn: parent; spacing: 16
            Text { text: "CachyOS Performance"; color: "#00e5ff"; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "linux-cachyos kernel with BORE/EEVDF scheduler"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "x86-64-v3/v4 CPU-optimized packages"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Both yay and paru AUR helpers included"; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#000000" }
        Column {
            anchors.centerIn: parent; spacing: 16
            Text { text: "Getting Started"; color: "#00e5ff"; font.pixelSize: 32; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "Your system is almost ready."; color: "#00e5ff88"; font.pixelSize: 20; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: "After install, press Ctrl+Shift+P for Privacy Control."; color: "#00e5ff88"; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
