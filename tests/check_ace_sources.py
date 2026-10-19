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
    if 'Libs' not in path.parts:
        text = path.read_text()
        for name in ('AceGUI-3.0', 'AceConfig-3.0', 'AceConfigRegistry-3.0', 'AceConfigDialog-3.0'):
            assert 'LibStub("' + name + '")' not in text, f'Shared UI reference: {path}'
print(f'PASS: {len(rows)} Ace source and fixture hashes; addon UI references are private')
