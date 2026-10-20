from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\[(=*)\[.*?\]\2\]|\.\.|[A-Za-z_][A-Za-z_0-9]*|\S', re.S)
ESCAPES = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}

def literal(token):
    if token[:1] not in ('"', "'"):
        return None
    return re.sub(r'\\(\d{1,3}|\r?\n|.)', lambda m: chr(int(m[1])) if m[1].isdigit() else ESCAPES.get(m[1], m[1]), token[1:-1])

def tokens(text):
    return [m[0] for m in TOKEN.finditer(text) if not m[0].startswith('--')]

def static_key(items, index):
    if index >= len(items):
        return None, index
    result = literal(items[index])
    if result is None:
        return None, index
    index += 1
    while index + 1 < len(items) and items[index] == '..':
        part = literal(items[index + 1])
        if part is None:
            return None, index
        result += part
        index += 2
    return result, index

def check():
    data = tokens((ROOT / 'Gladdy/Lang.lua').read_text())
    locales = {'enUS': {}, 'ruRU': {}}
    for i in range(len(data) - 5):
        if data[i] in locales and data[i + 1] == '[':
            key, end = static_key(data, i + 2)
            if key is not None and data[end:end + 2] == [']', '=']:
                value, _ = static_key(data, end + 2)
                assert value is not None, ('Nonliteral translation', key)
                assert key not in locales[data[i]], ('Duplicate translation', data[i], key)
                locales[data[i]][key] = value
    refs = set()
    for path in (ROOT / 'Gladdy').rglob('*.lua'):
        if 'Libs' in path.parts or path.name == 'Lang.lua':
            continue
        items = tokens(path.read_text())
        for i in range(len(items) - 3):
            if items[i:i + 2] == ['L', '[']:
                assert items[i:i + 4] != ['L', '[', 'L', '['], ('Nested translation', path)
                key, end = static_key(items, i + 2)
                if key is not None and items[end] == ']':
                    refs.add(key)
            if items[i:i + 2] == ['NewModule', '(']:
                key = literal(items[i + 2])
                if key and key not in ('EventListener', 'VersionCheck'):
                    refs.add(key)
    refs.update(('xx:xx Miliseconds', 'xx Seconds'))
    failures = []
    placeholders = re.compile(r'%%|%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs]')
    for key in sorted(refs):
        for locale, entries in locales.items():
            if not entries.get(key):
                failures.append(f'{locale}: missing {key!r}')
    for key in sorted(set(locales['enUS']) | set(locales['ruRU'])):
        if key not in locales['enUS'] or key not in locales['ruRU']:
            failures.append(f'Unpaired translation: {key!r}')
        elif placeholders.findall(locales['enUS'][key]) != placeholders.findall(locales['ruRU'][key]):
            failures.append(f'Format placeholders differ: {key!r}')
    assert not failures, '\n'.join(failures)
    print(f'PASS: {len(refs)} static and module localization keys; {len(locales["ruRU"])} paired translations and format placeholders')

if __name__ == '__main__':
    check()
