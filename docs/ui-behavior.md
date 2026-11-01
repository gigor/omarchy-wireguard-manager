# UI behavior

The top bar shows `WG`, dimmed like the Tailscale icon unless a listed
connection is up; its tooltip counts the interfaces confirmed by
`wg show interfaces`. Status re-checks whenever an interface appears,
disappears or changes (so tunnels toggled from a terminal show up too), with
no polling. Clicking opens an Omarchy `KeyboardPanel`, laid out like the
built-in Tailscale panel. The panel refreshes on open; Escape closes it,
`R` refreshes it, Tab switches to the neighbouring bar panel, and arrow keys
then Enter (or `T`) toggle the selected connection. The panel can also be
opened over IPC: `omarchy-shell io.github.alansnchz0.wireguard-manager toggle`.

Each name in `CONNECTIONS` gets a header (`PanelHero`): an icon, the name as
the title, a status line, and an on/off switch. Each name is mapped to the
fixed path `/etc/wireguard/<name>.conf`; no alternate config directory is
accepted. The status line reads Connected, Disconnected, Connecting,
Disconnecting, Failed, or Status unknown. Unknown connections cannot be
toggled. The Failed state remains visible through the refresh following an
unsuccessful or unconfirmed action; once refreshed status is known, the switch
can be retried. A line under the header shows the password prompt while an
action runs, otherwise the last failure (status unavailable, action failed).
