# Privacy stack

| Component | Configuration | Notes |
|---|---|---|
| Tor | `/etc/edex-os/torrc` (+ `/etc/tor/torrc.d/`), `tor.service.d/edex.conf` | control port 9051 with a group-readable cookie in `/run/tor`; users in group `tor` can read bootstrap state and send NEWNYM |
| Tor modes | `/usr/bin/edex-tor-mode`, `edex-tor-mode.service`, `/usr/share/edex-os/tor/transparent.nft` | state in `/var/lib/edex-os/tor-mode` and `/run/edex-tor-mode`; see the ruleset for the exact policy |
| Bridges | `/usr/bin/edex-tor-bridges` → `/etc/tor/torrc.d/40-bridges.conf` | obfs4 via `lyrebird`, Snowflake via `snowflake-client` |
| Firewall | `/etc/edex-os/nftables.conf` (`inet edex-filter`), `nftables.service.d/edex.conf` | never flushes the ruleset; Tailscale's and Tor's tables coexist |
| DNS | `/etc/edex-os/dnscrypt-proxy.toml`, `dnscrypt-proxy.socket`, `/etc/edex-os/resolv.conf` via tmpfiles, NM `dns=none` | DNSSEC + no-log resolvers required; queries go to Tor's DNSPort in transparent mode |
| NetworkManager | `conf.d/20-edex-privacy.conf` | random MACs per connection, randomised scan MACs, IPv6 privacy extensions, no connectivity probes |
| Kernel | `sysctl.d/90-edex-privacy.conf` | kptr/dmesg/bpf/ptrace restrictions, redirects off, rp_filter, IPv6 temporary addresses, forwarding on (for Tailscale exit nodes only; the firewall gates it) |
| Tailscale | `edex-tailscale-operator` | first login user (or the one given) becomes `tailscale set --operator`; exit-node, LAN access and advertising are set from the DE |
| Lid / logind | `edex-logind-conf lid <action>` | writes `/etc/systemd/logind.conf.d/50-edex.conf` |
| polkit | `50-edex-privacy.rules`, `50-edex-nm.rules` | wheel may pkexec exactly the helpers above and manage NetworkManager |

Threat-model notes: transparent mode protects against application-level leaks (any TCP/DNS is torified,
other protocols are dropped) but not against a compromised root, hardware identifiers, or the fact that
Tailscale traffic is exempt unless `--strict` is used.
