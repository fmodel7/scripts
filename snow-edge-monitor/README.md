# SNOW Edge Monitor

A local Windows desktop application that watches a ServiceNow Classic incident list in **Microsoft Edge through Playwright**. It polls and refreshes at configurable intervals and notifies through a generated siren, a topmost popup, and a Windows tray menu.

Authentication stays in the visible Edge window. The application does not accept passwords, call the ServiceNow API, export cookies, or store incident descriptions. The public example uses an illustrative instance and a dummy group ID.

## Objectives and documentation

The project helps Windows operators notice confirmed eligibility changes in one ServiceNow group while keeping authentication in their own interactive Edge session. Its priorities are configurable reuse, conservative detection, local notifications, modular maintenance and publication without corporate data.

| Read this | For |
| --- | --- |
| [Objectives and operating model](docs/PROJECT_GUIDE.md) | Goals, boundaries, end-to-end flow, snapshot checks, state transitions, fictional examples and delivery limits. |
| [Guia detalhado em português](docs/GUIA_DO_PROJETO.pt-BR.md) | Objetivos, configuração, funcionamento passo a passo, regras de alerta, privacidade e limitações. |
| [Operational runbook](docs/OPERATIONS.md) | First use, status messages, troubleshooting and shutdown. |
| [Architecture](docs/ARCHITECTURE.md) | Adapter contracts, thread ownership, detection state and extension points. |
| [Windows validation](docs/WINDOWS_VALIDATION.md) | Manual desktop/build checks that still need execution. |
| [Publication record](docs/PUBLICATION.pt-BR.md) | Authorized destination, shared-repository integration and validation boundaries. |
| [Initial review report](docs/REVIEW_REPORT.pt-BR.md) | Sensitive-data findings and the initial test evidence. |

## Requirements

- Windows 10/11, an interactive desktop session, and Microsoft Edge installed.
- Python 3.11 or newer with Tcl/Tk (include it in the official Python Windows installer).
- Permission to view the configured incident list and group.
- A ServiceNow Classic list exposing the metadata described below. Workspace and Shadow DOM interfaces require a separate adapter.

`requirements.txt` contains Playwright, Pillow, and Windows-only pystray. Tkinter, winsound, unittest, JSON, and WAV generation use the standard library. `requirements-dev.txt` adds PyInstaller. Dependency ranges are declared; this is not a reproducible dependency lock.

## Install and run (PowerShell)

In the shared `fmodel7/scripts` repository, open PowerShell in the `snow-edge-monitor` folder before running these commands.

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item config.example.json config.json
# Edit config.json locally before starting.
python -m snow_edge_monitor --config .\config.json
```

Use the normal installed Edge channel; downloading Playwright Chromium is unnecessary for production. Do not run `playwright install msedge` over an existing Edge installation.

Press **Start**, sign in manually in the launched Edge window, and wait for **Monitoring**. The app opens the group list itself. **Stop** closes its dedicated browser context; closing the panel hides it in the tray. **Exit** waits for the worker and closes the application. **Test alert** uses `INC9999999`, a synthetic value. Keep only one monitor process running per Windows user because the profile is dedicated to this app.

The source checkout defaults to `config.json` in the working directory. A frozen executable defaults to `config.json` beside the executable. `--config` accepts an explicit path. Configuration changes take effect after restarting the app.

## Configuration

| Setting | Meaning |
| --- | --- |
| `instance_url` | HTTPS origin only, such as `https://example.service-now.com`; no credentials, path, or parameters. |
| `assignment_group` | The group's 32-character ServiceNow `sys_id`, configured locally. |
| `eligible_states` | State values that can trigger an alert; defaults `1` and `2` are illustrative, not universal. |
| `poll_seconds` / `refresh_seconds` | Positive polling and browser reload intervals. |
| `failure_seconds` | Delay before one availability warning; a valid read resets it. |
| `confirmation_reads` | Consecutive valid observations required for a baseline or change, at least two. |
| `page_limit` | Requested list size; the server may enforce a smaller limit. |
| `table_selector` | CSS selector for the one incident table in a frame. |
| `query_selector` / `first_selector` / `total_selector` | CSS selectors for list metadata when GlideList2 is unavailable. |
| `number_columns` / `state_columns` / `group_columns` | Header field names or labels, matched without case sensitivity. |
| `siren_enabled` / `popup_enabled` | Independent notification switches. |

States use the cell's `data-value` when present, otherwise its visible label. Confirm which representation your instance supplies, then configure matching values or labels. Descriptions and assignees are never extracted. Group identity must be readable as `data-value`, `sys_id`, or a `sys_user_group.do?sys_id=...` reference link. Matching a display name alone is insufficient.

### List compatibility and pagination

Display **Number**, **State**, and **Assignment group** columns. Selection/action columns may precede or follow them; fields are mapped by header, not position. Headers may use `name`, `data-field`, `glide_field`, or visible labels; an `incident.` prefix is supported. Each frame is inspected, including nested iframes, but exactly one valid list is accepted in the controlled tab.

The read-only adapter first tries `GlideList2.get(list_id)` with `getQuery()`, `firstRow`, and `totalRows`. These APIs vary across ServiceNow releases. If unavailable, supply selectors for a single query input, first-row value, and total-row value. The fallback defaults target Classic-style `incident.first_row` and `incident.total_rows` element IDs. These selectors are a starting point, not a guarantee of compatibility with every release. Adapt them to your instance's existing DOM when necessary. No metadata is invented or injected into the ServiceNow page.

The effective query must contain the configured assignment group alone, optionally followed by `ORDERBY`, `ORDERBYDESC`, and `EQ` directives. Additional filters are rejected. The app reads all states in that group and evaluates alert eligibility locally, so it can observe state transitions.

**Only a complete first-page list is eligible for detection:** row count must equal the advertised total, every row must belong to the configured group, and numbers must be unique. When the group exceeds the available page size, monitoring pauses with a status/warning. Increasing `page_limit` helps only if the server permits it. This version deliberately does not merge pages or infer new incidents from rows entering a paginated window. Do not bypass this guard by changing the advertised total.

## Alert behavior

- Startup and each changed valid context establish a silent baseline after identical complete reads, including a truly empty list.
- A previously unseen incident in an eligible state, or a known incident moving from an ineligible to an eligible state, alerts after consecutive confirmation.
- Existing eligible incidents at startup and changes between eligible states stay silent.
- Returning to eligibility after a confirmed ineligible state can alert again.
- Refresh, missing frames, loading, detached frames, inflight document/XHR/fetch requests, and incomplete lists clear pending confirmations. Confirmed history remains in memory across a same-context refresh.
- Disappearing and reappearing rows do not, by themselves, alert. A changed URL, query, ordering, or header layout establishes a new baseline.
- Stopping/restarting starts fresh and does not replay incidents observed while stopped.

The tradeoff favors avoiding false alerts: an incident appearing only between polls, an eligibility transition while no valid complete list is available, or a change during baseline establishment may be missed. DOM integration cannot guarantee server consistency; validate your instance's metadata and loading behavior before operational use.

## Architecture

```text
__main__ / config -> ui (Tk main thread)
                      | queue + stop event
                      v
                    worker -> browser (Playwright / extract.js)
                      |        -> immutable Snapshot / Incident
                      v
                    monitor (pure detection state machine)
                      | alert event
                      v
                    ui -> notifications (winsound / popup / tray image)
```

`browser.py` owns only the controlled tab, validates origin, query, group and completeness, and reads frames. `monitor.py` contains deterministic detection with no desktop dependencies. `worker.py` owns polling, refresh, warnings and browser cleanup. `ui.py` keeps Tk on the main thread and routes tray callbacks through the queue. `notifications.py` generates a WAV and manages popup acknowledgment. See [architecture notes](docs/ARCHITECTURE.md).

## Tests

All fixtures contain fictional incident numbers, group names and HTML. Unit tests require no network, corporate browser profile, GUI, or Windows imports:

```powershell
python -m unittest discover -s tests -v
```

Browser integration tests run the actual extraction JavaScript in headless Chromium with every request intercepted and fulfilled from local fixtures:

```powershell
python -m playwright install chromium
python -m unittest discover -s tests -p 'browser_*.py' -v
```

For an existing Chromium binary on Linux, set `TEST_CHROMIUM_EXECUTABLE=/usr/bin/chromium`. This override is used only in tests; production always uses `channel="msedge"`. GitHub Actions definitions cover unit tests on Windows/Linux Python 3.11/3.12 and offline browser tests on Linux. Package-local definitions are for standalone use. In the shared repository, active definitions are the root-level `snow-edge-monitor-tests.yml` and `snow-edge-monitor-windows.yml` workflows. Consult the pull request for actual GitHub Actions results. See the [Windows manual checklist](docs/WINDOWS_VALIDATION.md).

## Package with PyInstaller (on Windows)

PyInstaller does not cross-compile Windows executables from Linux. Build on Windows using the same Python architecture as your target:

```powershell
python -m pip install -r requirements-dev.txt
python -m PyInstaller --noconfirm --clean --windowed --onedir --name SNOWEdgeMonitor --collect-all playwright --hidden-import pystray._win32 --add-data "snow_edge_monitor/extract.js:snow_edge_monitor" run_monitor.py
Copy-Item config.example.json dist\SNOWEdgeMonitor\config.example.json
Copy-Item config.example.json dist\SNOWEdgeMonitor\config.json
# Configure only the local config.json before use. Never publish that file.
.\dist\SNOWEdgeMonitor\SNOWEdgeMonitor.exe
```

`--collect-all playwright` includes the Node driver; installed Microsoft Edge remains an external dependency. `extract.js` must be shipped as package data. Prefer `--onedir` for diagnosis. For a single file, replace `--onedir` with `--onefile` and test startup/extraction and endpoint protection behavior separately. Missing or invalid configuration in a frozen Windows app produces an error dialog.

Share a clean build and `config.example.json` only, after Windows validation and approval. Do not bundle runtime profiles, your configured `config.json`, or browser downloads. Packaging commands are documented; no Windows executable has been built or validated in this Linux session.

## Privacy and source history

Local runtime files are under `%LOCALAPPDATA%\SNOWEdgeMonitor`: `edge-profile` contains the browser's authentication/session data and `siren.wav` is generated locally. These are never release artifacts. The application does not export browser state or write diagnostic files. UI logs contain generic status/counts and exception types, not URLs, configuration values, or incident identifiers; incident numbers appear only in the alert popup and memory.

The unchanged uploaded original is preserved privately outside this repository. `reference/` holds an explicitly sanitized historical copy, never the original corporate hostname. The standalone preparation repository's initial `main` commit contains only that safe reference, with refactoring on `refactor/generic-windows-app`. Publication in the shared `fmodel7/scripts` repository uses the separate `refactor/snow-edge-monitor` branch and the root-level `snow-edge-monitor` folder. A local Git bundle preserves both branches for review; the source ZIP omits Git internals. Neither artifact contains the private original. The [Portuguese review report](docs/REVIEW_REPORT.pt-BR.md) records findings and validation.

The owner explicitly authorized source publication after reviewing the initial report. The private original, local settings and browsing data remain excluded. Windows desktop validation is still pending; source publication does not claim a validated Windows binary. No license has been selected, so publication alone does not grant an open-source license.

## Restore the local review bundle

If you received the companion `snow-edge-monitor.bundle`, it contains the sanitized baseline and refactoring branches:

```powershell
git clone -b refactor/generic-windows-app .\snow-edge-monitor.bundle SNOWEdgeMonitor
cd SNOWEdgeMonitor
git branch main origin/main
```

The restored checkout points to the local bundle, not GitHub. Review the report and Windows checklist before adding any publishing remote. The source ZIP provides the same refactored files without branch history.
