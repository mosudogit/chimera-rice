#!/usr/bin/env bash
# =============================================================================
# chimera-rice installer  —  bspwm minimal/clean setup for Chimera Linux
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
WALLPAPER_DIR="$SCRIPT_DIR/wallpapers"
LOG="$HOME/.chimera-rice-install.log"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

: > "$LOG"

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' N='\033[0m'

_msg() { local c="$1" l="$2"; shift 2; printf "${c}${l}${N} %s\n" "$*" | tee -a "$LOG"; }
log()  { _msg "$G" "[+]" "$@"; }
warn() { _msg "$Y" "[!]" "$@"; }
err()  { _msg "$R" "[x]" "$@"; }
die()  { err "$@"; exit 1; }
step() { printf "\n${C}══${W} %s ${C}══${N}\n" "$*" | tee -a "$LOG"; }

if   [ "$(id -u)" -eq 0 ];        then _root() { "$@"; }
elif command -v doas &>/dev/null;  then _root() { doas "$@"; }
elif command -v sudo &>/dev/null;  then _root() { sudo "$@"; }
else die "need root, doas, or sudo"; fi

APK_WALL=300
APK_NET=60

_apk() {
  _root timeout "$APK_WALL" \
    apk --no-interactive --timeout="$APK_NET" "$@"
}

apk_update() {
  log "apk update"
  _apk update >> "$LOG" 2>&1 || die "apk update failed — check network"
}

apk_add() {
  log "apk add $*"
  _apk add "$@" >> "$LOG" 2>&1 || die "required packages failed: $*"
}

apk_try() {
  local pkg rc
  for pkg in "$@"; do
    rc=0
    _apk add "$pkg" >> "$LOG" 2>&1 || rc=$?
    [ "$rc" -eq 0 ] && log "  ok: $pkg" || warn "  optional missing: $pkg"
  done
  return 0
}

apk_first() {
  local pkg rc
  for pkg in "$@"; do
    rc=0
    _apk add "$pkg" >> "$LOG" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
      log "  installed (first available): $pkg"
      return 0
    fi
    warn "  not available: $pkg"
  done
  warn "  none of [$*] installed — install one manually"
  return 0
}

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
  [ -f "$HOME/.xsession" ] && {
    cp "$HOME/.xsession" "$BACKUP_DIR/.xsession"
    log "backed up: ~/.xsession"
  }
  log "backup dir: $BACKUP_DIR"
}

install_packages() {
  apk_update

  step "core X11"
  apk_add xserver-xorg xorg-xinit dbus elogind seatd

  step "WM + compositor"
  apk_add bspwm sxhkd picom

  step "bar + launcher + notifications"
  apk_add polybar rofi dunst

  step "terminal (first available)"
  apk_first alacritty foot xterm rxvt-unicode

  step "fonts"
  apk_try font-jetbrains-mono-nerd font-noto font-noto-emoji font-dejavu font-liberation

  step "lockscreen + wallpaper"
  apk_try i3lock
  apk_first feh nitrogen

  step "screenshot + clipboard"
  apk_try maim xdotool xclip xsel

  step "media controls"
  apk_try playerctl brightnessctl pamixer pavucontrol

  step "file manager"
  apk_first thunar pcmanfm lf ranger

  step "session helpers"
  apk_try lxpolkit network-manager-applet

  log "all packages done"
}

deploy_dir() {
  local src="$1" dest="$2"
  if [ ! -d "$src" ]; then
    warn "source dir missing: $src  (skipping)"
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
    && log "wallpapers copied" \
    || warn "no wallpapers in $WALLPAPER_DIR — set one manually with feh"

  write_xsession
}

write_xsession() {
  step "writing ~/.xsession"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" << 'XEOF'
#!/bin/sh
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=bspwm

[ -f "$HOME/.profile" ] && . "$HOME/.profile"

if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

if [ -S /run/seatd.sock ]; then
  export LIBSEAT_BACKEND=seatd
else
  export LIBSEAT_BACKEND=elogind
fi

command -v lxpolkit >/dev/null 2>&1 && lxpolkit &

command -v dunst >/dev/null 2>&1 && {
  pkill -x dunst 2>/dev/null || true
  dunst &
}

exec bspwm
XEOF
  mv "$tmp" "$HOME/.xsession"
  chmod +x "$HOME/.xsession"
  log ".xsession written"
}

enable_services() {
  step "enabling dinit services"
  local svc rc
  for svc in dbus elogind seatd; do
    rc=0
    _root dinitctl enable "$svc" >> "$LOG" 2>&1 || rc=$?
    [ "$rc" -eq 0 ] \
      && log "enabled: $svc" \
      || warn "could not enable $svc (may already be enabled)"
  done
}

print_done() {
  printf "\n"
  printf "${G}╔════════════════════════════════════════════╗${N}\n"
  printf "${G}║   chimera-rice installed successfully  ✓   ║${N}\n"
  printf "${G}╚════════════════════════════════════════════╝${N}\n\n"
  printf "  ${W}start X:${N}           startx\n"
  printf "  ${W}via display mgr:${N}   doas dinitctl start xdm\n\n"
  printf "  ${W}super + enter${N}      terminal\n"
  printf "  ${W}super + d${N}          rofi launcher\n"
  printf "  ${W}super + q${N}          close window\n"
  printf "  ${W}super + shift + l${N}  lockscreen\n\n"
  printf "  ${W}backup:${N}  $BACKUP_DIR\n"
  printf "  ${W}log:${N}     $LOG\n\n"
}

main() {
  printf "${C}chimera-rice installer${N}\n"
  printf "log: %s\n\n" "$LOG"
  backup_existing
  install_packages
  install_dotfiles
  enable_services
  print_done
}

main "$@"
