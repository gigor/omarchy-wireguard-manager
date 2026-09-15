# UI behavior

The top bar shows `WG N`, where `N` is the number of interfaces confirmed by
`wg show interfaces`. Clicking opens an Omarchy `KeyboardPanel`. The panel
refreshes on open and every five seconds while open; Escape closes it and `R`
refreshes it. Closing stops polling.

Rows are sorted by validated config basename. The basename from discovery is
mapped to the fixed path `/etc/wireguard/<basename>.conf`; no alternate config
directory is accepted. Each row shows Active, Inactive,
Unknown, Starting, Stopping, or Failed. Unknown rows cannot be toggled. The
Failed state remains visible through the refresh following an unsuccessful or
unconfirmed action; once refreshed status is known, the row can be retried. The
authentication hint appears only after a toggle is initiated. Empty,
unreadable, missing-tool, stale-status, and operation-failure states are shown
as text rather than treated as inactive.
