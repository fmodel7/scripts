from pathlib import Path
import tempfile
import unittest
import wave
from snow_edge_monitor.notifications import create_siren


class SirenTests(unittest.TestCase):
    def test_generates_valid_three_second_wave_and_reuses_it(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'siren.wav'
            create_siren(path)
            original = path.read_bytes()
            with wave.open(str(path)) as sound:
                self.assertEqual(sound.getnchannels(), 1)
                self.assertEqual(sound.getsampwidth(), 2)
                self.assertEqual(sound.getframerate(), 22050)
                self.assertEqual(sound.getnframes(), 66150)
            create_siren(path)
            self.assertEqual(path.read_bytes(), original)
