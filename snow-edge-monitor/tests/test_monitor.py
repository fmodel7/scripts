import unittest
from helpers import snapshot
from snow_edge_monitor.monitor import Detector

A, B, C = 'INC0000001', 'INC0000002', 'INC0000003'


class DetectorTests(unittest.TestCase):
    def setUp(self):
        self.detector = Detector(('1', '2'))
        self.base = snapshot((A, '3'))
        self.assertEqual(self.detector.observe(self.base), ())
        self.assertEqual(self.detector.observe(self.base), ())

    def confirm(self, snap, expected):
        self.assertEqual(self.detector.observe(snap), ())
        self.assertEqual(self.detector.observe(snap), expected)

    def test_existing_eligible_at_start_is_silent(self):
        detector = Detector(('1',))
        for _ in range(4): self.assertEqual(detector.observe(snapshot((A, '1'))), ())

    def test_new_eligible_incident(self):
        new = snapshot((A, '3'), (B, '1'))
        self.confirm(new, (B,))
        self.assertEqual(self.detector.observe(new), ())

    def test_new_ineligible_incident(self):
        self.confirm(snapshot((A, '3'), (B, '6')), ())

    def test_becoming_eligible(self):
        self.confirm(snapshot((A, '1')), (A,))

    def test_eligible_to_eligible_is_silent(self):
        self.confirm(snapshot((A, '1')), (A,))
        self.confirm(snapshot((A, '2')), ())

    def test_leave_then_reenter_eligible_can_notify(self):
        self.confirm(snapshot((A, '1')), (A,))
        self.confirm(snapshot((A, '6')), ())
        self.confirm(snapshot((A, '1')), (A,))

    def test_refresh_gap_keeps_baseline_but_clears_confirmation(self):
        new = snapshot((A, '3'), (B, '1'))
        self.detector.observe(new)
        self.assertEqual(self.detector.observe(None), ())
        self.confirm(new, (B,))

    def test_one_transient_row_never_alerts(self):
        self.detector.observe(snapshot((A, '3'), (B, '1')))
        self.detector.observe(self.base)
        self.confirm(snapshot((A, '3'), (B, '1')), (B,))

    def test_one_transient_state_never_alerts(self):
        self.detector.observe(snapshot((A, '1')))
        self.detector.observe(self.base)
        self.confirm(snapshot((A, '1')), (A,))

    def test_filter_sort_or_page_context_rebases(self):
        for scope in ('filtered', 'page-2', 'sort-desc', 'scope'):
            for _ in range(3):
                self.assertEqual(self.detector.observe(snapshot((B, '1'), scope=scope)), ())

    def test_disappearance_and_reappearance_do_not_alert(self):
        self.confirm(snapshot((A, '1')), (A,))
        self.confirm(snapshot(), ())
        self.confirm(snapshot((A, '1')), ())

    def test_stable_empty_initial_list_can_arm(self):
        detector = Detector(('1',))
        detector.observe(snapshot()); detector.observe(snapshot())
        self.assertEqual(detector.observe(snapshot((B, '1'))), ())
        self.assertEqual(detector.observe(snapshot((B, '1'))), (B,))

    def test_baseline_requires_identical_reads(self):
        detector = Detector(('1',))
        detector.observe(snapshot((A, '1')))
        detector.observe(snapshot((B, '1')))
        self.assertIsNone(detector.baseline)
        detector.observe(None)
        detector.observe(snapshot((B, '1')))
        self.assertIsNone(detector.baseline)
        detector.observe(snapshot((B, '1')))
        self.assertIsNotNone(detector.baseline)

    def test_multiple_changes_confirm_independently(self):
        self.detector.observe(snapshot((A, '1'), (B, '1')))
        self.assertEqual(self.detector.observe(snapshot((A, '1'), (B, '1'), (C, '1'))), (A, B))
        self.assertEqual(self.detector.observe(snapshot((A, '1'), (B, '1'), (C, '1'))), (C,))

    def test_three_confirmations(self):
        detector = Detector(('1',), 3)
        for _ in range(3): detector.observe(snapshot())
        for _ in range(2): self.assertEqual(detector.observe(snapshot((B, '1'))), ())
        self.assertEqual(detector.observe(snapshot((B, '1'))), (B,))

    def test_reject_single_read_policy(self):
        with self.assertRaises(ValueError): Detector(('1',), 1)
