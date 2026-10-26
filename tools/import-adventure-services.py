"""Export bounded dialogue, tutor identities and catch data from the pinned FRLG checkout.

This reads data only; no source scripts are evaluated at runtime.
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered'
out = root / 'assets/kanto'
text = '\n'.join(p.read_text(encoding='utf8') for p in (source / 'data').rglob('*.inc'))
blocks = dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)', text, re.M | re.S))
tutors, dialogue = {}, {}
for label, body in blocks.items():
    match = re.search(r'MOVETUTOR_(\w+)', body)
    if match:
        tutors[label] = match[1].lower().replace('_', '')
    match = re.search(r'msgbox\s+(\w+)', body)
    if match and match[1] in blocks:
        line = ' '.join(re.findall(r'"([^"\n]*)"', blocks[match[1]]))
        for escape in ['\\n', '\\l', '\\p']:
            line = line.replace(escape, ' ')
        line = re.sub(r'\{[^}]*\}', '', line.replace('$', ''))
        if line:
            dialogue[label] = line[:550]
for _ in range(3):
    for label, body in blocks.items():
        if label in tutors:
            continue
        for dest in re.findall(r'(?:goto|call)\s+(\w+)', body):
            if dest in tutors:
                tutors[label] = tutors[dest]
                break
maps = json.loads((out / 'maps.json').read_text())
scripts = {o.get('script') for m in maps.values() for o in m['objects']}
tutors = {k: v for k, v in tutors.items() if k in scripts}
tutors['SaffronCity_CopycatsHouse_2F_EventScript_Copycat'] = 'mimic'
(out / 'tutors.json').write_text(json.dumps(tutors, indent=2), encoding='utf8')
(out / 'dialogue.json').write_text(json.dumps(dialogue, ensure_ascii=False), encoding='utf8')
normalize = lambda value: re.sub('[^a-z0-9]', '', value.lower())
roster = json.loads((root / 'data/roster.json').read_text(encoding='utf8'))
ids = {normalize(m['key']): str(m['id']) for m in roster}
rates = {}
species = (source / 'src/data/pokemon/species_info.h').read_text()
for name, body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*\{(.*?)\n    \}', species, re.S):
    catch = re.search(r'\.catchRate\s*=\s*(\d+)', body)
    flee = re.search(r'\.safariZoneFleeRate\s*=\s*(\d+)', body)
    if normalize(name) in ids and catch:
        rates[ids[normalize(name)]] = {'catch': int(catch[1]), 'flee': int(flee[1]) if flee else 0}
(out / 'catch-rates.json').write_text(json.dumps(rates, indent=2), encoding='utf8')
print(f'Exported {len(tutors)} tutors, {len(dialogue)} dialogue records, {len(rates)} catch rates')
