# Operational runbook

This runbook covers routine use and diagnosis without exporting incident content. See the [project guide](PROJECT_GUIDE.md) for detection semantics and the [README](../README.md) for exact installation commands.

## First use

1. Install Python with Tcl/Tk and the declared dependencies on Windows, or use a Windows build that has completed the manual validation checklist. Keep Microsoft Edge installed.
2. Copy the example into a local `config.json`. Enter the target HTTPS origin, group sys_id and the exact eligible state representation supplied by the list. Do not commit the configured copy.
3. Ensure the Classic list contains Number, State and Assignment group and that first-row/total metadata is available. Adjust selectors locally when required.
4. Start the app and press **Start**. Sign in manually in the dedicated Edge window. Keep the controlled tab open.
5. Wait through **Establishing a stable baseline** until **Monitoring**. Existing eligible rows do not produce startup alerts.
6. Use fictional records in a test instance to verify one new eligible number and one ineligible-to-eligible transition. Use **Test alert** separately to verify the desktop sound/popup path.

## Reading status information

| Status or event | Meaning | Action |
| --- | --- | --- |
| Starting Edge / sign in | The worker is opening its browser context. | Complete interactive authentication if prompted. |
| Establishing a stable baseline | A complete accepted list has been read but baseline confirmation is incomplete. | Keep the scope stable and allow consecutive reads. |
| Monitoring | A complete list was accepted and the detector has a baseline. | Continue normal operation; this status does not promise future connectivity. |
| Waiting for a complete list | The latest read was unavailable or did not satisfy the validation contract. | Check session, scope, columns, metadata, loading and pagination. |
| List unavailable warning | Invalid reads lasted at least `failure_seconds`. | Investigate; the warning is emitted once until a valid read resets the outage. |
| Browser stopped with an exception type | Browser startup or the outer worker failed. | Check Edge installation, profile availability and dependencies. Restart after fixing the cause. |
| Stopped | The worker has released its context. | Start again to establish a fresh baseline. |

The visible count is updated only for accepted captures. During an outage it may describe the last valid read; it is not proof that the current page is complete.

## Common problems

### The list is visible but monitoring does not arm

Confirm that it is the Classic `/incident_list.do` view on the configured origin and controlled tab. Verify that the effective query contains the configured group alone, with supported sort directives only. Ensure each row supplies the group sys_id and that the expected headers are unambiguous. A visible table can still be incomplete or belong to a different group.

Inspect metadata compatibility in a non-production fixture or locally without copying corporate DOM into the repository. GlideList2 methods/properties vary by release. Configure fallback selectors to return one query value, one first-row value and one total value. Do not hardcode a fabricated count.

### The group has more records than the page

The monitor pauses because row count differs from the advertised total. Request a larger `page_limit` only if the server permits it. If the group cannot fit in one page, the current adapter does not support that dataset. Automatic multi-page collection requires a separate design with a stable dataset boundary.

### No sound or popup appears

Check `siren_enabled` and `popup_enabled`, then use **Test alert**. The test uses a fictional number and does not validate browser extraction. Verify the active Windows audio device and desktop session. If the test works, examine whether the real change meets the documented eligibility and consecutive-read rules. Startup records, one-read changes and eligible-to-eligible transitions are intentionally silent.

### Login expires or refresh is slow

Reauthenticate manually in the dedicated browser. Invalid reads clear pending candidates and leave the last confirmed baseline available for same-context recovery. Very frequent refreshes can interrupt confirmation; use intervals that allow the list to finish loading and be read consecutively. Events observed only during an outage cannot be guaranteed.

### Edge reports that the profile is in use

Run one monitor process for a Windows user. Stop the other monitor/context before retrying. Do not redirect the application to your everyday Edge profile or copy that profile into the project. After the application has fully stopped, resetting the dedicated profile removes its stored sessions and requires signing in again; back up only according to your organization's local policy, never to the repository.

### Configuration fails

Validate JSON syntax and use the field types from `config.example.json`. State values must be strings. The group must be a 32-character sys_id, timers must be positive finite numbers, and confirmation reads must be an integer of at least two. Pass an explicit `--config` path if the working directory is uncertain. Restart the app after editing.

## Shutdown and restart

Closing the panel hides it. Use the tray's **Show** to restore it. **Stop** interrupts the polling wait, but an ongoing browser navigation can take up to its 30-second timeout. **Exit** waits for worker cleanup, stops the tray and closes Tk. Restart learns a fresh baseline and does not replay records seen while stopped.

## Before sharing a build or changing an adapter

Run the unit suite and actual-JavaScript browser suite with fictional fixtures, then the release audit. Check the applicable Windows validation steps. Distribute only clean source/build output and `config.example.json`. Exclude local settings, browser profiles, cookies, HAR captures, screenshots containing real incident content and the private original.

The automated audit is heuristic. A zero-finding result complements human review; it does not prove that every possible secret or personal detail is absent.
