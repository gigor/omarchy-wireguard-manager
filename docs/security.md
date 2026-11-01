# Security boundary

This plugin is unsandboxed QML loaded into the long-running `omarchy-shell`.
It has no privilege of its own. Connections come from the fixed `CONNECTIONS`
list in `WireGuardModel.js`; the plugin never reads `/etc/wireguard/`, which
stays root-only. The read-only status check runs `/usr/bin/wg show interfaces`
with fixed arguments. To notice tunnels going up or down, it keeps one
`/usr/bin/ip -o monitor link` running per bar; that only listens to interface
change events, needs no privileges, and its output is used solely as a cue to
re-run the status check.

Only an explicit row button constructs a privileged argv:

```text
/usr/bin/pkexec /usr/bin/wg-quick up|down /etc/wireguard/<validated-name>.conf
```

The name is checked immediately before command construction: it must be in
`CONNECTIONS` and is limited to 1–15 ASCII characters from `[A-Za-z0-9_=+.-]`.
The command never uses `sh -c`, shell interpolation, sudo, arbitrary
environment variables, or extra flags. The config file is not pre-checked:
only root can read or change `/etc/wireguard/`, and `wg-quick` reports a
missing file as a failed operation.

`pkexec` may show an authentication dialog only after a toggle click. A user
cancel, policy denial, missing agent, missing executable, or non-zero command
exit is surfaced as an operation failure. A successful command is followed by
a fresh unprivileged status query before the model reports the final state.

The plugin cannot prevent another process, NetworkManager, or
systemd-networkd from owning the same interface. Use one owner per interface;
`wg-quick down` may conflict with a separately managed interface.
