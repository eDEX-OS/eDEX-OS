#!/usr/bin/env bash
# Behavioural test of the Tor modes; run as root on a live eDEX-OS system (VM or hardware).
# Without network it still proves the fail-closed property; with network it checks Tor exit.
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
pass=0; failn=0
ok() { echo "PASS: $*"; pass=$((pass+1)); }
ko() { echo "FAIL: $*"; failn=$((failn+1)); }

edex-tor-mode off >/dev/null
[ "$(cat /run/edex-tor-mode)" = off ] && ok "mode off persisted" || ko "mode off"
nft list tables | grep -q 'inet edex-tor' && ko "transparent table present in off mode" || ok "no transparent table in off mode"

edex-tor-mode socks5 >/dev/null && ok "socks5 mode switch" || ko "socks5 mode switch"
sleep 2
ss -ltn | grep -q ':9050 ' && ok "tor listening on 9050" || ko "tor not listening on 9050"

# Transparent mode: load the table directly (no bootstrap wait) and verify the policy.
uid=$(id -u tor)
sed -e "s/@TOR_UID@/$uid/" -e 's/^\(\s*\)# @TAILSCALE@ /\1/' /usr/share/edex-os/tor/transparent.nft | nft -f - && ok "transparent table loads" || ko "transparent table fails to load"
nft list chain inet edex-tor filter_output | grep -q 'policy drop' && ok "output policy is drop (fail closed)" || ko "output policy not drop"
# A plain UDP packet to the internet must be dropped, not sent.
if timeout 3 bash -c 'echo x > /dev/udp/9.9.9.9/9999' 2>/dev/null; then
    ko "UDP to the internet was not blocked"
else
    ok "UDP to the internet blocked"
fi
# A TCP connection must be redirected to the TransPort (9040) rather than leaving directly.
if nft list chain inet edex-tor nat_output | grep -q 'redirect to :9040'; then ok "TCP redirect rule present"; else ko "TCP redirect rule missing"; fi
nft delete table inet edex-tor

if EDEX_TOR_BOOTSTRAP_TIMEOUT=240 edex-tor-mode transparent >/dev/null 2>&1; then
    ok "transparent mode reached bootstrap"
    if curl -s --max-time 30 https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
        ok "check.torproject.org sees Tor"
    else
        ko "traffic does not exit through Tor"
    fi
else
    echo "SKIP: transparent bootstrap (no network or timeout); rollback state: $(cat /run/edex-tor-mode)"
    [ "$(cat /run/edex-tor-mode)" = socks5 ] && ok "rolled back to socks5 after failed bootstrap" || ko "no rollback"
fi
edex-tor-mode off >/dev/null
echo "passed=$pass failed=$failn"
[ "$failn" -eq 0 ]
