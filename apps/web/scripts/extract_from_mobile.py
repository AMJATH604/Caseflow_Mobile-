"""Extract the English and Tamil strings, and the state/district list, from the
Flutter app into JSON for the web, so both apps use the same wording.

Run from the repo root:  python apps/web/scripts/extract_from_mobile.py
Re-run whenever app_localizations.dart or geo_data.dart changes.
"""
import io
import json
import re

L10N_SRC = 'apps/mobile/lib/services/app_localizations.dart'
GEO_SRC = 'apps/mobile/lib/models/geo_data.dart'
OUT = 'apps/web/src/lib/i18n/{}.json'
GEO_OUT = 'apps/web/src/lib/geo.json'

STR = r"""(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")"""
ENTRY = re.compile(r"'([a-z0-9_]+)'\s*:\s*(" + STR + r"(?:\s*" + STR + r")*)\s*,")
PIECE = re.compile(r"""'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)\"""")


def grab(src, start, lang):
    marker = "'" + lang + "': {"
    i = src.index(marker, start) + len(marker)
    depth, j = 1, i
    while depth:
        c = src[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
        j += 1
    out = {}
    for m in ENTRY.finditer(src[i:j - 1]):
        val = ''.join(a or b for a, b in PIECE.findall(m.group(2)))
        val = (val.replace("\\'", "'").replace('\\"', '"')
                  .replace('\\n', '\n').replace('\\$', '$'))
        # Dart interpolation ($name / ${name}) -> i18next ({{name}})
        val = re.sub(r'\$\{?(\w+)\}?', r'{{\1}}', val)
        out[m.group(1)] = val
    return out


def main():
    src = io.open(L10N_SRC, encoding='utf-8').read()
    start = src.index('_localizedValues = {')
    en, ta = grab(src, start, 'en'), grab(src, start, 'ta')
    for lang, d in (('en', en), ('ta', ta)):
        with io.open(OUT.format(lang), 'w', encoding='utf-8') as f:
            f.write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
    missing = sorted(set(en) - set(ta))
    print('strings: en', len(en), '| ta', len(ta), '| untranslated', len(missing), missing[:10])

    geo_src = io.open(GEO_SRC, encoding='utf-8').read()
    body = geo_src[geo_src.index('{') + 1:]
    geo = {m.group(1): re.findall(r"'([^']+)'", m.group(2))
           for m in re.finditer(r"'([^']+)'\s*:\s*\[(.*?)\]", body, flags=re.S)}
    with io.open(GEO_OUT, 'w', encoding='utf-8') as f:
        f.write(json.dumps(geo, ensure_ascii=False, indent=1) + '\n')
    print('geo: states', len(geo), '| districts', sum(map(len, geo.values())))


if __name__ == '__main__':
    main()
