# Testing and runtime validation

The default suite is deliberately host-safe:

```sh
node tests/node_test_wireguard_model.js
omarchy plugin validate .
```

The Node test uses synthetic strings and verifies the fixed argv boundary. The
fake commands under `tests/fakes/` accept only expected arguments and paths
under `/tmp/wgomarchy-wireguard-test`; they do not invoke real `wg-quick`.

On the installed target, use the following only after reviewing the source:

```sh
omarchy plugin validate "$PWD"
qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml
omarchy-shell shell rescanPlugins
omarchy plugin list --json
```

This checkout has Omarchy 4.0.3 and Quickshell 0.3.1, but no `qmllint` binary
was available during implementation. A graphical shell session, configured
polkit agent, and a safe test WireGuard interface are required for manual
toggle verification; none is invoked by the default tests. The plugin has not
been installed into user configuration and has not changed host network state.

The Node checks cover the QML state-machine contracts statically because no
QML linter is available: failed privileged operations return to idle, status
confirmation is bounded, stale rows are disabled, and delegate status uses the
outer model state. Discovery emits `%f` basenames; each validated basename
maps immutably to `/etc/wireguard/<basename>.conf`.
