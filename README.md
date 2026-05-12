# chimera-rice

minimal & clean bspwm desktop for [Chimera Linux](https://chimera-linux.org/)

```
bspwm + sxhkd + polybar + rofi + picom + alacritty + dunst
theme: Catppuccin Mocha
```

## install

```sh
git clone https://github.com/mosudogit/chimera-rice
cd chimera-rice
chmod +x install.sh
./install.sh
```

then start X:

```sh
startx
# or via display manager:
doas dinitctl start xdm
```

## keybinds

| keys | action |
|------|--------|
| `super + enter` | terminal |
| `super + d` | rofi launcher |
| `super + q` | close window |
| `super + m` | monocle toggle |
| `super + f` | fullscreen |
| `super + shift + space` | float toggle |
| `super + h/j/k/l` | focus direction |
| `super + shift + h/j/k/l` | move window |
| `super + 1-9` | switch workspace |
| `super + shift + 1-9` | send to workspace |
| `super + shift + l` | lockscreen |
| `super + alt + r` | restart bspwm |

## what gets installed

- **bspwm** — tiling WM
- **sxhkd** — hotkey daemon
- **picom** — compositor (blur, shadows, rounded corners, fade)
- **polybar** — bar (workspaces, clock, cpu, ram, volume, network)
- **rofi** — launcher
- **dunst** — notifications
- **alacritty** — terminal (falls back to foot → xterm)
- **feh** — wallpaper
- **i3lock** — lockscreen
- **JetBrainsMono Nerd Font** — font

## safe to re-run

configs are backed up to `~/.config-backup-<timestamp>` before overwriting.

## requirements

- Chimera Linux + apk
- doas or sudo
- Xorg compatible GPU
