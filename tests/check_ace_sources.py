import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
rows = json.loads((root / 'docs/ace-sources.json').read_text())
paths = set()
for row in rows:
    path = row['path']
    assert path not in paths, f'Duplicate source entry: {path}'
    paths.add(path)
    data = (root / path).read_bytes()
    assert hashlib.sha256(data).hexdigest() == row['installed_sha256'], f'Source manifest mismatch: {path}'
    assert row['source_repository'] in ('AmonRay/ElvUI-for-Sirus', 'Accidev-Addons/WeakAuras-Sirus.su')
    assert len(row['source_commit']) == 40 and len(row['source_sha256']) == 64
for directory in ('Gladdy/Libs/Ace3', 'Gladdy/Libs/AceGUI-3.0-SharedMediaWidgets'):
    for path in (root / directory).rglob('*'):
        if path.is_file():
            assert str(path.relative_to(root)) in paths, f'Untracked Ace source: {path}'
for path in (root / 'Gladdy').rglob('*.lua'):
    text = path.read_text()
    assert '-Gladdy"' not in text and "-Gladdy'" not in text, f'Private UI library: {path}'
    assert 'GladdyAceGUI' not in text, f'Private UI global: {path}'
    assert 'AceGUI.CreateFrame' not in text and 'AceGUI.CreateFont' not in text, f'Private UI wrapper: {path}'
print(f'PASS: {len(rows)} source and fixture hashes; Ace UI uses shared registrations')
