# Plugin Marketplace

## Runtime Shape

- This directory is the live user plugin at `~/.config/omarchy/plugins/io.yasino55.omarchy-plugin-marketplace`; saves normally hot-reload the long-running Omarchy Quickshell process.
- `manifest.json` exposes only `MarketplaceButton.qml` as the `barWidget`. The button's always-active `Loader` owns `Marketplace.qml` and forwards `open`, `close`, and `toggle`, which is how `omarchy-shell` IPC reaches the overlay.
- `MarketplaceModel.js` contains the shared catalog filtering, sorting, and URL validation helpers. Keep reusable catalog rules there rather than duplicating them in delegates.
- There is no dependency install, build, test, lint, formatter, or CI configuration in this project.

## Verification

- Run `omarchy plugin validate .` after changing the manifest or entrypoint layout; success is silent.
- With the Omarchy shell running and the widget enabled, smoke-test the overlay with `omarchy-shell shell toggle io.yasino55.omarchy-plugin-marketplace '{}'`.
- Plugin files should reload on save. If they do not, force discovery and reload with `omarchy-shell shell rescanPlugins`.

## Catalog And Installation

- The remote catalog must have an integer `stateSchemaVersion >= 1` and a `plugins` array. Entries are validated field-by-field (`id`, `name`, `repo`, `installAvailable`, `sourceType`) before display or install; only entries whose `sourceType` is absent or `community` are displayed.
- Views, copies, and hearts come from the separate read-only `https://api.omarchyplugins.com/v1/stats` response. Keep those sort options unavailable until its `schemaVersion === 1` payload parses successfully; catalog browsing must still work if this optional request fails.
- Installation is intentionally gated by both `installAvailable === true` and `MarketplaceModel.repoIsSafe()`, which accepts only a bare GitHub HTTPS repository URL. Preserve the checks in display-model construction, install request, and confirmation; they are defense in depth around execution of remote catalog data.
- Keep external commands as `Process.command` argument arrays, never shell-built strings. Installation uses `plugin-add-checked` to validate the catalog id before moving the checkout, then persists discovery/enable intent across the required plugin rescan. Installed state comes from `omarchy plugin list --json`.
- The Manage view includes first-party and user plugins. Only user plugins can be removed, only Git-managed user plugins can be updated, and enabling or updating third-party code requires confirmation. Keep self-management of `io.yasino55.omarchy-plugin-marketplace` disabled, and send full-bar activation plus active-bar update/removal to the CLI, so an operation cannot unload its own process.
- The Updates view uses `plugin-update-status` to compare local commits with `HEAD` advertised by validated GitHub HTTPS or SSH origins. Checks must remain non-interactive, bounded, and read-only: do not fetch or modify plugin Git state. Remote failures are unknown, never up to date.
- Updates launched from that view use `plugin-update-checked`, which must bind the explicit validated origin, local commit, and advertised remote commit through fetch, fast-forward, validation, and rescan. Do not replace it with an unrestricted update after a separate precheck.
- Community plugins run unsandboxed inside `omarchy-shell`. Do not weaken the confirmation or the README/UI security wording that marketplace verification is not a security audit.

## QML Integration

- Use the shell's `qs.Commons` and `qs.Ui` components and `Color`/`Style` tokens; this plugin runs inside Omarchy Quattro rather than as a standalone Qt application.
- `MarketplaceSession.js` preserves open intent and Manage/Updates context while bar-widget enable/disable operations recreate `MarketplaceButton.qml`; manual close must clear that intent.
- Keep `manifest.json`'s id, `MarketplaceButton.qml`'s `moduleName`, and IPC commands aligned as `io.yasino55.omarchy-plugin-marketplace`.
