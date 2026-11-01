# WireGuard Manager for Omarchy

WireGuard Manager is an Omarchy 4 bar-widget plugin for observing a fixed list
of `wg-quick` connections in `/etc/wireguard/` and explicitly enabling or
disabling one connection with `wg-quick`.

This fork replaces upstream's directory scan with a fixed list (`CONNECTIONS`
in `WireGuardModel.js`, currently `wg-servers`). `/etc/wireguard/` stays
root-only: the plugin never reads it, and no ACL is needed. Toggles are refused
for any name not in the list.

It runs unsandboxed inside the existing `omarchy-shell` process. The status
check is read-only: `/usr/bin/wg show interfaces` needs no authentication. A
toggle is the only privileged action and passes a fixed argv array to
`/usr/bin/pkexec /usr/bin/wg-quick up|down /etc/wireguard/<name>.conf`.
Connection names are restricted to `[A-Za-z0-9_=+.-]{1,15}`. No shell string
interpolation is used.

## Install

Review this repository, then install it as a normal Omarchy plugin:

```sh
omarchy plugin add https://github.com/gigor/omarchy-wireguard-manager.git --enable
omarchy bar move io.github.alansnchz0.wireguard-manager --section right
```

Requirements are Omarchy 4.0.3-compatible Quickshell, `wireguard-tools`,
`pkexec`, and a desktop polkit authentication agent. On Arch Linux, install
the package-backed requirements with:

```sh
sudo pacman -S --needed wireguard-tools polkit
```

The `polkit` package provides `pkexec`. Verify the versioned and runtime
requirements with:

```sh
omarchy version
quickshell --version
command -v wg wg-quick pkexec
```

`wg-quick` also needs `resolvconf` (`systemd-resolvconf`) when a profile
contains a `DNS=` setting. A desktop polkit authentication agent must be
running in the graphical session for toggle authentication dialogs to appear.

## Uninstall

Remove the plugin with:

```sh
omarchy plugin remove io.github.alansnchz0.wireguard-manager
```

## Development checks

```sh
node tests/node_test_wireguard_model.js
omarchy plugin validate .
```

See [docs/security.md](docs/security.md), [docs/ui-behavior.md](docs/ui-behavior.md),
and [docs/testing.md](docs/testing.md) for the security boundary and runtime
limitations.
