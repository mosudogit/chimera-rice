cat > /mnt/user-data/outputs/install.sh << 'ENDOFFILE'
#!/usr/bin/env bash
# =============================================================================
# void-rice installer  —  bspwm minimal/clean setup for Void Linux
# =============================================================================
# package manager : xbps-install
# init system     : runit  (services via /etc/runit/runsvdir/default/)
# privilege       : sudo or doas
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"
LOG="$HOME/.void-rice-install.log"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

: > "$LOG"

# ── colours ──────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' N='\033[0m'

_msg() { local c="$1" l="$2"; shift 2; printf "${c}${l}${N} %s\n" "$*" | tee -a "$LOG"; }
log()  { _msg "$G" "[+]" "$@"; }
warn() { _msg "$Y" "[!]" "$@"; }
err()  { _msg "$R" "[x]" "$@"; }
die()  { err "$@"; exit 1; }
step() { printf "\n${C}══${W} %s ${C}══${N}\n" "$*" | tee -a "$LOG"; }

# ── privilege ────────────────────────────────────────────────────────────────
if   [ "$(id -u)" -eq 0 ];        then _root() { "$@"; }
elif command -v sudo &>/dev/null;  then _root() { sudo "$@"; }
elif command -v doas &>/dev/null;  then _root() { doas "$@"; }
else die "need root, sudo, or doas"; fi

# ── xbps helpers ─────────────────────────────────────────────────────────────
XBPS_WALL=300   # wall-clock timeout per install call

_xi() {
  # xbps-install: -y = yes to all, -S = sync repos first (only on update call)
  _root timeout "$XBPS_WALL" xbps-install -y "$@"
}

xbps_update() {
  log "xbps-install -Su (sync + update)"
  _root timeout "$XBPS_WALL" xbps-install -Syu >> "$LOG" 2>&1 \
    || die "xbps sync/update failed — check network"
}

# xbps_add: required packages — die on failure
xbps_add() {
  log "installing: $*"
  _xi "$@" >> "$LOG" 2>&1 || die "required packages failed: $*"
}

# xbps_try: optional — each pkg independently, warn on miss, never die
xbps_try() {
  local pkg rc
  for pkg in "$@"; do
    rc=0
    _root timeout "$XBPS_WALL" xbps-install -y "$pkg" >> "$LOG" 2>&1 || rc=$?
    [ "$rc" -eq 0 ] && log "  ok: $pkg" || warn "  optional not found: $pkg"
  done
  return 0
}

# xbps_first: install first pkg from list that succeeds; warn if none, never die
xbps_first() {
  local pkg rc
  for pkg in "$@"; do
    rc=0
    _root timeout "$XBPS_WALL" xbps-install -y "$pkg" >> "$LOG" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
      log "  installed (first available): $pkg"
      return 0
    fi
    warn "  not available: $pkg"
  done
  warn "  none of [$*] installed — install one manually"
  return 0
}

# ── backup ────────────────────────────────────────────────────────────────────
backup_existing() {
  step "backing up existing configs"
  mkdir -p "$BACKUP_DIR"
  local d
  for d in bspwm sxhkd polybar rofi alacritty picom dunst; do
    [ -d "$HOME/.config/$d" ] && {
      cp -r "$HOME/.config/$d" "$BACKUP_DIR/$d"
      log "backed up: ~/.config/$d"
    }
  done
  [ -f "$HOME/.xinitrc" ] && {
    cp "$HOME/.xinitrc" "$BACKUP_DIR/.xinitrc"
    log "backed up: ~/.xinitrc"
  }
  log "backup dir: $BACKUP_DIR"
}

# ── packages ──────────────────────────────────────────────────────────────────
install_packages() {
  xbps_update

  step "core X11"
  # xorg-minimal = lean xorg; xinit provides startx; xorg includes xinit already
  # but we name both to be safe — xbps dedupes
  xbps_add xorg-minimal xinit xorg-fonts

  step "input drivers"
  xbps_try xf86-input-libinput xf86-input-evdev

  step "GPU drivers (intel — change if AMD/nvidia)"
  xbps_try xf86-video-intel
  # AMD:    xbps_try xf86-video-amdgpu
  # NVIDIA: xbps_try nvidia (non-free repo required)

  step "WM + hotkeys + compositor"
  xbps_add bspwm sxhkd picom

  step "bar + launcher + notifications"
  xbps_add polybar rofi dunst

  step "terminal (first available)"
  xbps_first alacritty foot xterm rxvt-unicode

  step "fonts"
  # nerd-fonts is the void meta pkg; noto-fonts-ttf + noto-fonts-emoji for fallback
  xbps_try nerd-fonts noto-fonts-ttf noto-fonts-emoji dejavu-fonts-ttf

  step "lockscreen + wallpaper"
  xbps_try i3lock
  xbps_first feh nitrogen

  step "screenshot + clipboard"
  xbps_try maim xdotool xclip xsel scrot

  step "media + brightness controls"
  xbps_try playerctl brightnessctl pamixer pavucontrol

  step "file manager"
  xbps_first Thunar pcmanfm lf ranger

  step "session / polkit helpers"
  xbps_try lxpolkit polkit
  xbps_try NetworkManager network-manager-applet

  log "all packages done"
}

# ── dotfiles ──────────────────────────────────────────────────────────────────
# rm -rf dest before cp — prevents nested dirs on re-runs
deploy_dir() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    warn "source missing: $src  (skipping)"
    return 0
  fi
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$src" "$dest"
  log "deployed: $dest"
}

install_dotfiles() {
  step "deploying dotfiles"
  mkdir -p "$HOME/.config"

  deploy_dir "$DOTFILES_DIR/bspwm"     "$HOME/.config/bspwm"
  deploy_dir "$DOTFILES_DIR/sxhkd"     "$HOME/.config/sxhkd"
  deploy_dir "$DOTFILES_DIR/polybar"   "$HOME/.config/polybar"
  deploy_dir "$DOTFILES_DIR/rofi"      "$HOME/.config/rofi"
  deploy_dir "$DOTFILES_DIR/alacritty" "$HOME/.config/alacritty"
  deploy_dir "$DOTFILES_DIR/picom"     "$HOME/.config/picom"
  deploy_dir "$DOTFILES_DIR/dunst"     "$HOME/.config/dunst"

  [ -f "$HOME/.config/bspwm/bspwmrc" ]     && chmod +x "$HOME/.config/bspwm/bspwmrc"
  [ -f "$HOME/.config/polybar/launch.sh" ]  && chmod +x "$HOME/.config/polybar/launch.sh"

  # wallpapers
  mkdir -p "$HOME/.local/share/wallpapers"
  local found=0
  if [ -d "$WALLPAPER_DIR" ]; then
    for wp in "$WALLPAPER_DIR"/*; do
      [ -f "$wp" ] || continue
      cp "$wp" "$HOME/.local/share/wallpapers/"
      found=1
    done
  fi
  [ "$found" -eq 1 ] \
    && log "wallpapers copied to ~/.local/share/wallpapers" \
    || warn "no wallpapers in $WALLPAPER_DIR — set one manually with feh"

  write_xinitrc
}

write_xinitrc() {
  step "writing ~/.xinitrc"
  # Void uses ~/.xinitrc not ~/.xsession
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" << 'XEOF'
#!/bin/sh
# void-rice xinitrc

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=bspwm

[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# dbus session (needed by dunst, polkit, nm-applet etc)
if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# polkit agent
command -v lxpolkit >/dev/null 2>&1 && lxpolkit &

# notification daemon
command -v dunst >/dev/null 2>&1 && {
  pkill -x dunst 2>/dev/null || true
  dunst &
}

# bspwmrc handles compositor + bar + sxhkd
exec bspwm
XEOF
  mv "$tmp" "$HOME/.xinitrc"
  chmod +x "$HOME/.xinitrc"
  log ".xinitrc written"
}

# ── runit services ────────────────────────────────────────────────────────────
# Void runit: enable = symlink /etc/sv/<svc> -> /etc/runit/runsvdir/default/
enable_services() {
  step "enabling runit services"
  local svc rc
  # dbus is needed for most graphical apps
  for svc in dbus NetworkManager; do
    rc=0
    [ -d "/etc/sv/$svc" ] || { warn "service not found: $svc"; continue; }
    _root ln -sf "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc" 2>>"$LOG" || rc=$?
    [ "$rc" -eq 0 ] \
      && log "enabled: $svc" \
      || warn "could not enable $svc (may already be enabled)"
  done
  log "runit services done"
}

# ── summary ───────────────────────────────────────────────────────────────────
print_done() {
  printf "\n"
  printf "${G}╔════════════════════════════════════════════╗${N}\n"
  printf "${G}║    void-rice installed successfully  ✓     ║${N}\n"
  printf "${G}╚════════════════════════════════════════════╝${N}\n\n"
  printf "  ${W}start X:${N}           startx\n\n"
  printf "  ${W}super + enter${N}      terminal\n"
  printf "  ${W}super + d${N}          rofi launcher\n"
  printf "  ${W}super + q${N}          close window\n"
  printf "  ${W}super + shift + l${N}  lockscreen\n"
  printf "  ${W}super + alt + r${N}    restart bspwm\n\n"
  printf "  ${W}backup:${N}  $BACKUP_DIR\n"
  printf "  ${W}log:${N}     $LOG\n\n"
}

# ── entry ─────────────────────────────────────────────────────────────────────
main() {
  printf "${C}void-rice installer${N}\n"
  printf "log: %s\n\n" "$LOG"
  backup_existing
  install_packages
  install_dotfiles
  enable_services
  print_done
}

main "$@"
ENDOFFILE
echo "done"
