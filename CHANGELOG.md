# Changelog

## Fork (gigor)

- Replace the `/etc/wireguard` directory scan with a fixed `CONNECTIONS` list
  (`wg-servers`), so the directory stays root-only and needs no ACL.
- Refuse toggles for names outside the list.
- Drop the pre-toggle `find` check on the config file, which needed the ACL.

## 0.1.0

- Initial Omarchy bar widget with fixed-argv discovery and pkexec toggle boundary.
- Added host-safe Node tests and opt-in command fakes.
