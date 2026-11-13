"""Ensure publication auditing works both standalone and inside a shared repo."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

AUDIT = Path(__file__).parents[1] / 'tools' / 'audit_release.py'


class AuditScopeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Synthetic Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.repo / 'config.json').write_text('{}')
        self.commit('Unrelated tool baseline')
        self.project = self.repo / 'snow-edge-monitor'
        (self.project / 'tools').mkdir(parents=True)
        shutil.copyfile(AUDIT, self.project / 'tools' / 'audit_release.py')
        (self.project / 'README.md').write_text('Synthetic project')
        self.commit('Add synthetic nested project')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.STDOUT)

    def commit(self, message):
        self.git('add', '.')
        self.git('commit', '-m', message)

    def audit(self, cwd=None):
        return subprocess.run([sys.executable, str(self.project / 'tools' / 'audit_release.py')],
                              cwd=cwd or self.project, text=True, capture_output=True)

    def test_other_projects_are_outside_audit_scope(self):
        result = self.audit()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('2 tracked files', result.stdout)
        self.assertIn('0 findings', result.stdout)

    def test_invocation_from_repository_root_uses_script_location(self):
        result = self.audit(self.repo)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_project_local_config_is_rejected(self):
        (self.project / 'config.json').write_text('{}')
        self.commit('Synthetic accidental config')
        result = self.audit()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('private/runtime filename', result.stdout)

    def test_deleted_local_config_remains_a_history_finding(self):
        path = self.project / 'config.json'
        path.write_text('{}')
        self.commit('Synthetic accidental config')
        path.unlink()
        self.commit('Remove synthetic config')
        result = self.audit()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('history:', result.stdout)
