"""Interruptible polling worker; only generic status information enters the UI."""
import time
from .browser import EdgeBrowser
from .monitor import Detector


def run_worker(settings, events, stop, profile_dir, browser_factory=EdgeBrowser, clock=time.monotonic):
    detector = Detector(settings.eligible_states, settings.confirmation_reads)
    try:
        events.put(('status', 'Starting Microsoft Edge; sign in manually.'))
        with browser_factory(settings, profile_dir) as browser:
            refreshed = clock()
            failed_since = None
            warned = False
            while not stop.is_set():
                try:
                    if clock() - refreshed >= settings.refresh_seconds:
                        detector.gap()
                        browser.refresh()
                        refreshed = clock()
                    snapshot = browser.snapshot()
                except Exception:
                    snapshot = None
                    refreshed = clock()
                alerts = detector.observe(snapshot)
                if snapshot is None:
                    if failed_since is None:
                        failed_since = clock()
                    if clock() - failed_since >= settings.failure_seconds and not warned:
                        events.put(('failure', 'List unavailable or unsafe to evaluate. Check sign-in, columns, filters and pagination.'))
                        warned = True
                    events.put(('status', 'Waiting for a complete list in the configured scope.'))
                else:
                    failed_since, warned = None, False
                    events.put(('count', len(snapshot.incidents)))
                    events.put(('status', 'Monitoring' if detector.baseline is not None else 'Establishing a stable baseline'))
                if alerts:
                    events.put(('alert', alerts))
                stop.wait(settings.poll_seconds)
    except Exception as exc:
        # Exception messages can contain URLs and incident HTML. Only expose type.
        events.put(('error', f'Browser stopped ({type(exc).__name__}). Check Edge installation and profile availability.'))
    finally:
        events.put(('stopped', None))
