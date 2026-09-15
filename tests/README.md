# Tests

The default test command is `node tests/node_test_wireguard_model.js`. It runs
without Quickshell, root, polkit, or a live WireGuard interface. The test loads
the same pure JavaScript boundary functions used by the QML components and
also asserts that discovery never contains a privileged command.

The fakes are opt-in and only accept synthetic paths under
`/tmp/wgomarchy-wireguard-test`. They record argv-shaped invocations and never
call the host `wg-quick`.
