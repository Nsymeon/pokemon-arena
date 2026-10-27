"""Export FRLG EV yields plus the two retained post-Gen3 species from cached PokeAPI data."""
import json, re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
norm = lambda text: re.sub('[^a-z0-9]', '', text.lower())
roster = json.loads((root/'data/roster.json').read_text(encoding='utf8'))
ids = {norm(mon['key']): str(mon['id']) for mon in roster}
source = (root/'data/source/pokefirered/src/data/pokemon/species_info.h').read_text()
names = {'HP':'hp','Attack':'atk','Defense':'def','SpAttack':'spa','SpDefense':'spd','Speed':'spe'}
yields = {}
for name, body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*\{\s*\n(.*?)\n    \}', source, re.S):
    if norm(name) in ids:
        values = {names[key]: int(n) for key,n in re.findall(r'\.evYield_(\w+)\s*=\s*(\d+)', body)}
        assert len(values)==6, name
        yields[ids[norm(name)]] = values
extras = json.loads((root/'data/source/extra-ev-yields.json').read_text(encoding='utf-8-sig'))
api_names = {'hp':'hp','attack':'atk','defense':'def','special-attack':'spa','special-defense':'spd','speed':'spe'}
for species, stats in extras.items():
    yields[species] = {api_names[s['stat']]: s['effort'] for s in stats}
assert len(yields)==len(roster)==158
assert all(len(v)==6 and 1<=sum(v.values())<=3 for v in yields.values())
(root/'assets/kanto/ev-yields.json').write_text(json.dumps(yields, indent=2)+'\n', encoding='utf8')
print('Exported EV yields for',len(yields),'species')
