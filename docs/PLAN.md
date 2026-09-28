# eDEX-OS + eDEX-DE: plan to finish the OS and desktop environment

## Context

eDEX-OS is meant to be a privacy-focused CachyOS/Arch distribution whose desktop is eDEX-DE, a sci-fi shell in the style of eDEX-UI. Today neither repo delivers that:

- **eDEX-DE** (`eDEX-OS/eDEX-DE`, master `b8dad02`, v2.0.8) was rewritten in May 2026 as a pure-Rust smithay compositor + wgpu shell. The shell pieces are real (PTY terminal, file panel, sysmon, fuzzy launcher, wgpu layer-shell renderer, three TOML themes), but the in-tree compositor never draws application windows, has no pointer support, and the settings panel, config file, notifications and lock screen are not wired. README and website promise a complete DE.
- **eDEX-OS** (`eDEX-OS/eDEX-OS`, main `66f0999`, v0.1.0-alpha) still targets the *old* Tauri + Hyprland design: `desktop/` submodule pinned to the Tauri commit `098d6b5`, CI runs `npm run tauri build`, ISO ships Hyprland + waybar + wofi. Nothing in `system-settings/`, `calamares/`, `branding/` or `packages/` reaches the ISO; the live initramfs config is missing (ISO cannot mount `airootfs.sfs`); the Calamares config has fatal errors (no `instances:`, invalid shellprocess syntax, wrong unpackfs source, no kernel copied to `/boot`, missing branding images); Tor transparent mode fails open.

### Owner decisions (locked)

| Decision | Choice |
|---|---|
| Compositor | **Hyprland** (Arch `hyprland 0.56.2`). eDEX-DE becomes a Rust *shell* on Hyprland, ML4W-style (curated dotfiles + custom apps), but every visible pixel is eDEX. The smithay `compositor/` crate is removed. |
| Repos | eDEX-DE stays a **separate repo**; work lands on a branch there; eDEX-OS pins it as the `desktop/` submodule and builds it into an Arch package during the ISO build. |
| Login | **greetd + custom Rust greeter** (`edex-greeter`, new crate in eDEX-DE) run under `cage`. Live ISO autologs into the session. |
| Shell scope | Rust shell draws **everything visible**: panels, terminal, file browser, sysmon, hex keyboard, bars, launcher, 14-category settings wired to real backends, privacy panel, notifications (edex-de is the D-Bus notification server), power menu, OSD. `hyprlock` (eDEX theme) + `hypridle` handle lock/idle. |
| Artwork | Generated from SVG by a checked-in script. |
| Quality bar | Daily-driver: ISO boots UEFI+BIOS, Calamares installs, DE runs real apps, privacy controls work end-to-end, README claims all true, CI green, tagged releases. Nothing stubbed. |

### Verified upstream facts (Sept 2026)
Arch ships Hyprland 0.56.2; since 0.55 config is **Lua** (`~/.config/hypr/hyprland.lua`; API `hl.monitor/hl.config/hl.env/hl.bind/hl.dsp.*/hl.window_rule/hl.layer_rule/hl.workspace_rule/hl.curve/hl.animation/hl.device/hl.gesture`, autostart via `hl.on("hyprland.start", fn)`; reference copy at scratchpad `hyprland-example.lua`); hyprlang `.conf` deprecated; sessions launch `start-hyprland`. Current Arch names: `hyprland-guiutils`, `hyprpolkitagent`, `hyprlock`, `hypridle`, `hyprsunset`, `greetd`, `cage`, `7zip` (not p7zip), `awww` (not swww). `lyrebird`/`snowflake-pt-client` are AUR-only. CachyOS repo provides `cachyos-calamares` (provides `calamares`, ships its own `/etc/calamares` config), `cachyos-v3-mirrorlist`, `cachyos-v4-mirrorlist`, `cachyos-plymouth-theme`. CachyOS live ISO uses `HOOKS=(base udev microcode modconf memdisk archiso archiso_loop_mnt archiso_pxe_* block filesystems keyboard)` and a `mkinitcpio.d/<kernel>.preset` with `PRESETS=('archiso')`.

### Prerequisites
- Push access to `eDEX-OS/eDEX-DE` (currently read-only; re-run `add_repo` with `access: push`). eDEX-DE work goes to branch `claude/shell-on-hyprland`; eDEX-OS work to `claude/intelligent-babbage-q5yi36`.
- All builds/tests run inside an `archlinux:latest` container (GitHub-hosted runners); anything marked **VERIFY** is checked with the given command on day one of that work package, never guessed.

---

## Target architecture

```
greetd (tty1) ──▶ cage -s -- edex-greeter            installed systems
              └─▶ edex-session (initial_session)     live ISO autologin
edex-session ──▶ start-hyprland ──▶ Hyprland 0.56 (Lua config, /usr/share/edex-de/hypr/)
   hyprland.start ──▶ dbus/systemd env import, hyprpolkitagent, hypridle, portals,
                      systemctl --user start edex-de.service
edex-de (one process, calloop event loop)
   per output: canvas    = zwlr_layer_surface(Background, anchor all, exclusive -1, kbd OnDemand, wgpu)
               reservers = 4 invisible Top-layer surfaces (top/bottom/left/right) whose exclusive
                           zones equal the bar/keyboard/side-panel sizes → Hyprland tiles app
                           windows exactly into the terminal slot
               overlay   = zwlr_layer_surface(Overlay, anchor all, kbd Exclusive, wgpu), on demand
               toasts    = zwlr_layer_surface(Overlay, top-right, kbd None), while toasts exist
   sockets: $XDG_RUNTIME_DIR/edex-de/ipc.sock (shell IPC, driven from Lua binds),
            Hyprland .socket.sock / .socket2.sock, session D-Bus (Notifications server; NM/bluez/
            upower/logind/systemd/accountsservice clients)
```

Layer topology rationale: reservers make the tiling area the terminal slot, so the file panel, sysinfo panel, bars and keyboard stay visible around real apps (the eDEX-UI look with apps in the middle). Reservers draw a 1×1 transparent `wl_shm` buffer scaled by `wp_viewport`, with an empty input region, so pointer events fall through to the canvas. Dragging a resize handle updates a reserver's `set_size`/`set_exclusive_zone`; Hyprland relayouts live. Canvas uses `KeyboardInteractivity::OnDemand` (click focuses the shell; clicking an app returns focus). Overlays use `Exclusive` and close on Escape/click-outside. Toasts never take focus.

---

## Phase A — eDEX-DE (repo `/home/user/edex-de`, branch `claude/shell-on-hyprland`)

### A0. Workspace reshape
- Delete `compositor/` crate, `renderer/src/wayland_client.rs`, `packaging/session/edex-de-startup.sh`, `packaging/session/edex-de-portals.conf` (replaced), `terminal/src/{pty,vt}.rs` (empty stubs), `sysmon/src/{cpu,disk,network,process,ram}.rs` (empty stubs), `renderer/src/ui/borders.rs` (unused).
- `Cargo.toml`: members `edex-de, edex-greeter, platform, renderer, ui, terminal, launcher, settings, sysmon, notifications, hypr, ipc, system`; workspace version `3.0.0` used by every crate (`version.workspace = true`); remove `smithay, wayland-server, termwiz, vte, portable-pty, fontdue, cosmic-text (direct), tokio`; add `smithay-client-toolkit 0.19 (calloop)`, `calloop 0.14`, `calloop-wayland-source`, `wayland-protocols (client, staging, unstable)`, `wayland-cursor`, `alacritty_terminal`, `zbus 5 (async-io)`, `clap 4`, `greetd_ipc (sync-codec)`, `notify`, `rustix`, `xdg`, `roxmltree`, `image (png)`, `unicode-width`, dev: `insta`, `tempfile`. wgpu 29 with `vulkan` + `gles` features so `Backends::VULKAN | GL` works on lavapipe/llvmpipe VMs.
- Gate: `cargo build --workspace --locked` green with the compositor gone (main.rs temporarily minimal); CI green.

### A1. `platform` crate (sctk client, calloop loop, outputs, pointer, HiDPI)
Files: `platform/src/{lib,output,surface,reserver,seat,events,raw,xdg_window}.rs`.
- `Platform` owns `Connection`, `EventLoop`, sctk `RegistryState/OutputState/SeatState/CompositorState/LayerShell/Shm`, manual binds for `wp_fractional_scale_manager_v1`, `wp_viewporter`, `wp_cursor_shape_manager_v1`, `zxdg_output_manager_v1`. Wayland fd via `WaylandSource`; no `dispatch_pending()+sleep`.
- `output.rs`: per-output `OutputShell` (canvas + 4 reservers + optional overlay/toast) created/destroyed on hotplug; logical geometry from xdg-output, scale from fractional-scale (fallback `wl_output.scale`).
- `surface.rs`: `EdexSurface` with frame-callback pacing (`dirty && !frame_pending` → render), buffer size = logical × scale, `wp_viewport.set_destination`.
- `reserver.rs`: creation order top, bottom, then left/right (later surfaces respect earlier exclusive zones so corners are not double-reserved).
- `seat.rs`: keyboard (xkb, repeat via calloop timer), pointer (enter/leave/motion/button/axis with surface identity), cursor via cursor-shape-v1 with `wayland-cursor` fallback.
- `xdg_window.rs`: fullscreen xdg-toplevel mode used by the greeter under cage (no layer-shell there).
- Timers: clock 1 s, sysmon 1 s, privacy probes 3 s, animation tick 16 ms only while animating.
- Tests: scale math, reserver geometry, dirty/frame flags.

### A2. Renderer rewrite + `ui` crate
- `renderer/src/{lib,rects,text}.rs`: `GpuContext` (shared instance/adapter/device/queue) + `SurfaceRenderer` per surface. sRGB surface format with theme colors converted once at load. **Instanced rect pipeline** (single persistent instance buffer written once per frame) replaces `draw_uniform_rect` (which allocates a buffer + bind group per rect per frame). `TextCache` keyed by content/width/size so only changed lines reshape; terminal lines cached per line. Shaders: `rect.wgsl` (panel border/glow/keys), `scanline.wgsl`.
- New `ui` crate (moved from `renderer/src/ui/*`, no wgpu dependency): `layout.rs` (scale-aware, keyboard height from font metrics), `resize.rs` (draggable handles → reserver updates), `theme.rs`, `state.rs`, `scene.rs`, `hit.rs`, `widgets/{button,list,tabs,slider,toggle,text_input,scrollview}.rs`, `panels/{topbar,statusbar,filesystem,terminal_view,sysinfo,keyboard,launcher,settings/*,privacy/*,notifications,power,osd,boot}.rs`.
- Focus model `PanelFocus { Filesystem, Terminal, Keyboard }`: Up/Down/Enter/Backspace go only to the focused panel (fixes the current hijack in `main.rs:367-387`); Tab/Shift+Tab cycles; click focuses.
- Sysinfo panel gets real graphs (CPU per-core bars, RAM/swap bars, network history sparkline from the existing 60-sample buffer, disk usage bars, process list), and the status bar shows all six privacy indicators (Tor, Tailscale, VPN, WireGuard, fprintd, mic, camera).
- Tests: `insta` snapshots of `PanelLayout` at 1280×720, 1920×1080, 2560×1440@1.5, 3840×2160@2; hit-test and focus unit tests.

### A3. Terminal on `alacritty_terminal`
Replace the hand-rolled VT (`terminal/src/{grid,instance,tab}.rs`) with `alacritty_terminal` (alt screen, DEC private modes, scroll regions, IL/DL/ICH/DCH/ECH, SU/SD, save/restore cursor, wide chars, bracketed paste, OSC 52, selection, scrollback, damage, title/bell/exit events, own PTY).
- `terminal/src/{lib,pty,input,render_model,metrics,clipboard}.rs`: tabs wrap `Term<Listener>`; PTY events reach calloop via a channel; `render_model` yields per-cell fg/bg/attrs + cursor shape + selection; PTY sized from the real terminal rect using measured cell metrics; clipboard via sctk data-device (drop `wl-copy`/`wl-paste` subprocesses); OSC 52 read denied by default.
- Child exit: "[process exited N]" + Enter to close; closing the last tab spawns a new shell. Clickable tab bar; `Ctrl+Shift+T/W`, `Alt+1..9`, `Shift+PgUp/PgDn` scrollback, mouse selection, mouse reporting when apps enable it.
- Tests: `terminal/tests/vt_fixtures.rs` with fixture streams (alt screen, scroll region, IL/DL, wide chars, bracketed paste, cursor save/restore, ECH/DCH/ICH) → `insta` grid dumps.

### A4. Hyprland integration, shell IPC, Lua dotfiles, session
- New `hypr` crate: `socket.rs` (`.socket.sock`, `j/` JSON commands: monitors, workspaces, activewindow, clients, layers, dispatch, keyword, reload), `events.rs` (`.socket2.sock` stream in calloop; workspace/focusedmon/activewindow/monitor/layout/fullscreen/open-close/configreloaded), `model.rs` (`HyprState`, resync on reload; `unavailable()` when no socket → shell degrades gracefully, e.g. in the sway CI job).
- Top bar: workspace strip (click → `dispatch workspace N`), active window title, keyboard layout, clock; status bar keeps indicators.
- New `ipc` crate: newline-delimited JSON over `$XDG_RUNTIME_DIR/edex-de/ipc.sock` (0600). Commands: `ping, toggle/show/hide {launcher|settings|privacy|notifications|power}, focus {terminal|filesystem}, audio {volume ±N|set N|mute}, brightness ±N, theme <name>, reload, state, screenshot-scene, quit`. CLI `edex-de ipc …` (clap) used by Lua binds and tests.
- `edex-de/src/main.rs`: clap CLI (`run` default, `ipc`, `--smoke-test <secs>`, `--config`, `--no-hypr`); `App` with handlers for platform/terminal/hypr/ipc/dbus events; subsystem errors log and degrade, only a lost Wayland connection exits.
- Lua dotfiles in `hypr/lua/` installed to `/usr/share/edex-de/hypr/`: `hyprland.lua` (entry, includes the rest; **VERIFY** include mechanism `dofile`/`require`/`hl.source` with `Hyprland --verify-config` in the container), `monitors.lua`, `env.lua` (`XDG_CURRENT_DESKTOP=eDEX-DE:Hyprland`, Qt/GTK/Mozilla/Electron Wayland vars), `look.lua` (gaps 4/8, cyan borders, rounding 0, blur/shadow off, `misc.disable_hyprland_logo`, `background_color`, eDEX bezier curves/animations), `input.lua`, `rules.lua` (`hl.layer_rule` for `edex-de:*` namespaces: no animation/blur; `hl.window_rule` float+center for calamares), `binds.lua` (SUPER+Space launcher, SUPER+, settings, SUPER+P privacy, SUPER+N notifications, SUPER+Escape power menu, SUPER+Return focus terminal, SUPER+SHIFT+Return kitty, SUPER+E nemo, SUPER+Q kill, SUPER+F fullscreen, SUPER+V float, SUPER+H/J/K/L focus, SUPER+SHIFT+… move, SUPER+1..9 workspaces, SUPER+L hyprlock, Print/SUPER+SHIFT+S grim+slurp, XF86 audio/brightness/media keys via `edex-de ipc`/`playerctl`, SUPER+mouse drag/resize), `autostart.lua` (`hl.on("hyprland.start")`: `dbus-update-activation-environment --systemd …`, `systemctl --user import-environment …`, start `hyprpolkitagent.service hypridle.service`, restart portals, `wl-paste --watch cliphist store`, `systemctl --user start edex-de.service`), `hyprlock.conf` (eDEX theme, fingerprint enabled), `hypridle.conf` (dim 300 s, lock 600 s, dpms 900 s, lock before sleep). `hypr/skel/hyprland.lua` → `/etc/skel/.config/hypr/hyprland.lua` includes system config, then `~/.config/edex-de/hypr/generated.lua` (from settings), then optional `~/.config/hypr/user.lua`.
- Session: `packaging/session/edex-de.desktop` (`Exec=edex-session`, `DesktopNames=eDEX-DE;Hyprland`), `packaging/session/edex-session` (sh: log to `$XDG_STATE_HOME/edex-de/session.log`, export desktop vars, `exec start-hyprland`), `packaging/session/edex-de-portals.conf` (`default=hyprland;gtk`, FileChooser=gtk, Secret=gnome-keyring), `packaging/systemd/edex-de.service` (user unit, `PartOf=graphical-session.target`, `Restart=on-failure` so a shell crash restarts without killing the session). Polkit agent: `hyprpolkitagent`.
- Gate: on a real/nested Hyprland, apps tile into the terminal slot, workspace strip updates, Lua binds open overlays via IPC, resize handles move the tile boundary.

### A5. `system` crate (backends) + D-Bus thread + sysmon fixes
- `CommandRunner` trait (`RealRunner`/`FakeRunner` with fixtures) and a `DbusThread` (zbus on a dedicated thread; requests via mpsc, results/signals via calloop channel).
- `audio.rs` (wpctl status/get-volume/set-volume/set-mute/set-default; change detection via `pactl subscribe` fd) — removes hardcoded `volume: 42`. `network.rs` (NM D-Bus props/signals; nmcli wifi list/connect, connection up/down, radio, VPN import wireguard/openvpn; rfkill). `bluetooth.rs` (bluez D-Bus Adapter1/Device1/ObjectManager + Agent1 KeyboardDisplay). `power.rs` (upower DisplayDevice; brightnessctl; power-profiles-daemon D-Bus; logind Suspend/Hibernate/Reboot/PowerOff + Can*). `users.rs` (accountsservice; `passwd` in a terminal tab; lock/unlock via pkexec). `services.rs` (systemd system+session bus units list/start/stop/enable/disable). `display.rs` (`hyprctl -j monitors`; live `hyprctl keyword monitor …`; persist `hl.monitor` into `generated.lua`; night light via `hyprsunset`). `input.rs` (layouts from `/usr/share/X11/xkb/rules/evdev.xml`; `hyprctl keyword input:*`). `privacy/{tor,tailscale,vpn,dns}.rs` (Tor: mode from `/run/edex-tor-mode`, `pkexec edex-tor-mode`, `pkexec edex-tor-bridges`, control-port client with cookie auth for bootstrap %/circuits/NEWNYM; Tailscale: `tailscale status --json`, `login` URL, `set --exit-node`, `--exit-node-allow-lan-access`, `--advertise-exit-node`, up/down; VPN: nmcli + portal FileChooser; DNS: dnscrypt socket status + test resolve).
- `sysmon`: privacy probes moved to a 3 s timer (mic/camera `/proc` walk every 5 s, prefer `wpctl status` streams for mic); fix net-rate double-delta bug (`collector.rs:106-122`); bounded sysinfo refreshes.
- Tests: fixture parsers for wpctl/nmcli/tailscale/tor/evdev.

### A6. Config system + themes
- `settings/src/{config,io,hypr_export,paths}.rs`: full schema (`[appearance] theme font font_size border_glow scanlines animations keyboard_visible`, `[layout] fs_split sysinfo_split reserve_side_panels`, `[terminal] shell scrollback font_size cursor cursor_blink bell osc52_read`, `[launcher]`, `[notifications] dnd timeout_ms position max_visible muted_apps`, `[wm] gaps_in gaps_out border layout workspaces`, `[input]`, `[display] monitors night_light night_temp`, `[power] dim_after lock_after dpms_after profile lid_close`, `[privacy] tor_mode_on_login tailscale_exit_node`); `load()` with `#[serde(default)]` merge, atomic `save()`, `notify` watcher for live reload; `hypr_export` writes `~/.config/edex-de/hypr/generated.lua` + `hypridle.conf` then `hyprctl reload`.
- `ui/src/theme.rs`: full key set (bg, panel_bg, border, text_primary/secondary, accent, warning, error, cursor, selection, terminal palette[16]+fg/bg, keyboard key/key_active, glow) loaded from `/usr/share/edex-de/themes/*.toml` then `~/.config/edex-de/themes/`; `include_str!` fallback only for tron. Ship `themes/{tron,matrix,amber,cyborg,blade,apollo,interstellar,horizon,navy,nord,red,purple}.toml` with palettes ported from eDEX-UI. Live switch via `edex-de ipc theme`.
- Tests: config round-trip, default merge, golden `generated.lua`.

### A7. Overlays: launcher, settings (14 categories), privacy, power, OSD; clickable panels
- Launcher (`launcher/src/{desktop,runner,search}.rs` + `ui/panels/launcher.rs`): scan `$XDG_DATA_HOME` + all `$XDG_DATA_DIRS/applications` (dedupe by desktop-id), honor `Hidden/NoDisplay/OnlyShowIn/NotShowIn/TryExec/Terminal/Path`, field codes; launch via `hyprctl dispatch exec` (detached, SIGCHLD reaped via calloop signals); fuzzy on name/generic/keywords/comment + recency; text input, list, Enter/Ctrl+Enter.
- Settings (`ui/panels/settings/*.rs`), every control bound to a `system`/`settings` backend:
  1 Appearance (theme/font/glow/scanlines/animations/keyboard → config, live) · 2 Display (monitors → hyprctl + generated.lua; night light) · 3 Input (layouts/repeat/touchpad → hyprctl + generated.lua) · 4 Audio (wpctl) · 5 Network (NM: wifi list/connect, connections, VPN import) · 6 Bluetooth (bluez) · 7 Power (brightness, profile, idle/lock/dpms timeouts → hypridle.conf, lid action via `pkexec edex-logind-conf`) · 8 Security (hyprlock options, fprintd enroll/list via `net.reactivated.Fprint`, firewall + keyring status) · 9 Users (accountsservice, passwd, lock/unlock) · 10 Notifications (DND, timeout, position, per-app mute) · 11 Services (systemd units) · 12 Window Manager (gaps/border/layout/workspaces/animations → generated.lua; keybind cheat sheet from `hyprctl -j binds`) · 13 Terminal (shell/scrollback/font/cursor/bell/OSC52) · 14 About (os-release, kernel, CPU, GPU adapter, RAM, Hyprland version, edex-de version, uptime).
- Privacy panel (`ui/panels/privacy/{tor,tailscale,vpn,dns}.rs`): Tor mode radio (confirm transparent), bootstrap %, circuit state, NEWNYM, bridges editor (obfs4 lines / built-in snowflake / clear); Tailscale state, login URL + open-in-browser, peers table, exit-node picker, allow-LAN, advertise-exit-node, up/down; VPN connections up/down/import/delete; DNS status + test query.
- Power menu (lock/logout/suspend/hibernate/reboot/poweroff via logind), OSD (volume/brightness on toast surface).
- Filesystem panel: click/double-click, clickable breadcrumbs, right-click "open terminal here". Hex keyboard: clickable keys inject into the active tab; highlights physical presses when focused; Caps/Shift indicators.
- Live-ISO hook: top bar shows an "INSTALL eDEX-OS" button when `/run/archiso` exists (runs `edex-install`).

### A8. Notifications server
- `notifications/src/{server,store}.rs`: zbus `org.freedesktop.Notifications` (GetCapabilities, Notify with urgency/desktop-entry hints, CloseNotification, GetServerInformation, NotificationClosed/ActionInvoked signals); name requested with DoNotQueue (if another daemon owns it, toasts disable + log). History (200, persisted to `~/.local/state/edex-de/notifications.json`), DND, per-app mute, critical never expires. Toasts on the toast surface; history overlay. No D-Bus activation file; eDEX-OS must not ship dunst/mako.
- Test: `notify-send` in the smoke job → `edex-de ipc state` shows one toast; introspection test on a private bus.

### A9. Greeter (`edex-greeter` crate)
- greetd runs `cage -s -- edex-greeter` (kiosk compositor, no config, fullscreens the single toplevel; Hyprland-as-greeter rejected for startup time and a second config).
- `edex-greeter/src/{main,greetd,users,sessions,ui}.rs`: `greetd_ipc` sync codec on `$GREETD_SOCK` (CreateSession → AuthMessage loop incl. fprintd info lines → StartSession `edex-session`); users from `/etc/passwd` (uid 1000..60000, login shell), last user/session in `/var/cache/edex-greeter/state.toml` (tmpfiles.d); sessions from `/usr/share/wayland-sessions`; eDEX UI (procedural hex-grid + optional background PNG, clock/hostname, user list, masked password with Caps warning, session dropdown, power buttons via logind + polkit rule for the `greeter` user). Config `/etc/edex-greeter/greeter.toml`.
- `packaging/greetd/config.toml` reference (`[terminal] vt=1`, `[default_session] command="cage -s -- edex-greeter" user="greeter"`).
- Tests: users/sessions parsing; fake greetd socket for the AuthMessage conversation.

### A10. Packaging, CI, docs, tag
- `packaging/aur/PKGBUILD`: pkgver 3.0.0, deps `hyprland>=0.55 cage greetd libxkbcommon wayland vulkan-icd-loader pipewire wireplumber networkmanager bluez upower brightnessctl hyprlock hypridle hyprpolkitagent hyprsunset xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit ttf-jetbrains-mono-nerd kitty wl-clipboard cliphist grim slurp playerctl` (**VERIFY** names with `pacman -Si` in the container), optdepends `tailscale tor lyrebird snowflake-pt-client fprintd power-profiles-daemon accountsservice`; `build()` `cargo build --release --locked --workspace --bins` + `assets/make-assets.sh`; installs bins, session files, user unit, `/usr/share/edex-de/{themes,hypr,greetd,backgrounds}`, skel Lua, tmpfiles, greeter config, polkit rule; real sha256 in release. `.install` message for greetd setup.
- Debian: complete `packaging/debian/{control,rules,changelog,copyright,compat,edex-de.install,postinst}` and build with `dpkg-buildpackage` in release.yml; RPM spec: script path `%{_bindir}`, `Requires:` outside `%description`, versions from tag. README labels deb/rpm as CI-built, not integration-tested.
- `assets/{logo.svg,hexgrid.svg,make-assets.sh}` (rsvg-convert → lock background, logo PNGs; outputs gitignored).
- `.github/workflows/ci.yml`: `check` (`--locked`, clippy `-D warnings`, fmt), `test`, `smoke-sway` (ubuntu-24.04: headless sway + pixman renderer; `edex-de run --smoke-test 8 --no-hypr`; assert surfaces configured, ≥3 frames, `notify-send` → 1 toast, `grim` screenshot artifact), `smoke-hyprland` (archlinux container; **VERIFY** Aquamarine headless feasibility; else `workflow_dispatch`-only and rely on the ISO QEMU test), `pkgbuild` (makepkg + namcap in container). `release.yml`: on tag, `--locked` build + tests, tarball, deb, rpm, checksums, GitHub Release, AUR publish with real sha256. Release depends on CI.
- Docs: README rewrite (shell on Hyprland, install, greetd snippet, keybinds from binds.lua, config schema, themes, architecture, troubleshooting), `CHANGELOG.md`, `CONTRIBUTING.md`, `docs/{architecture,ipc,testing}.md`; `website/index.html` text aligned; fix `404.html` root link.
- Gate: tag `v3.0.0-rc.1`; eDEX-OS pins that commit.

---

## Phase B — eDEX-OS (repo `/home/user/eDEX-OS`, branch `claude/intelligent-babbage-q5yi36`)

### B1. Package pipeline + local `[edex-os]` repo
- `scripts/build-packages.sh` (inside the Arch container): creates `builder` user; for each `packages/<name>/`, makes a source tarball from the **local tree** (`git -C desktop archive` for the submodule; tar of `system-settings/`, `branding/generated`, `calamares/`, `live/`), sets `pkgver` from `git describe`, `makepkg -s --noconfirm`, then `repo-add out/repo/edex-os.db.tar.gz`. AUR packages (`yay-bin`, `paru-bin`, `lyrebird`, `snowflake-pt-client`) cloned at pinned commits and built the same way.
- PKGBUILDs (`source=("${pkgname}-${pkgver}.tar")`, real `install=` files, no `post_install` inside PKGBUILD, no file conflicts):
  - `packages/edex-de/` — builds the submodule; provides `edex-de`, `edex-greeter`.
  - `packages/edex-os-settings/` — `/etc/edex-os/nftables.conf` + `nftables.service.d/edex.conf` drop-in; `/etc/edex-os/dnscrypt-proxy.toml` + service drop-in; `/etc/edex-os/resolv.conf` + tmpfiles symlink; NM `conf.d/{10-edex-dns.conf (dns=none, rc-manager=unmanaged), 20-edex-privacy.conf (MAC randomization, connectivity off)}`; `sysctl.d/90-edex-privacy.conf`; `/etc/edex-os/torrc` + `tor.service.d/edex.conf` (`-f /etc/edex-os/torrc`, `RuntimeDirectory=tor` 0750; cookie in `/run/tor/control.authcookie`, group-readable — fixes the unreadable-cookie bug) + `%include /etc/tor/torrc.d/`; helpers `/usr/bin/{edex-tor-mode,edex-tor-bridges,edex-tailscale-operator,edex-logind-conf,edex-enable-cachy-repos}`; units `edex-tor-mode.service` (restores persisted mode at boot), `edex-tailscale-operator.service`; polkit rules per helper (wheel → YES for that exact pkexec path) + `50-edex-greeter-power.rules`; `/usr/share/edex-os/tor/{transparent.nft,snowflake-bridges.conf}`; `/usr/share/edex-os/mkinitcpio/linux-cachyos.preset` (stock preset copy for the installer).
  - `packages/edex-os-branding/` — Plymouth theme + generated images, GRUB theme + fonts + icons + background, wallpapers, icons; `.install` runs `plymouth-set-default-theme edex-os`.
  - `packages/edex-os-calamares-config/` (dir renamed to match pkgname) — installs to **`/etc/edex-os/calamares/`** (not `/etc/calamares`, which `cachyos-calamares` owns) plus `/usr/bin/edex-install` (`pkexec calamares -c /etc/edex-os/calamares` with `QT_QPA_PLATFORM=wayland`; **VERIFY** `-c` support in cachyos-calamares, else `-d` + `XDG_CONFIG_DIRS`) and `/usr/share/applications/edex-install.desktop`.
  - `packages/edex-os-greetd-config/` — `/etc/edex-os/greetd.toml` + `greetd.service.d/edex.conf`; `.install` adds `pam_fprintd` line to `/etc/pam.d/greetd` idempotently.
  - `packages/edex-os-live/` — live-only (removed by Calamares): greetd `initial_session` autologin for `liveuser`, sudoers NOPASSWD, live polkit rule, `edex-setup-live` (copies skel, chowns), no-suspend logind drop-in, volatile journald, `edex-ci-report` + unit, `edex-ci-install` (B6), systemd preset enabling the live units.
- `iso/pacman.conf.in` → generated `iso/pacman.conf` with `[edex-os] SigLevel = Optional TrustAll Server = file://@REPO_DIR@` above `[cachyos]`; upstream repos keep `SigLevel = Required DatabaseOptional`: `scripts/ci-build-iso.sh` runs `pacman-key --init/--populate archlinux`, imports the CachyOS key, installs `cachyos-keyring cachyos-mirrorlist`, `--populate cachyos`. Remove the `SigLevel=Never` seds and all in-place edits of tracked files.
- Gate: repo builds; `pacman -Sp` resolves every entry in `packages.x86_64`.

### B2. archiso profile completion
- Start from the container's `/usr/share/archiso/configs/releng/` and apply eDEX changes (**VERIFY** `bootmodes` spelling there).
- `iso/profiledef.sh`: `iso_name=edex-os`, label `EDEX_OS_YYYYMM`, `file_permissions` only for files that exist (`/etc/shadow`, `/etc/gshadow`, `/root`, `/etc/sudoers.d`, `/usr/local/bin/*`).
- `iso/packages.x86_64`: remove `waybar wofi dunst swww hyprpaper p7zip polkit-gnome network-manager-applet nm-connection-editor iwd dhcpcd mkinitcpio-nfs-utils`; add `edex-de edex-os-settings edex-os-branding edex-os-calamares-config edex-os-greetd-config edex-os-live yay-bin paru-bin git 7zip plymouth greetd cage hyprland-guiutils hyprpolkitagent hyprlock hypridle hyprsunset xorg-xwayland vulkan-swrast vulkan-icd-loader mesa libva-mesa-driver brightnessctl power-profiles-daemon accountsservice lyrebird snowflake-pt-client libnotify pacman-contrib archlinux-keyring cachyos-keyring cachyos-v3-mirrorlist cachyos-v4-mirrorlist wpa_supplicant jq squashfs-tools arch-install-scripts qt6ct edk2-shell ttf-dejavu` (**VERIFY** each with `pacman -Si`; the build fails loudly otherwise).
- `iso/airootfs/etc/`: `hostname`, `locale.conf`, `locale.gen`, `vconsole.conf`, `motd`, `issue`; `mkinitcpio.conf.d/archiso.conf` (`HOOKS=(base udev plymouth microcode modconf kms memdisk archiso archiso_loop_mnt archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs block filesystems keyboard)`, `MODULES=(virtio_gpu)`, zstd); `mkinitcpio.d/linux-cachyos.preset` (`PRESETS=('archiso')`); `passwd/shadow/group/gshadow` (root hash via `openssl passwd -6`, `liveuser` uid 1000, groups `wheel,audio,video,input,storage,network,rfkill,tor,users`); `pacman.conf` (runtime: cachyos + core/extra/multilib, signatures required); `systemd/system/{pacman-init.service, etc-pacman.d-gnupg.mount}` + `.wants` symlinks (multi-user: NetworkManager, pacman-init, edex-setup-live, tailscaled, nftables, bluetooth, edex-tor-mode, edex-tailscale-operator, power-profiles-daemon, accounts-daemon; sockets: dnscrypt-proxy.socket; graphical: greetd), `default.target → graphical.target`, mask `NetworkManager-wait-online`.
- Delete `airootfs/root/customize_airootfs.sh`, `airootfs/etc/skel/.config/hypr/hyprland.conf`, `airootfs/usr/bin/edex-setup-live`, `airootfs/etc/systemd/system/edex-setup-live.service` (moved to packages), all `.gitkeep`-only dirs, `iso/efiboot/`.
- Gate: `mkarchiso` completes; ISO contains `EFI/BOOT/BOOTx64.EFI`, `syslinux/`, `arch/x86_64/airootfs.sfs`.

### B3. Boot: GRUB, syslinux, Plymouth, artwork
- `scripts/make-artwork.sh` (librsvg, imagemagick, grub-mkfont, DejaVu): from `branding/src/{logo.svg → desktop/assets/logo.svg, hexgrid.svg, icon.svg}` produce into `branding/generated/` (gitignored): Plymouth `logo.png/bar.png/bar_bg.png`; GRUB `background.png`, `icons/edex-os.png`, `dejavu_sans_mono_{14,18,24}.pf2`, `unicode.pf2`; Calamares `logo.png/icon.png/welcome.png/slide-bg.png`; wallpapers 1080p/1440p/4K; app icons 64/128/256; syslinux `splash.png`; greeter/lock backgrounds.
- `branding/plymouth/edex-os/edex-os.script`: valid Plymouth script API (`Image()`, `Scale`, `SetBootProgressFunction`, `SetDisplayPasswordFunction` for LUKS, `SetMessageFunction`, `SetQuitFunction`); remove the nonexistent `Image.FromJpegData`.
- `branding/grub/edex-os/theme.txt`: reference generated fonts, background, boot_menu with icons, progress bar, help label.
- `iso/grub/grub.cfg`: `insmod` set, `loadfont` unicode + DejaVu, gfxterm + theme, entries: default, copytoram, nomodeset, serial console (`console=ttyS0,115200 console=tty0`), Memtest86+, UEFI Shell, firmware setup, reboot, poweroff; releng placeholders/search-by-label scheme.
- `iso/syslinux/`: releng set with `vesamenu.c32`, `splash.png`, eDEX colors, reachable copytoram/nomodeset/memtest/hdt entries.
- Secure Boot: out of scope, documented.
- Gate: UEFI (OVMF) and BIOS boots reach themed menus; serial log shows `Reached target Graphical Interface`.

### B4. Calamares
- `calamares/etc/calamares/settings.conf` with `instances:` (`shellprocess@kernel`, `shellprocess@postinstall`) and sequence `partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, luksbootkeyfile, luksopenswaphookcfg, initcpiocfg, shellprocess@kernel, initcpio, users, networkcfg, hwclock, services-systemd, packages, grubcfg, bootloader, shellprocess@postinstall, removeuser, umount`.
- Module confs: `welcome.conf` (storage/ram/root requirements), `locale.conf`, `keyboard.conf`, `partition.conf` (existing choices + erase default, gpt on EFI), `mount.conf` (btrfs subvolumes `@ @home @log @cache`, `noatime,compress=zstd:3`), `unpackfs.conf` (`source: /run/archiso/bootmnt/arch/x86_64/airootfs.sfs`, `sourcefs: squashfs`; copytoram handled by `edex-install` exporting the sfs path), `machineid`, `fstab.conf`, `initcpiocfg`, `initcpio.conf` (`kernel: linux-cachyos`), `shellprocess-kernel.conf` (`dontChroot: true`: copy `vmlinuz-linux-cachyos` from bootmnt into `${ROOT}/boot`, remove `archiso.conf`, install the stock preset, add `plymouth` hook), `users.conf` (`setRootPassword: true`, groups incl. `input lp`, fish shell, no autologin group), `networkcfg`, `hwclock`, `services-systemd.conf` (NetworkManager, greetd, tailscaled, nftables, bluetooth, edex-tor-mode, edex-tailscale-operator, power-profiles-daemon, accounts-daemon, fstrim.timer; socket dnscrypt-proxy.socket; target graphical), `packages.conf` (`try_remove: [edex-os-live, edex-os-calamares-config, cachyos-calamares, mkinitcpio-archiso]`), `grubcfg.conf` (quiet splash, GRUB_THEME, gfxterm, os-prober on), `bootloader.conf` (grub, `installEFIFallback: true`, id `eDEX-OS`), `shellprocess-postinstall.conf` (valid syntax, in chroot: `edex-enable-cachy-repos` (v3/v4 by CPU detection), `plymouth-set-default-theme edex-os`, `systemctl set-default graphical.target`, torrc.d dir, tor-mode state `off`, tmpfiles), `removeuser.conf` (`liveuser`), `umount.conf` (log to `/var/log/calamares.log`). `displaymanager` module not used (greetd config owned by drop-ins).
- Branding: `branding.desc` with generated images and current 3.3 style keys; `show.qml` fixed subtitle alpha and corrected slide text (Rust + wgpu shell on Hyprland).
- Gate: `QT_QPA_PLATFORM=offscreen calamares -d -c …` loads every module with zero errors; scripted install (B6) passes.

### B5. Privacy stack rewrite (`system-settings/`)
- `edex-tor-mode` (`off|socks5|transparent|status|restore`, state in `/var/lib/edex-os/tor-mode` + `/run/edex-tor-mode`): transparent writes `torrc.d/50-transparent.conf` (`TransPort 127.0.0.1:9040 Isolate*`, `DNSPort 127.0.0.1:5353`, `AutomapHostsOnResolve 1`, `VirtualAddrNetworkIPv4 10.192.0.0/10`), reloads tor, waits for bootstrap 100 % via the control cookie (timeout → roll back to socks5), then loads `/usr/share/edex-os/tor/transparent.nft` as `table inet edex-tor`: nat output chain (tor uid return → tailscale fwmark return → DNS redirect **before** loopback exclusion → VirtualAddr range redirect before LAN set → `lo`/LAN/`tailscale0` return → TCP redirect :9040) and a **fail-closed** filter output chain (policy drop; allow tor uid, tailscale mark, lo, LAN set, tailscale0, DHCP; drop IPv6 and everything else). `--strict` also drops Tailscale. `edex-tor-mode.service` restores persisted mode at boot, loading the drop-policy table before waiting for bootstrap (no fail-open window). `off/socks5` delete the table and the transparent conf.
- `edex-tor-bridges` (`obfs4 --stdin` with line validation, `snowflake` built-in list, `clear`) → `torrc.d/40-bridges.conf` with `ClientTransportPlugin` lines for `lyrebird`/`snowflake-client`.
- `nftables.conf`: own `table inet edex-filter` (no `flush ruleset`, so tor/tailscale tables survive), input drop with established/related, lo, DHCP, ICMP/ICMPv6, `tailscale0` accept; forward rules for exit-node use.
- `sysctl.d/90-edex-privacy.conf`: IPv6 kept on with temp addresses, `ip_forward=1` (exit node), drop `tcp_timestamps=0`, keep kptr/dmesg/bpf hardening.
- `dnscrypt-proxy.toml`: socket-activated on 127.0.0.1:53, `require_dnssec`, no `query_log`/`nx_log`, IPv6 allowed; NM `dns=none` + tmpfiles `resolv.conf` → actually used as the resolver.
- `edex-tailscale-operator` (service sets `tailscale set --operator` for the first wheel user; pkexec path from the DE), `edex-logind-conf` (whitelisted lid action), `edex-enable-cachy-repos` (detect v3/v4 via `ld.so --help`, insert repos idempotently).
- Tests: `tests/privacy/nft-lint.sh` (`nft -c -f`), `tests/privacy/tor-mode.bats` run in the live VM (fail-closed assertion without network; `check.torproject.org` assertion on a developer machine).

### B6. Scripts, CI, tests, docs
- `buildiso.sh` (clean work dir → artwork → packages → generate pacman.conf → copy fonts/theme/splash → `mkarchiso` → checksums); `scripts/ci-build-iso.sh` same steps in-container with keyring init; delete `scripts/build-de.sh`.
- `scripts/test-iso.sh --mode uefi|bios|both`: OVMF path detection (`/usr/share/edk2/x64/OVMF_CODE.4m.fd`, `/usr/share/OVMF/OVMF_CODE_4M.fd`, …), KVM if available else TCG, serial log, `-vga virtio`, asserts `EDEX_CI: boot-ok` and `EDEX_CI: shell-ok` (printed by `edex-ci-report` after `graphical.target` and when `hyprctl -j layers` shows `edex-de:canvas`), non-zero exit otherwise.
- `scripts/test-install.sh`: direct-kernel boot of the ISO's kernel/initramfs with `edex.ci=install` → `edex-ci-install.service` performs the same steps as the Calamares exec sequence (partition, unsquashfs, kernel copy, mkinitcpio, grub-install EFI+BIOS, user, remove live package; the shellprocess confs are generated from `/usr/share/edex-os/install-steps/*.sh` by `scripts/gen-calamares-shellprocess.py` so they cannot drift), then boots the resulting disk in UEFI and BIOS and asserts greetd is active.
- `scripts/lint.sh`: shellcheck, yamllint, namcap.
- Workflows: `lint.yml`; `packages.yml` (container build of all packages + namcap on relevant path changes); `build-iso.yml` (push main/tags, PRs, dispatch; checkout **pinned** submodule, no `--remote`; free disk; Docker archlinux build; checksums; GPG with `--pinentry-mode loopback`; `test-uefi`, `test-bios`, `test-install` jobs in the same workflow, failing on missing markers); `release.yml` (tag: ISO + checksums + `.asc` + package repo tarball; notes from `CHANGELOG.md`); `bump-desktop.yml` (daily: open a PR when the submodule has new commits). Delete `build-de.yml`, `test-iso.yml`, `pkgbuild.yml` (self-hosted runner requirement removed).
- Docs: README rewrite (real features, container build one-liner, testing, layout, privacy semantics, known limitations: no Secure Boot, NVIDIA needs `nvidia-open-dkms` + `nvidia_drm.modeset=1`, Tor transparent vs Tailscale), `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/{building,testing,architecture,installer,privacy}.md`. Release body no longer repeats unimplemented claims.

---

## Order and gates

| Step | Work | Gate |
|---|---|---|
| 1 | A0 | `cargo build --locked` without compositor; CI green |
| 2 | A1, A2, A6 | `edex-de --smoke-test` under headless sway; layout snapshots |
| 3 | A3 | VT fixtures; vim/htop/tmux usable |
| 4 | A4 | Real Hyprland: apps tile into terminal slot, IPC binds, session via greetd on a VM |
| 5 | A5, A7, A8 | Backend fixture tests; manual matrix of 14 categories; `notify-send` toast |
| 6 | A9, A10 | Greeter login on a VM; tag `v3.0.0-rc.1`; PKGBUILD builds in container |
| 7 | B1 | `[edex-os]` repo builds; every package resolves |
| 8 | B2, B3 | ISO builds; UEFI + BIOS boot with `boot-ok`/`shell-ok` |
| 9 | B5 | nft lint; live bats tests; manual Tor/Tailscale on hardware |
| 10 | B4, B6 | Calamares loads clean; scripted install boots; CI all green |
| 11 | Docs, tags `eDEX-DE v3.0.0`, `eDEX-OS v1.0.0` | Release assets published; README claims cross-checked against the test list |

## Verification (end-to-end)
- eDEX-DE: `cargo test --workspace --locked`; CI `smoke-sway` job (surfaces, frames, toast, screenshot); manual under Hyprland (nested window works for development).
- eDEX-OS: `docker run --privileged -v $PWD:/workspace archlinux bash /workspace/scripts/ci-build-iso.sh`; `scripts/test-iso.sh --mode both`; `scripts/test-install.sh`; `tests/privacy/*`; manual Calamares install on UEFI and BIOS machines per release.

## Risks needing real hardware or not CI-verifiable
1. GPU/Vulkan under Hyprland (lavapipe in QEMU proves correctness only): test AMD/Intel/NVIDIA; wgpu GL fallback + adapter shown in About.
2. Hyprland 0.56 Lua API spelling (include mechanism, event names, `hl.config` nesting): verify in the container on day one of A4.
3. Aquamarine headless in CI may be unavailable; ISO QEMU test is the fallback coverage.
4. Tor bootstrap on GitHub runners: fail-closed tested without Tor; end-to-end locally. Tailscale exemption relies on tailscaled's `0x80000` fwmark.
5. fprintd: greeter PAM conversation unit-tested with a fake socket; real reader needed for the full path.
6. Calamares UI not driven automatically; module loading + scripted twin of its exec sequence are tested.
7. Package name drift (CachyOS/Arch renames): the container build fails loudly; `bump-desktop.yml` + weekly ISO build catch it.
8. Hosted-runner disk (~12 GB for mkarchiso): free-disk step; trim `multilib` if needed.

## Explicitly out of scope (documented, not stubbed)
Secure Boot (shim/MOK), ARM images, X11 sessions, hibernation setup by the installer (swap "suspend" choice offered but resume hook left to the user).
