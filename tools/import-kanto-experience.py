"""Export Gen III EXP yields/growth groups from the pinned FireRed source checkout."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered/src/data/pokemon/species_info.h'
normalize = lambda value: re.sub('[^a-z0-9]', '', value.lower())
entries = {}
for name, body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*\{\s*\n(.*?)\n    \}', source.read_text(encoding='utf8'), re.S):
    reward = re.search(r'\.expYield\s*=\s*(\d+)', body)
    growth = re.search(r'\.growthRate\s*=\s*GROWTH_(\w+)', body)
    if reward and growth:
        entries[normalize(name)] = {'yield': int(reward[1]), 'growth': growth[1]}
roster = json.loads((root / 'data/roster.json').read_text(encoding='utf8'))
result = {}
for mon in roster:
    value = entries.get(normalize(mon['key']))
    if value is None:
        assert mon['id'] > 386, f'Missing FireRed species: {mon}'
        # Existing later-generation guests use a documented arena fallback.
        value = {'yield': 100, 'growth': 'MEDIUM_FAST'}
    result[str(mon['id'])] = value
assert len(result) == len(roster)
(root / 'assets/kanto/experience.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
print(f'Exported experience rules for {len(result)} species')
