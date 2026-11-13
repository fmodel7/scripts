import json
from pathlib import Path
import tempfile
import unittest
from helpers import settings
from snow_edge_monitor.config import load_settings


class ConfigTests(unittest.TestCase):
    def test_example_valid(self):
        example = Path(__file__).parents[1] / 'config.example.json'
        self.assertEqual(load_settings(example).eligible_states, ('1', '2'))

    def test_invalid_origin(self):
        for url in ('http://example.invalid', 'https://user:secret@example.invalid',
                    'https://example.invalid/path', 'https://example.invalid?token=fake',
                    'https://example.invalid:8443', 'file:///tmp/example'):
            with self.subTest(url=url), self.assertRaises(ValueError): settings(instance_url=url)

    def test_no_query_injection_in_group(self):
        with self.assertRaises(ValueError): settings(assignment_group='group^ORstate=1')

    def test_invalid_intervals(self):
        for key in ('poll_seconds', 'refresh_seconds', 'failure_seconds'):
            for value in (0, -1, float('nan'), float('inf'), True, '5'):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError): settings(**{key: value})

    def test_invalid_fields(self):
        for kwargs in ({'eligible_states': []}, {'eligible_states': '1'}, {'eligible_states': [1]},
                       {'confirmation_reads': 1}, {'confirmation_reads': 2.5}, {'page_limit': 0},
                       {'siren_enabled': 'yes'}, {'popup_enabled': 1}, {'table_selector': ''}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError): settings(**kwargs)

    def test_settings_are_normalized(self):
        self.assertEqual(settings(eligible_states=[' New ']).eligible_states, ('new',))

    def test_invalid_file_has_generic_message(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'config.json'
            for text in ('{', json.dumps({'secret': 'FAKE_SECRET'}), 'null'):
                path.write_text(text)
                with self.assertRaises(ValueError) as error: load_settings(path)
                self.assertNotIn('FAKE_SECRET', str(error.exception))
