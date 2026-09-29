#!/usr/bin/env python3
"""Reject version/resource regressions in the release artifact."""
import json
import plistlib
import sys
import zipfile
from pathlib import Path

ipa = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/CarPlayW.ipa')
with zipfile.ZipFile(ipa) as archive:
    info = plistlib.loads(archive.read('Payload/CarPlayW.app/Info.plist'))
    assert info['CFBundleShortVersionString'] == '1.2', info
    assert info['CFBundleVersion'] == '21', info
    assert info['CFBundleIdentifier'] == 'dev.carplaycanvas.app', info
    old = {'AlpineReflection.png', 'SeasideJoy.png', 'TwilightLighthouse.png', 'BlueSkyBird.png', 'PalmSunset.png'}
    assert not any(Path(name).name in old for name in archive.namelist()), 'Wallpapers must not ship in the app'
    assert not any('.xctest/' in name for name in archive.namelist()), 'Test bundle leaked into IPA'
    print('Verified CarPlayW 1.2 (21); no bundled wallpaper originals or test bundles.')
config = json.loads(Path('remote-wallpapers/wallpapers.json').read_text(encoding='utf-8'))
assert config['version'] == 1
assert [entry['url'] for entry in config['wallpapers']] == [f'{i}.png' for i in range(1, 6)]
print(f'IPA size: {ipa.stat().st_size:,} bytes')
