# Architecture and adapter contract

The Python package separates settings, immutable models, browser I/O, detection, worker scheduling, UI and notifications. The original monolith is retained as a sanitized historical reference; production imports do not depend on it.

## Snapshot boundary

`extract.js` runs as one synchronous evaluation in each frame. It rejects hidden/ambiguous tables, non-complete documents, `aria-busy` loading, merged cells, and inconsistent column counts. It maps header fields, then returns only number/state/group cells plus minimum list metadata. Python validates every record, origin, configured group query, uniqueness, exact full-list count and first row. Unknown fields, additional filters, missing metadata, partial pages and detached frames cannot become empty lists.

GlideList2 compatibility is isolated in this adapter, with configurable CSS metadata fallbacks. Group reference links are read without navigating. There is no ServiceNow request interception, state modification or injected UI. Test request routing exists only in the offline test harness.

`EdgeBrowser` tracks document/XHR/fetch requests on the controlled page, including its frames, waits one quiet observation after a network epoch changes, and rejects ambiguous valid frames. WebSocket traffic, ServiceNow-specific loading indicators beyond `aria-busy`, virtualized lists, Shadow DOM, UI Builder and Workspace are not supported. A target instance may require an adapter change; never relax completeness/group checks to make a partial list look valid.

## Detection state machine

A snapshot's scope is a SHA-256 digest of frame URL, effective query and column mapping. The digest avoids forwarding configuration values to the UI; it is not a security credential.

On a new scope, baseline state is unarmed. Identical complete snapshots observed `confirmation_reads` times create a silent baseline. While armed, each incident's changed state is a separate candidate. Only consecutive valid reads of that same number/state confirm the change. Confirmed absent-to-eligible or ineligible-to-eligible changes produce sorted incident numbers. Eligible-to-eligible changes are silent. Confirmed states for missing rows remain known until the worker is stopped or scope changes. This memory is not persisted across sessions.

Invalid reads and scheduled reloads discard candidates while retaining confirmed history. A complete empty table is valid only when the list metadata also says zero rows. A temporarily emptied tbody with a nonzero total is invalid.

This complete-list policy avoids distinguishing creation from entering the current page: there is no page window in accepted snapshots. It cannot guarantee delivery of changes that are not visible in any confirmed valid snapshot.

## Concurrency and shutdown

Playwright starts, polls, reloads and closes on one worker thread. The worker emits typed queue tuples for status, count, alert, failure, error and stopped. The UI drains the queue on Tk's main thread every 150 ms. Tray callbacks enqueue commands rather than touching Tk. Poll delays use `Event.wait`, so Stop interrupts the delay immediately. An ongoing Playwright navigation may take up to its 30-second timeout; shutdown waits for it to release the dedicated browser context.

The browser is never attached to the user's everyday Edge profile. Authentication is interactive in a dedicated persistent profile. Context cleanup and Playwright cleanup run on startup errors and worker shutdown. Unexpected browser errors expose only exception class names, because exception text may contain request URLs or page content.

## Extension points

Keep a new ServiceNow UI adapter behind the `Snapshot | None` contract, with fixture-based tests of its completeness and group assertions. A future multi-page implementation needs a stable server-side dataset boundary and duplicate/reorder protection before it can produce a snapshot. Do not concatenate user-driven page reads and assume that they form one transaction.

## Shared-repository publication

The release auditor resolves the project root from its own script location. In a shared repository it scans this project's tracked files and historical subtree, excluding unrelated tools; it still detects a private file deleted from this project's current tree. This permits publication under `snow-edge-monitor/` without treating the repository's other projects as part of this package. Four synthetic Git-repository tests exercise this boundary.

GitHub only runs workflow definitions from the repository-root `.github/workflows`. The publication includes uniquely named workflow files there with `snow-edge-monitor` as the default run directory, path filters for this project, and an artifact path rooted at this project's Windows build. Existing workflows are retained. The package-local workflow definitions remain useful when the project is extracted into its own repository.
