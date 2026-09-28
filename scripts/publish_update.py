"""Builds a release APK and publishes it as an in-app update.

    python scripts/publish_update.py --notes "What changed"

Steps: bump the version in pubspec.yaml (patch and build number, or
--version), build an arm64 release APK with .env.app, upload it to the
private "releases" bucket, then replace latest.json so phones see it on
their next check. Old APKs beyond the last three are removed.

Needs SB_PROJECT_URL and SB_SERVICE_ROLE in .env.local. The service-role
key stays on this computer; the app only ever gets short-lived links.
Commit the pubspec.yaml bump afterwards.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / 'pubspec.yaml'
APK = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
BUCKET = 'releases'
KEEP = 3

# Supabase's free plan refuses uploads above this.
MAX_UPLOAD_BYTES = 50 * 1024 * 1024


def read_env(path: Path) -> dict[str, str]:
    env = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def bump_version(explicit: str | None) -> tuple[str, int]:
    text = PUBSPEC.read_text(encoding='utf-8')
    match = re.search(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', text, re.M)
    if not match:
        sys.exit('pubspec.yaml needs a version like 0.1.0+1')
    major, minor, patch, build = map(int, match.groups())
    if explicit:
        if not re.fullmatch(r'\d+\.\d+\.\d+', explicit):
            sys.exit('--version must look like 0.2.0')
        name = explicit
    else:
        name = f'{major}.{minor}.{patch + 1}'
    code = build + 1
    PUBSPEC.write_text(
        text[: match.start()] + f'version: {name}+{code}' + text[match.end() :],
        encoding='utf-8',
    )
    return name, code


def build_apk() -> None:
    subprocess.run(
        'flutter build apk --release --target-platform android-arm64 '
        '--dart-define-from-file=.env.app',
        cwd=ROOT,
        shell=True,
        check=True,
    )


class Storage:
    def __init__(self, url: str, key: str):
        self.base = url.rstrip('/') + '/storage/v1'
        self.headers = {'Authorization': f'Bearer {key}', 'apikey': key}

    def _send(self, method: str, path: str, body: bytes, headers: dict) -> bytes:
        req = urllib.request.Request(
            self.base + path,
            data=body,
            method=method,
            headers={**self.headers, **headers},
        )
        try:
            with urllib.request.urlopen(req, timeout=600) as res:
                return res.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode('utf-8', 'replace')
            sys.exit(f'{method} {path} failed ({error.code}): {detail}')

    def upload(self, name: str, body: bytes, content_type: str) -> None:
        self._send(
            'POST',
            f'/object/{BUCKET}/{name}',
            body,
            {
                'Content-Type': content_type,
                'x-upsert': 'true',
                'cache-control': 'no-cache',
            },
        )

    def list_apks(self) -> list[str]:
        body = json.dumps({'prefix': '', 'limit': 1000}).encode()
        raw = self._send(
            'POST',
            f'/object/list/{BUCKET}',
            body,
            {'Content-Type': 'application/json'},
        )
        return [o['name'] for o in json.loads(raw) if o['name'].endswith('.apk')]

    def remove(self, names: list[str]) -> None:
        body = json.dumps({'prefixes': names}).encode()
        self._send(
            'DELETE',
            f'/object/{BUCKET}',
            body,
            {'Content-Type': 'application/json'},
        )


def last_commit_subject() -> str:
    result = subprocess.run(
        ['git', 'log', '-1', '--format=%s'],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--notes', help='What’s new, shown in the app')
    parser.add_argument('--version', help='Version name, e.g. 0.2.0')
    parser.add_argument(
        '--skip-build',
        action='store_true',
        help='Upload the APK already built (no version bump)',
    )
    args = parser.parse_args()

    env = read_env(ROOT / '.env.local')
    url, key = env.get('SB_PROJECT_URL'), env.get('SB_SERVICE_ROLE')
    if not url or not key:
        sys.exit('.env.local needs SB_PROJECT_URL and SB_SERVICE_ROLE')

    if args.skip_build:
        match = re.search(
            r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
            PUBSPEC.read_text(encoding='utf-8'),
            re.M,
        )
        name, code = match.group(1), int(match.group(2))
    else:
        name, code = bump_version(args.version)
        print(f'Building Velora {name} ({code})…')
        build_apk()

    apk = APK.read_bytes()
    if len(apk) > MAX_UPLOAD_BYTES:
        sys.exit(
            f'The APK is {len(apk) // (1024 * 1024)} MB; Supabase takes at '
            'most 50 MB per file on the free plan.'
        )

    storage = Storage(url, key)
    apk_name = f'velora-{code}.apk'
    print(f'Uploading {apk_name} ({len(apk) // (1024 * 1024)} MB)…')
    storage.upload(apk_name, apk, 'application/vnd.android.package-archive')

    # Written last, so phones never see a version whose APK isn't there yet.
    latest = {
        'versionCode': code,
        'versionName': name,
        'apk': apk_name,
        'sha256': hashlib.sha256(apk).hexdigest(),
        'sizeBytes': len(apk),
        'notes': args.notes or last_commit_subject(),
        'publishedAt': datetime.now(timezone.utc).isoformat(),
    }
    storage.upload(
        'latest.json',
        json.dumps(latest, indent=2).encode(),
        'application/json',
    )

    def code_of(n: str) -> int:
        m = re.fullmatch(r'velora-(\d+)\.apk', n)
        return int(m.group(1)) if m else 0

    old = sorted(storage.list_apks(), key=code_of, reverse=True)[KEEP:]
    if old:
        storage.remove(old)
        print(f'Removed {", ".join(old)}')

    print(f'Published Velora {name} ({code}). Commit the pubspec.yaml bump.')


if __name__ == '__main__':
    main()
