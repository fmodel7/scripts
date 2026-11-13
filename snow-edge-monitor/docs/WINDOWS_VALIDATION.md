# Windows validation before release

This checklist is pending: development validation was performed in Linux using synthetic fixtures. Use a test instance with fictional records; no production screenshots or exports belong in Git.

1. On Windows 10/11 with Edge installed, install dependencies and verify `python -m tkinter` opens a window.
2. Copy/configure the example locally. Set a test group sys_id and verify state values and column aliases against that instance. Verify first row and total metadata using GlideList2 or your CSS fallbacks.
3. Start monitoring, complete interactive sign-in, confirm the initial list establishes a silent baseline, and confirm an empty list can arm.
4. Add a synthetic eligible incident. Verify one sound and popup only after the configured consecutive reads. Confirm that resolved/closed/canceled and other ineligible states stay silent.
5. Move a synthetic known incident from an ineligible to an eligible state; verify one alert. Move between two eligible states; verify silence. Acknowledge and verify the sound stops.
6. Change sorting and filters, paginate, navigate through an iframe, and reload while the page is loading. Confirm unsafe/partial captures pause detection and never trigger alerts merely because rows move.
7. Exercise automatic refresh, session expiry, unavailable list, recovery and one warning per outage. Verify Stop, restart, hide, show, tray Test alert, and Exit. Confirm Edge releases the dedicated profile and the process exits.
8. Check notification toggles, audio device errors, malformed/missing config and profile-in-use errors. Verify the UI shows useful generic errors without corporate URLs or page content.
9. Build the Windows PyInstaller `--onedir` artifact using the README. On a clean Windows desktop with Edge installed and no Python, configure the example locally and repeat startup, extraction, sound, popup, tray and shutdown checks.
10. Inspect the clean distribution for local configs and profile files before packaging. Add the selected license and review the sensitive-data report. Publish only after explicit owner approval.

No checkbox here represents a test already executed on Windows.
