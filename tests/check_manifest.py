"""Check every TOC/XML dependency without a WoW installation (stdlib only)."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
seen = set()

def visit(path):
    assert path.is_file(), f"Missing addon dependency: {path.relative_to(root)}"
    if path in seen:
        return
    seen.add(path)
    if path.suffix == '.xml':
        for node in ET.parse(path).iter():
            tag = node.tag.rsplit('}', 1)[-1]
            if tag in ('Script', 'Include') and 'file' in node.attrib:
                dep = path.parent / node.attrib['file'].replace('\\', '/')
                assert dep.suffix == ('.lua' if tag == 'Script' else '.xml'), f"Wrong {tag}: {dep}"
                visit(dep)
    elif path.suffix == '.toc':
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith('#'):
                visit(path.parent / line.replace('\\', '/'))

visit(root / 'Gladdy/Gladdy.toc')
print(f'PASS: {len(seen)} TOC/XML dependencies resolve with correct loader types')
