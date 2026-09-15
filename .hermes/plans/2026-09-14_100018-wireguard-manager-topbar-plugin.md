# WireGuard Manager Omarchy Top-Bar Plugin Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Build a user-owned Omarchy Quickshell bar widget that discovers WireGuard `.conf` connections from `/etc/wireguard/`, shows their active state, and lets the user authenticate and toggle a selected connection on or off.

**Architecture:** Implement one `bar-widget` plugin following the Omarchy clock/bar-widget pattern: `BarWidget.qml` owns the top-bar button and loads `Panel.qml` for the connection list. A model/service layer performs read-only discovery and status checks, while privileged `wg-quick up/down` actions cross an explicit authentication boundary through `pkexec` (or a narrowly scoped installed helper if validation proves `pkexec` unsuitable). No plugin code should run a second Quickshell process, use shell-string interpolation, or silently retain root privileges.

**Tech Stack:** QML, QtQuick, Quickshell, Omarchy Quattro shell imports, JavaScript model logic, `wg`/`wg-quick`, `pkexec`, `qmllint`, Omarchy plugin validation, shell/Python test doubles as needed.

---

## Current context and assumptions

- Target checkout: `/home/alan-gerardo/src/wgomarchy`.
- The checkout currently exists as an empty non-Git directory; no existing source, test harness, package metadata, or CI configuration was found. Treat this as a greenfield plugin repository.
- Target runtime is the current Omarchy Quattro plugin contract documented at `https://plugins.omarchy.org/develop.html` and the official shell reference at `https://github.com/omacom/omarchy/blob/quattro/shell/README.md`.
- The plugin should be published as a normal Git repository with `manifest.json` at its root and installed under `~/.config/omarchy/plugins/<plugin-id>/`.
- Proposed permanent ID: `io.github.<author>.wireguard-manager`; replace `<author>` before publication. Do not use an `omarchy.*` third-party ID.
- The bar widget is a user-level process. Reading `/etc/wireguard/` and querying `wg show` are read-only operations; changing interfaces requires root authorization.
- Do not test against production or real patient data. WireGuard tests must use mocked commands and synthetic fixture names/configuration.

## Design decisions to preserve

1. Use `kinds: ["bar-widget"]` and `entryPoints.barWidget: "BarWidget.qml"`. The panel is loaded internally by the bar widget; do not declare a second standalone `panel` kind unless the Omarchy runtime requires it.
2. Discover only regular files ending in `.conf` directly under `/etc/wireguard/`; derive the display name from the basename. Reject path traversal, nested paths, symlinks, and unexpected filenames.
3. Never construct a shell command string from a connection name. Pass fixed executables and argument arrays to `Quickshell.Process`/the chosen process API.
4. Do not invoke `sudo` from the plugin. For a graphical shell action, first evaluate `pkexec` with a fixed executable and validated absolute config path. If `pkexec` cannot reliably run `wg-quick` with the required environment, add a separate, narrowly scoped helper with a documented polkit policy rather than broad sudoers access.
5. Only request authentication when the user clicks a toggle that needs root. Discovery and status refresh must not trigger an authentication prompt.
6. Treat operation completion as provisional until the process exits successfully and a subsequent status refresh confirms the expected state.
7. Keep the UI compact and Omarchy-native: `WidgetButton`, `Panel`, `KeyboardPanel`, `PanelKeyCatcher`, `Style`, `root.barForeground`, bar font settings, spacing helpers, and existing panel geometry conventions.

---

## Task 1: Establish repository metadata and plugin manifest

**Objective:** Create the minimal valid third-party plugin structure and explicit metadata.

**Files:**
- Create: `manifest.json`
- Create: `README.md`
- Create: `LICENSE` (license choice must be confirmed before publication)
- Create: `.gitignore`

**Steps:**

1. Write a manifest with `schemaVersion: 1`, the permanent namespaced ID placeholder, name `WireGuard Manager`, version `0.1.0`, author, license, description, `kinds: ["bar-widget"]`, and `entryPoints: { "barWidget": "BarWidget.qml" }`.
2. Set the bar widget metadata explicitly: `displayName`, category such as `Network`, `allowMultiple: false`, and `defaultSection: "right"`.
3. Document that the plugin is unsandboxed QML running inside `omarchy-shell`, reads `/etc/wireguard/`, invokes `wg` for status, and authenticates only for explicit toggle actions.
4. Document installation, enabling, moving the widget, required packages (`wireguard-tools`, `polkit`/desktop authentication agent), and removal.
5. Add only generated/cache artifacts to `.gitignore`; do not ignore source, manifests, or tests.
6. Validate JSON syntax and run `omarchy plugin validate <plugin-directory>` once the Omarchy tooling is available.

**Expected result:** The folder is recognizable as a valid Omarchy plugin before feature code is added.

---

## Task 2: Define the connection and command boundary in tests first

**Objective:** Lock down safe filename parsing, command construction, and state normalization before implementing QML behavior.

**Files:**
- Create: `tests/test_wireguard_model.py` (or a lightweight equivalent if the project standard is JavaScript-only)
- Create: `tests/fixtures/wireguard-list.txt`
- Create: `tests/fixtures/wg-show-output.txt`
- Create: `tests/README.md`

**Steps:**

1. Add tests for accepted names: `office.conf`, `home-lab.conf`, and names containing spaces if the process API supports argument-safe handling.
2. Add tests rejecting directories, symlinks, nested paths, names without `.conf`, names containing `/`, and shell metacharacters.
3. Add tests that map `office.conf` to exactly `/etc/wireguard/office.conf` and never to a user-controlled executable or shell expression.
4. Add tests for status parsing from `wg show interfaces` or the selected status command, including no active interfaces, one active interface, multiple active interfaces, and malformed output.
5. Add tests for state transitions: `inactive -> starting -> active`, `active -> stopping -> inactive`, command failure, timeout, and refresh failure.
6. Add tests proving no privileged command is emitted during initial discovery or periodic read-only refresh.

**Expected result:** Tests fail because the model and boundary functions do not yet exist; the failure should identify the intended API rather than a runtime/environment problem.

---

## Task 3: Implement safe discovery and read-only status model

**Objective:** Provide a deterministic model of available connections and active interfaces without privilege escalation.

**Files:**
- Create: `WireGuardModel.js` (or `WireGuardModel.qml` if the installed shell conventions favor a QML singleton)
- Modify: `tests/test_wireguard_model.py` and/or JavaScript tests

**Steps:**

1. Implement a fixed-path discovery operation for `/etc/wireguard/` that returns connection records with at least `name`, `configPath`, `active`, and `operationState`.
2. Ensure discovery is non-recursive and filters to regular `.conf` files. Preserve literal filenames for display, but use validated absolute paths for commands.
3. Implement status refresh using a fixed `wg` executable and argument list. Parse interface names defensively and match them to the config basename; document the limitation if interface names can differ from config names.
4. Decide and document the status source of truth. Preferred initial behavior: query `wg show interfaces` for active interface names and use the config basename as the mapping convention; if this is insufficient, use `wg-quick`/`ip` only as a read-only probe with tests.
5. Expose signals/properties for `loading`, `errorMessage`, `lastUpdated`, and an operation error that the panel can display without crashing the shell.
6. Refresh on panel open, after every toggle completion, and on a bounded timer while the panel remains open. Stop or reduce polling while closed.
7. Add a stale-data indicator when a refresh fails; do not report an interface as inactive merely because a status command failed.

**Expected result:** The model can list synthetic fixture connections and accurately represent active/inactive/unknown states without any authentication prompt.

---

## Task 4: Implement the privileged toggle executor

**Objective:** Add an explicit, auditable root boundary for `wg-quick up/down` actions.

**Files:**
- Create: `WireGuardPrivilegedRunner.js` (or a QML helper component)
- Create: `docs/security.md`
- Modify: `README.md`
- Modify: tests for command construction and result handling

**Steps:**

1. Implement a single toggle entry point accepting only a model record previously produced by validated discovery and the desired action (`up` or `down`).
2. Revalidate the config path immediately before execution: it must be a direct child of `/etc/wireguard/`, have a `.conf` suffix, and resolve to a regular non-symlink file according to the chosen validation mechanism.
3. Use an argument-vector process invocation, not `sh -c`, and use fixed executable paths. Proposed first implementation: `pkexec /usr/bin/wg-quick up|down /etc/wireguard/<validated-name>.conf`.
4. Do not pass arbitrary environment variables, terminal commands, or user-provided extra flags. Avoid `--` semantics unless verified against the installed `wg-quick` implementation.
5. Surface authentication cancellation, policy denial, missing polkit agent, missing `wg-quick`, non-zero exit, and timeout as distinct user-visible errors.
6. Mark the row as `starting`/`stopping` while the process is active; disable repeated clicks for that row and prevent concurrent operations on the same connection.
7. After a successful exit, call the read-only status refresh and only show `active`/`inactive` after confirmation. If confirmation is unavailable, show `unknown` plus the command result rather than claiming success.
8. Document the privilege trade-off. If `pkexec` fails because of the desktop policy or argument handling, stop and evaluate a dedicated root helper plus polkit rule; do not add unrestricted sudoers permissions as a shortcut.
9. Document that the plugin cannot guarantee exclusive control if users also run `wg-quick` or systemd-networkd manually.

**Expected result:** A user click can request authentication for exactly one validated connection action, with no background privilege requests and no arbitrary command execution.

---

## Task 5: Build the Omarchy bar widget entry point

**Objective:** Add a compact top-bar control that reflects aggregate WireGuard state and opens the panel.

**Files:**
- Create: `BarWidget.qml`
- Create: `tests/README.md` additions for manual bar checks

**Steps:**

1. Follow the current Omarchy clock plugin structure from the development guide: import `QtQuick`, `Quickshell`, and `qs.Ui`; instantiate `BarWidget`; set the same module ID in all components; load `Panel.qml` through a `Loader`.
2. Expose `open()`, `close()`, `toggle()`, `closeForPopoutSwitch()`, and panel injection methods expected by the Quattro bar lifecycle.
3. Use `WidgetButton` and Omarchy style properties rather than custom global colors or a second window.
4. Render a stable compact label/icon: for example, a WireGuard/network glyph plus `N` active count, with a tooltip such as `WireGuard: 1 active` or `WireGuard: unavailable`.
5. Make the button keyboard- and pointer-accessible, and ensure the panel closes correctly when switching bar panels.
6. Avoid doing filesystem or privileged work directly in the button component; delegate all work to the model/runner.

**Expected result:** The widget loads in the top bar, opens its panel, and communicates empty, active, loading, and error states without layout jumps.

---

## Task 6: Build the Omarchy-styled connection panel

**Objective:** Present each available connection with an understandable toggle control and safe status feedback.

**Files:**
- Create: `Panel.qml`
- Modify: `WireGuardModel.js`/`WireGuardModel.qml` as needed
- Create: `docs/ui-behavior.md`

**Steps:**

1. Follow the documented `Panel`, `KeyboardPanel`, and `PanelKeyCatcher` pattern. Anchor the surface to the bar button and use `Style.space(...)`, Omarchy fonts, foreground colors, and existing panel geometry.
2. Show a title, refresh timestamp/state, and a connection list sorted deterministically by display name.
3. Render one row per discovered `.conf` with connection name, `Active`/`Inactive`/`Unknown`/`Starting`/`Stopping` state, and one toggle button.
4. Make the toggle explicit: clicking an inactive row requests `up`; clicking an active row requests `down`; clicking an unknown row is disabled until refresh succeeds.
5. Display a clear authentication hint only when an operation is initiated: `Authentication required to enable <name>` or equivalent. Do not imply that Omarchy itself grants privilege.
6. Add empty and permission-error states: no `.conf` files, `/etc/wireguard/` unreadable, tools missing, status unavailable, and operation failed.
7. Add keyboard navigation, Escape-to-close, focus transfer on open, and accessible labels/tooltips for each toggle.
8. Prevent accidental activation from panel-open or row selection; only the toggle action may invoke the privileged runner.
9. Keep content width bounded so long filenames wrap or elide cleanly without overflowing the bar/panel.

**Expected result:** The panel feels native to Omarchy and makes authentication, current state, and failure state explicit.

---

## Task 7: Add static validation and test doubles

**Objective:** Make the plugin testable without changing a real WireGuard interface.

**Files:**
- Create: `tests/fakes/fake-wg`
- Create: `tests/fakes/fake-wg-quick`
- Create: `tests/fakes/fake-pkexec`
- Create: `tests/test_integration.py` or the project’s equivalent
- Modify: `README.md`

**Steps:**

1. Make fakes accept only the expected argument forms and record invocations to a temporary log.
2. Test discovery and status refresh against a temporary synthetic configuration directory or injected model path, never `/etc/wireguard/` on the host.
3. Test successful `up` and `down`, authentication cancellation, non-zero command exit, timeout, and post-operation state refresh.
4. Assert that no command contains `sh -c`, an unvalidated path, a second command separator, or arbitrary user input outside the validated config argument.
5. Keep privileged integration tests opt-in and isolated; default CI must not request authentication or alter the host network.
6. Add a test for status polling cancellation when the panel is closed.

**Expected result:** CI can exercise the behavior deterministically without root, network changes, or a desktop session.

---

## Task 8: Validate against the installed Omarchy runtime

**Objective:** Catch manifest, import, lifecycle, and visual/runtime issues that unit tests cannot detect.

**Files:**
- No new source files; update `docs/testing.md`

**Steps:**

1. Run:
   ```sh
   PLUGIN_ID="io.github.<author>.wireguard-manager"
   PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
   omarchy plugin validate "$PLUGIN_DIR"
   qmllint -I "$OMARCHY_PATH/shell" \
     "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
   ```
2. Discover/reload the plugin with `omarchy-shell shell rescanPlugins` and confirm it appears in `omarchy plugin list --json` with the expected ID, kind, and enabled state.
3. Place it in the bar with `omarchy bar move "$PLUGIN_ID" --section right` (or the exact supported syntax for the installed Omarchy version).
4. Manually test: empty directory, one inactive connection, one active connection, multiple connections, long names, unreadable directory, missing `wg`, missing `wg-quick`, authentication accepted, authentication canceled, command failure, refresh failure, Escape, focus navigation, shell reload, disable, re-enable, and removal.
5. Verify that shell restart does not leave stale process handles or duplicate panels.
6. Verify no second Quickshell process is started by the plugin and no authentication prompt occurs during idle polling.
7. Capture exact command output and environment limitations in `docs/testing.md`; do not claim a real toggle test unless it was explicitly run against a safe test interface.

**Expected result:** Manifest validation and `qmllint` pass, the plugin is discoverable/enabled, and manual lifecycle checks pass on the target Omarchy installation.

---

## Task 9: Documentation, packaging, and release readiness

**Objective:** Make installation, security review, and maintenance clear before publishing.

**Files:**
- Modify: `README.md`
- Modify: `docs/security.md`
- Modify: `docs/testing.md`
- Create: `CHANGELOG.md`
- Create: `CONTRIBUTING.md` (optional if accepting contributions)

**Steps:**

1. Document exact install/enable/move/remove commands, including `--yes` only for scripted installation after code review.
2. Document required runtime assumptions: Omarchy Quattro, Quickshell imports, `wireguard-tools`, `pkexec`, a working polkit authentication agent, and readable `/etc/wireguard/`.
3. Explain the unsandboxed plugin risk and every external command invoked.
4. State the limitation that `wg-quick down` may not be the correct owner operation when another service manages the interface; recommend one owner per interface.
5. Add troubleshooting for authentication denial, missing agent, permission errors, stale status, interface/config name mismatch, and command conflicts.
6. Pin the first release version only after validation; include a changelog entry describing the privilege boundary and known limitations.
7. Run the complete test suite, manifest validation, `qmllint`, and a clean-tree check before tagging or publishing.

**Expected result:** A reviewer can understand exactly what code runs in the shell, when root is requested, and how to install or remove it safely.

---

## Proposed file tree

```text
/home/alan-gerardo/src/wgomarchy/
├── manifest.json
├── BarWidget.qml
├── Panel.qml
├── WireGuardModel.js              # or .qml singleton, chosen during Task 3
├── WireGuardPrivilegedRunner.js   # or QML helper, chosen during Task 4
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── docs/
│   ├── security.md
│   ├── testing.md
│   └── ui-behavior.md
└── tests/
    ├── fixtures/
    ├── fakes/
    ├── test_wireguard_model.py
    └── test_integration.py
```

## Verification checklist

- [ ] `manifest.json` parses and `omarchy plugin validate` passes.
- [ ] `qmllint` passes with the installed Omarchy shell import path.
- [ ] Unit tests cover filename/path safety, status parsing, operation states, and all failure classes.
- [ ] Default tests never request authentication or modify a host WireGuard interface.
- [ ] Privileged operations use only fixed executables, validated direct-child config paths, and argument arrays.
- [ ] Authentication is requested only after an explicit toggle click.
- [ ] Successful commands are followed by a status refresh before the UI claims the target state.
- [ ] Panel open/close, Escape, keyboard navigation, bar switching, shell reload, disable/re-enable, and removal are manually verified.
- [ ] No second Quickshell process is launched.
- [ ] README and security documentation enumerate commands, dependencies, privilege behavior, and known ownership conflicts.
- [ ] Final Git diff contains only intended plugin files; no secrets, host configs, logs, or test artifacts are included.

## Risks, trade-offs, and open questions

- **`pkexec` compatibility:** The first implementation should validate whether the installed polkit policy permits `pkexec wg-quick ...` with the required environment. If not, use a minimal helper and polkit rule rather than broad sudoers access. This is the primary implementation gate.
- **Interface-name mapping:** A WireGuard config basename normally maps to the interface name used by `wg-quick`, but custom naming or another network manager can break that assumption. The model must show `Unknown` rather than infer state incorrectly.
- **Concurrent ownership:** systemd-networkd, NetworkManager, or another user process may own the interface. The UI should report command failures and document that the plugin is not an ownership coordinator.
- **QML process API drift:** Confirm the exact `Quickshell.Process` API and Omarchy imports from the installed shell examples before coding; do not copy an outdated API signature from this plan.
- **Privilege and symlink races:** Discovery-time validation can be invalidated before execution. Revalidate at action time and consider an installed helper that performs final `openat`/ownership checks if the threat model requires protection against local filesystem races.
- **Polling cost:** Keep refresh bounded and panel-scoped so the always-running shell does not spawn frequent subprocesses while the panel is closed.
- **No existing project harness:** Because the checkout is empty and non-Git, the implementer must choose and document the smallest practical test runner. Avoid adding a heavy framework unless QML integration requires it.
