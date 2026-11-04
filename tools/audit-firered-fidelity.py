"""Read-only comparison with the pinned FireRed source (no ROM or save needed).

Writes diagnostic evidence in captures/. Matching map data does not imply that
all original scripts execute: runtime handlers and story tests need separate review.
"""
import json
import re
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered'
read = lambda p: json.loads(p.read_text(encoding='utf8'))
maps = read(root / 'assets/kanto/maps.json')
original = {m['id']: m for p in (source / 'data/maps').glob('*/map.json') for m in [read(p)]}
layouts = {m['id']: m for m in read(source / 'data/layouts/layouts.json')['layouts'] if 'id' in m}
differences = []
for key, current in maps.items():
    m = original[key]
    layout = layouts[m['layout']]
    raw = (source / layout['blockdata_filepath']).read_bytes()
    expected = dict(width=layout['width'], height=layout['height'], cells=list(struct.unpack('<'+'H'*(len(raw)//2), raw)),
                    warps=m.get('warp_events', []), connections=m.get('connections') or [],
                    objects=m.get('object_events', []), signs=m.get('bg_events', []))
    for field, value in expected.items():
        actual = [{k:v for k,v in o.items() if k!='battle'} for o in current[field]] if field=='objects' else current[field]
        if actual != value: differences.append([key, field])

norm = lambda text: re.sub('[^a-z0-9]', '', text.lower())
ids = {norm(m['key']):m['id'] for m in read(root / 'data/roster.json')}
encounters = {}
for group in read(source / 'src/data/wild_encounters.json')['wild_encounter_groups']:
    if not group.get('for_maps'): continue
    fields = {f['type']:f for f in group['fields']}
    for record in group['encounters']:
        if record['map'] not in maps or 'LeafGreen' in record['base_label']: continue
        entry = {}
        for kind in ['land_mons', 'water_mons', 'fishing_mons']:
            if kind not in record: continue
            slots = [dict(slot=i, id=ids[norm(m['species'].removeprefix('SPECIES_'))], min=m['min_level'], max=m['max_level'], weight=fields[kind]['encounter_rates'][i]) for i,m in enumerate(record[kind]['mons'])]
            if kind=='fishing_mons':
                for rod, indices in fields[kind]['groups'].items(): entry[rod]=[s for s in slots if s['slot'] in indices]
            else: entry[kind]=slots
        if entry: encounters[record['map']]=entry
current_encounters = read(root / 'assets/kanto/encounters.json')
encounter_diff = sorted(k for k in encounters.keys() | current_encounters.keys() if encounters.get(k)!=current_encounters.get(k))

party_text = (source / 'src/data/trainer_parties.h').read_text(encoding='utf8')
parties = {}
for name, body in re.findall(r'^static const struct \w+ (sParty_\w+)\[\] = \{(.*?)(?=^static const|\Z)', party_text, re.M|re.S):
    team = []
    for entry in re.findall(r'\{((?:[^{}]|\{[^{}]*\})*)\}', body, re.S):
        level = re.search(r'\.lvl = (\d+)', entry); species = re.search(r'\.species = SPECIES_(\w+)', entry)
        if not level or not species: continue
        moves = re.search(r'\.moves = \{([^}]+)\}', entry)
        team.append(dict(id=ids[norm(species[1])], level=int(level[1]), moves=[norm(m) for m in re.findall(r'MOVE_(\w+)', moves[1]) if m!='NONE'] if moves else None))
    parties[name]=team
trainers = {}
for name, body in re.findall(r'\[(TRAINER_\w+)\] = \{(.*?)\n    \}', (source / 'src/data/trainers.h').read_text(encoding='utf8'), re.S):
    party = re.search(r'\.party = \w+\((sParty_\w+)\)', body)
    if party: trainers[name]=parties[party[1]]

dialogue = read(root / 'assets/kanto/npc-dialogue.json')
scripted = {o['script'] for m in maps.values() for o in m['objects']+m['signs'] if o.get('script') not in [None,'','0x0']}
no_first_text = sorted(s for s in scripted if not dialogue.get(s, {}).get('text'))
report = dict(source=read(root / 'assets/kanto/source.json'), source_map_count=len(original), included_maps=len(maps),
              map_differences=differences, excluded_maps=sorted(original.keys()-maps.keys()),
              objects=sum(len(m['objects']) for m in maps.values()), signs=sum(len(m['signs']) for m in maps.values()),
              trainer_actors=sum('battle' in o for m in maps.values() for o in m['objects']),
              encounter_maps=len(encounters), encounter_differences=encounter_diff,
              source_trainer_definitions=len(trainers), unique_object_sign_scripts=len(scripted),
              scripts_without_first_text=no_first_text,
              dialogue_warning='No first text is not a missing event: battles, gifts, warps and services have dedicated handlers. Text presence is not script parity.')
captures = root / 'captures'; captures.mkdir(exist_ok=True)
(captures / 'firered-fidelity-data.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf8')
(captures / 'firered-source-trainers.json').write_text(json.dumps(trainers, indent=2)+'\n', encoding='utf8')
print(json.dumps({k:v for k,v in report.items() if k not in ['scripts_without_first_text','dialogue_warning']}, indent=2))
print('Scripts without first text (not a missing-event count):', len(no_first_text))
assert not differences and not encounter_diff, 'Source data drift; inspect captures/firered-fidelity-data.json'
