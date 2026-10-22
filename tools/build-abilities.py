"""Build the FRLG normal ability slots from the checked-in pret species table."""
import json, re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda path: (root/path).read_text(encoding='utf8')
dex = json.loads(read('data/source/pokedex.json'))
roster = json.loads(read('data/roster.json'))
source = read('data/source/frlg-species-info.h')
names = {re.sub('[^A-Z0-9]', '', a.upper()): a for p in dex.values() for a in p.get('abilities', {}).values()}
result = {}
for mon in roster:
    key = mon['key'].upper().replace('NIDORANF', 'NIDORAN_F').replace('NIDORANM', 'NIDORAN_M').replace('MRMIME', 'MR_MIME')
    match = re.search(r'\[SPECIES_'+key+r'\]\s*=\s*\{(.*?)\n    \}', source, re.S)
    if match:
        values = re.search(r'\.abilities = \{(.*?)\}', match[1])[1].split(',')
        options = [names[re.sub('[^A-Z0-9]', '', v.replace('ABILITY_', '').strip())] for v in values if v.strip() != 'ABILITY_NONE']
    else:
        assert mon['id'] in (599, 821), f'Missing FRLG species: {mon}'
        options = [v for k, v in dex[mon['key']]['abilities'].items() if k != 'H']
    result[str(mon['id'])] = list(dict.fromkeys(options))
(root/'data/abilities.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf8')
moves = json.loads(read('data/source/moves.json'))
(root/'data/move-flags.json').write_text(json.dumps({k:v.get('flags', {}) for k,v in moves.items()}), encoding='utf8')
assert len(result) == 158
assert result['19'] == ['Run Away', 'Guts'] and result['94'] == ['Levitate']
print(f'PASS: {len(result)} species, {len(set(a for options in result.values() for a in options))} normal abilities')
