"""Offline browser tests. Run explicitly; default unit suite needs no browser."""
from dataclasses import asdict
import os
from pathlib import Path
import unittest
from playwright.sync_api import sync_playwright
from helpers import settings
from snow_edge_monitor.browser import EXTRACT_SCRIPT, parse_snapshot, EdgeBrowser

FIXTURES = Path(__file__).with_name('fixtures')


class BrowserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pw = sync_playwright().start()
        try:
            executable = os.environ.get('TEST_CHROMIUM_EXECUTABLE')
            cls.browser = cls.pw.chromium.launch(headless=True, **({'executable_path': executable} if executable else {}))
        except Exception:
            cls.pw.stop()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.browser.close(); cls.pw.stop()

    def setUp(self):
        self.context = self.browser.new_context()
        self.page = self.context.new_page()
        self.context.route('**/*', lambda route: route.fulfill(
            status=200, content_type='text/html', body=(FIXTURES / (
                'iframe.html' if '/shell' in route.request.url else 'list.html')).read_text()))
        self.page.goto(settings().list_url, wait_until='load')

    def tearDown(self): self.context.close()

    def read(self, frame=None):
        return parse_snapshot((frame or self.page).evaluate(EXTRACT_SCRIPT, asdict(settings())), settings())

    def test_selection_column_and_all_states(self):
        result = self.read()
        self.assertEqual([i.state for i in result.incidents], ['1', '2', '6'])

    def test_iframe_discovery(self):
        self.page.goto('https://example.service-now.com/shell', wait_until='load')
        adapter = EdgeBrowser(settings(), Path('unused'))
        adapter.page = self.page
        adapter.last_network_epoch = 0
        result = adapter.snapshot()
        self.assertEqual(len(result.incidents), 3)

    def test_ambiguous_duplicate_tables_rejected(self):
        self.page.evaluate('document.body.append(document.querySelector("table").cloneNode(true))')
        self.assertIsNone(self.read())

    def test_loading_refresh_is_not_empty_list(self):
        self.page.evaluate('document.querySelector("table").setAttribute("aria-busy", "true")')
        self.assertIsNone(self.read())

    def test_partial_refresh_rows_rejected(self):
        self.page.evaluate('document.querySelector("tbody tr").remove()')
        self.assertIsNone(self.read())

    def test_filter_change_rejected(self):
        self.page.locator('input[name=sysparm_query]').fill('state=6')
        self.assertIsNone(self.read())

    def test_page_two_rejected(self):
        self.page.locator('[data-monitor-first]').evaluate('(e) => e.value = "4"')
        self.assertIsNone(self.read())

    def test_missing_required_column_rejected(self):
        self.page.locator('th[name=state]').evaluate('(e) => e.removeAttribute("name")')
        self.page.locator('thead th').nth(2).evaluate('(e) => e.textContent = "Other"')
        self.assertIsNone(self.read())

    def test_valid_empty_table(self):
        self.page.locator('tbody').evaluate('(e) => e.innerHTML = ""')
        self.page.locator('[data-monitor-total]').evaluate('(e) => e.textContent = "0"')
        self.assertEqual(self.read().incidents, ())

    def test_glidelist_metadata_adapter(self):
        self.page.evaluate('''window.GlideList2 = {get: () => ({
          firstRow: 1, totalRows: 3, getQuery: () => "assignment_group=00000000000000000000000000000000"
        })}; document.querySelector('[data-monitor-total]').remove();''')
        self.assertEqual(len(self.read().incidents), 3)

    def test_selection_checkbox_change_is_silent(self):
        before = self.read()
        self.page.locator('tbody input').first.check()
        self.assertEqual(before, self.read())

    def test_inflight_network_blocks_snapshot(self):
        adapter = EdgeBrowser(settings(), Path('unused'))
        adapter.page = self.page
        adapter.inflight.add('synthetic-request')
        self.assertIsNone(adapter.snapshot())

    def test_changed_network_epoch_requires_quiet_read(self):
        adapter = EdgeBrowser(settings(), Path('unused'))
        adapter.page = self.page
        adapter.network_epoch = 1
        self.assertIsNone(adapter.snapshot())
        self.assertIsNotNone(adapter.snapshot())

    def test_reference_link_supplies_group_id(self):
        self.page.locator('tbody td:nth-child(4)').evaluate_all('''nodes => nodes.forEach(e => {
            e.removeAttribute('data-value');
            e.innerHTML = '<a href="sys_user_group.do?sys_id=00000000000000000000000000000000">Example support</a>';
        })''')
        self.assertEqual(len(self.read().incidents), 3)

    def test_duplicate_valid_frames_are_ambiguous(self):
        self.page.goto('https://example.service-now.com/shell', wait_until='load')
        self.page.evaluate('''() => {
          const f = document.createElement('iframe'); f.src = '/incident_list.do'; document.body.append(f);
        }''')
        self.page.wait_for_function('document.querySelectorAll("iframe").length === 2 && document.querySelectorAll("iframe")[1].contentDocument?.readyState === "complete"')
        adapter = EdgeBrowser(settings(), Path('unused')); adapter.page = self.page; adapter.last_network_epoch = 0
        self.assertIsNone(adapter.snapshot())

    def test_unneeded_sensitive_cells_are_not_extracted(self):
        self.page.evaluate('''() => {
          const header = document.createElement('th'); header.textContent = 'Assigned to';
          document.querySelector('thead tr').append(header);
          document.querySelectorAll('tbody tr').forEach(row => {
            const cell = document.createElement('td'); cell.textContent = 'SYNTHETIC_PRIVATE_VALUE'; row.append(cell);
          });
        }''')
        raw = self.page.evaluate(EXTRACT_SCRIPT, asdict(settings()))
        self.assertNotIn('SYNTHETIC_PRIVATE_VALUE', str(raw))
        self.assertEqual(len(parse_snapshot(raw, settings()).incidents), 3)

    def test_end_to_end_new_eligible_incident_after_refresh_gap(self):
        from snow_edge_monitor.monitor import Detector
        detector = Detector(settings().eligible_states)
        detector.observe(self.read()); detector.observe(self.read())
        detector.observe(None)
        self.page.evaluate('''() => {
          const row = document.querySelector('tbody tr').cloneNode(true);
          row.children[1].textContent = 'INC0000004';
          document.querySelector('tbody').append(row);
          document.querySelector('[data-monitor-total]').textContent = '4';
        }''')
        self.assertEqual(detector.observe(self.read()), ())
        self.assertEqual(detector.observe(self.read()), ('INC0000004',))
        self.assertEqual(detector.observe(self.read()), ())

    def test_end_to_end_state_transition(self):
        from snow_edge_monitor.monitor import Detector
        detector = Detector(settings().eligible_states)
        detector.observe(self.read()); detector.observe(self.read())
        self.page.locator('tbody tr').nth(2).locator('td').nth(2).evaluate('(e) => e.setAttribute("data-value", "1")')
        self.assertEqual(detector.observe(self.read()), ())
        self.assertEqual(detector.observe(self.read()), ('INC0000003',))
