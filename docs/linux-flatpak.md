# Linux Flatpak

Releases may ship `gen1recomp-<version>-linux.flatpak` (x86_64 bundle).

## Install

```sh
flatpak install --user ./gen1recomp-<version>-linux.flatpak
flatpak run com.theboisclub.gen1recomp
```

Or open the `.flatpak` in Discover / GNOME Software. AppStream metainfo
includes a `<releases>` entry so those UIs can show the version.

## Permissions

The manifest requests:

- network (updater, mods, save sync)
- X11 / Wayland / DRI / PulseAudio
- `--device=all` (SDL2 gamepads, rumble, gyro via evdev/hidraw)
- `--filesystem=home` (ROM import)

Curl is bundled at `/app/bin/curl` so the game does not need host curl.

## Updates

Lua/engine payloads still use the in-app `.love` updater. A native shell bump
points at the new `.flatpak` asset (`Download Flatpak update`).

After a `.love` payload download, restart uses `love.event.quit("restart")`
(`execv` of `/proc/self/exe` inside bwrap). If a restart hangs after an
update, fully quit and relaunch — PhysFS can retain a lock on the previous
payload across a bad handoff.

## Building

```sh
scripts/build_flatpak.sh --version X.Y.Z
# → dist/flatpak/gen1recomp-X.Y.Z-linux.flatpak
```

Requires `flatpak` + `flatpak-builder` and the Freedesktop 24.08 runtime from
Flathub (installed automatically on first build).

Release CI builds the bundle on `ubuntu-24.04` (`linux-flatpak` job) from the
shared `game.love` payload and publishes `gen1recomp-<ver>-linux.flatpak`
alongside the AppImages. PR CI path-gates the same script when `flatpak/` or
`scripts/build_flatpak.sh` change.

Flathub store submission is out of scope for the GitHub bundle channel.
