# WireGuard Manager for Omarchy

WireGuard Manager is an Omarchy 4 bar-widget plugin for observing `.conf`
connections in `/etc/wireguard/` and explicitly enabling or disabling one
connection with `wg-quick`.

It runs unsandboxed inside the existing `omarchy-shell` process. Discovery is
read-only: it uses `/usr/bin/find` directly under `/etc/wireguard/` and
`/usr/bin/wg show interfaces`; neither operation requests authentication. A
toggle is the only privileged action and passes a fixed argv array to
`/usr/bin/pkexec /usr/bin/wg-quick up|down /etc/wireguard/<name>.conf`.
Connection names are restricted to `[A-Za-z0-9_=+.-]{1,15}`. No shell string
interpolation is used.

## Install

Review this repository, then install it as a normal Omarchy plugin:

```sh
# From a repository URL supplied by your package/release source:
omarchy plugin add https://github.com/alansnchz0/omarchy-wireguard-manager.git --enable
omarchy bar move io.github.alansnchz0.wireguard-manager --section right
```

Requirements are Omarchy 4.0.3-compatible Quickshell, `wireguard-tools`,
`systemd-resolvconf`, `pkexec`, a desktop polkit authentication agent, and a
readable `/etc/wireguard/` directory. On Arch Linux, install the package-backed
requirements with:

```sh
sudo pacman -S --needed wireguard-tools systemd-resolvconf polkit acl
```

The `polkit` package provides `pkexec`, and `acl` provides `setfacl`. Verify the
versioned and runtime requirements with:

```sh
omarchy version
quickshell --version
command -v wg wg-quick resolvconf pkexec setfacl
test -d /etc/wireguard && test -r /etc/wireguard && test -x /etc/wireguard
```

`resolvconf` is required by `wg-quick` when a profile contains a `DNS=` setting.
A desktop polkit authentication agent must also be running in the graphical
session for toggle authentication dialogs to appear.

The plugin also needs to enumerate configuration filenames without requesting
root authentication during discovery. For example, grant the user directory
read/traverse access with:

```sh
sudo setfacl -m u:<YOUR_SYSTEM_USERNAME>:rx /etc/wireguard
```

This allows the plugin to list files such as `wg0.conf` and `wg1.conf` without
granting read access to the configuration contents.

## Uninstall

Remove the plugin with:

```sh
omarchy plugin remove io.github.alansnchz0.wireguard-manager
```

Removing the plugin does not revoke the ACL. Remove it separately with:

```sh
sudo setfacl -x u:<YOUR_SYSTEM_USERNAME> /etc/wireguard
```

## Development checks

```sh
node tests/node_test_wireguard_model.js
omarchy plugin validate .
```

See [docs/security.md](docs/security.md), [docs/ui-behavior.md](docs/ui-behavior.md),
and [docs/testing.md](docs/testing.md) for the security boundary and runtime
limitations.
