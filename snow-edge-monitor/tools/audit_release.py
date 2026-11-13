"""Review tracked source/history for release hazards; never print matched values.

Heuristics supplement manual review; they cannot prove absence of every secret.
The private uploaded original must stay outside this repository.
"""
import re
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

PROJECT_ROOT = Path(__file__).resolve().parents[1]

SAFE_HOSTS = {'example.service-now.com', 'example.invalid', 'localhost'}
URL = re.compile(r'https?://[^\s\x22\x27<>`]+')
SECRET = re.compile(r'''(?im)^\s*(?:password|passwd|api_key|access_token|client_secret)\s*=\s*["'][^"']+["']''')
FORBIDDEN = re.compile(r'(^|/)(?:config\.json|\.env(?:\..*)?|edge-profile|private-reference|\.private-reference)(?:/|$)|\.(?:har|pem|pfx|key|wav)$', re.I)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT_ROOT)


def findings(path, data):
    issues = []
    if FORBIDDEN.search(path): issues.append('private/runtime filename')
    try: text = data.decode('utf-8')
    except UnicodeDecodeError: return issues + ['binary file requires review']
    if SECRET.search(text): issues.append('possible literal secret')
    for url in URL.findall(text):
        try: host = urlsplit(url).hostname
        except ValueError: host = None
        if host and host not in SAFE_HOSTS and not host.endswith('.example.invalid'):
            issues.append('non-example URL requires review')
            break
    return issues


def main():
    failures = []
    tracked = git('ls-files', '-z', '--', '.').decode().split('\0')
    repository_root = Path(git('rev-parse', '--show-toplevel').decode().strip())
    relative_root = PROJECT_ROOT.relative_to(repository_root).as_posix()
    scope = [] if relative_root == '.' else [relative_root]
    for path in filter(None, tracked):
        for reason in findings(path, (PROJECT_ROOT / path).read_bytes()): failures.append(('working-tree', path, reason))
    checked = set()
    for revision in git('rev-list', '--all').decode().splitlines():
        for line in git('-C', str(repository_root), 'ls-tree', '-r', revision, '--', *scope).decode().splitlines():
            metadata, path = line.split('\t', 1)
            kind, object_id = metadata.split()[1:]
            if kind != 'blob' or (object_id, path) in checked: continue
            checked.add((object_id, path))
            for reason in findings(path, git('cat-file', 'blob', object_id)):
                failures.append(('history', path, reason))
    for source, path, reason in failures:
        print(f'{source}: {path}: {reason}')
    print(f'Audit: {len(list(filter(None, tracked)))} tracked files; {len(checked)} unique historical file versions; {len(failures)} findings.')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
