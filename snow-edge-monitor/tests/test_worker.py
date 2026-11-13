from pathlib import Path
import queue
import unittest
from helpers import settings, snapshot
from snow_edge_monitor.worker import run_worker


class FakeStop:
    def __init__(self, count): self.remaining = count
    def is_set(self): return self.remaining <= 0
    def wait(self, _): self.remaining -= 1


class FakeBrowser:
    def __init__(self, snapshots):
        self.snapshots = iter(snapshots)
        self.closed = False
        self.refreshes = 0
    def __enter__(self): return self
    def __exit__(self, *_): self.closed = True
    def snapshot(self): return next(self.snapshots)
    def refresh(self): self.refreshes += 1


class WorkerTests(unittest.TestCase):
    def test_emits_alert_and_closes_browser(self):
        empty, new = snapshot(), snapshot(('INC0000001', '1'))
        browser = FakeBrowser([empty, empty, new, new])
        events = queue.Queue()
        run_worker(settings(), events, FakeStop(4), Path('fake'), lambda *_: browser, lambda: 0)
        messages = list(events.queue)
        self.assertIn(('alert', ('INC0000001',)), messages)
        self.assertEqual(messages[-1], ('stopped', None))
        self.assertTrue(browser.closed)

    def test_failure_is_reported_once_and_recovers(self):
        browser = FakeBrowser([None] * 5 + [snapshot(), snapshot()])
        events = queue.Queue()
        ticks = iter(range(200))
        run_worker(settings(failure_seconds=1, refresh_seconds=1000), events, FakeStop(7),
                   Path('fake'), lambda *_: browser, lambda: next(ticks))
        messages = list(events.queue)
        self.assertEqual(sum(k == 'failure' for k, _ in messages), 1)
        self.assertIn(('status', 'Monitoring'), messages)

    def test_exception_message_never_exposes_urls(self):
        def fail(*_): raise RuntimeError('FAKE_SECRET https://private.example.invalid')
        events = queue.Queue()
        run_worker(settings(), events, FakeStop(1), Path('fake'), fail)
        self.assertNotIn('FAKE_SECRET', repr(list(events.queue)))
        self.assertEqual(list(events.queue)[-1][0], 'stopped')

    def test_refresh_happens_without_erasing_baseline(self):
        browser = FakeBrowser([snapshot(), snapshot()])
        events = queue.Queue()
        ticks = iter(range(200))
        run_worker(settings(refresh_seconds=1), events, FakeStop(2), Path('fake'),
                   lambda *_: browser, lambda: next(ticks))
        self.assertGreater(browser.refreshes, 0)
        self.assertTrue(browser.closed)
