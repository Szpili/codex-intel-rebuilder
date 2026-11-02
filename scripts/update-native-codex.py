#!/usr/bin/env python3
"""Install the unchanged, signed Intel archive from OpenAI's distribution host."""
import argparse
import fcntl
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

HOST = 'https://persistent.oaistatic.com/codex-app-prod/'
TEAM = '2DC432GLL2'
REQUIREMENT = 'anchor apple generic and certificate leaf[subject.OU] = "' + TEAM + '"'
STATE = Path.home() / 'Library/Application Support/Codex Intel Rebuilder'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def is_running(app):
    processes = run('/bin/ps', '-axo', 'command=', capture_output=True).stdout
    return str(app) + '/Contents/' in processes


def verify(app, version, build):
    with (app / 'Contents/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if (info.get('CFBundleIdentifier') != 'com.openai.codex'
            or info.get('CFBundleShortVersionString') != version
            or str(info.get('CFBundleVersion')) != build):
        raise RuntimeError('Archive identity/version does not match the official release feed')
    executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
    arches = run('/usr/bin/lipo', '-archs', str(executable), capture_output=True).stdout.split()
    if 'x86_64' not in arches:
        raise RuntimeError('Downloaded app does not include Intel code')
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', '-R', '=' + REQUIREMENT, str(app))
    return executable


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--output', type=Path, default=Path(os.environ.get(
        'CODEX_INTEL_APP_PATH', str(Path.home() / 'Applications/Codex_Intel.app'))))
    parser.add_argument('--archive', type=Path, help='Use an already downloaded archive; all validation still applies')
    args = parser.parse_args()
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'native-update.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Another update is running; deferring.', flush=True)
            return
        feed = run('/usr/bin/curl', '-fsSL', '--retry', '3', '--connect-timeout', '15',
                   '--max-time', '60', HOST + 'appcast.xml', capture_output=True).stdout
        item = ET.fromstring(feed).find('./channel/item')
        if item is None:
            raise RuntimeError('Official release feed is empty')
        ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
        version, build = item.findtext(ns + 'shortVersionString'), item.findtext(ns + 'version')
        if not version or not re.fullmatch(r'\d+(?:\.\d+)+', version) or not build or not build.isdigit():
            raise RuntimeError('Invalid release version in feed')
        app = args.output.expanduser().absolute()
        print('Latest release: ' + version + ' (build ' + build + ')', flush=True)
        current = False
        if app.exists():
            try:
                verify(app, version, build)
                current = True
            except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, plistlib.InvalidFileException):
                pass
        if current:
            print('Signed Intel app is current.', flush=True)
            return
        if args.dry_run:
            print('Would download, verify and install the signed Intel app.', flush=True)
            return
        # Do not move a running bundle, including helper processes in its framework.
        if is_running(app):
            print('Codex is open; deferring installation.', flush=True)
            return
        app.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.codex-intel-', dir=app.parent) as temp:
            staging = Path(temp)
            archive = args.archive
            if archive is None:
                archive = staging / 'release.zip'
                url = HOST + 'ChatGPT-darwin-x64-' + version + '.zip'
                print('Downloading ' + url, flush=True)
                # The public feed currently advertises ARM only. An unavailable
                # Intel artifact is a failed update; never substitute the ARM app.
                run('/usr/bin/curl', '-fL', '--retry', '3', '--connect-timeout', '30',
                    '--max-time', '1800', url, '-o', str(archive))
            run('/usr/bin/ditto', '-x', '-k', str(archive), str(staging / 'unpacked'))
            candidate = staging / 'unpacked/ChatGPT.app'
            verify(candidate, version, build)
            run('/usr/sbin/spctl', '--assess', '--type', 'execute', str(candidate))
            if is_running(app):
                print('Codex opened during the download; deferring installation.', flush=True)
                return
            backup = app.with_name(app.stem + '.previous.app')
            if backup.exists():
                shutil.rmtree(backup)
            if app.exists():
                app.rename(backup)
            try:
                candidate.rename(app)
            except BaseException:
                if backup.exists() and not app.exists():
                    backup.rename(app)
                raise
        print('Prepared' if args.prepare_only else 'Installed', app, flush=True)


if __name__ == '__main__':
    main()
