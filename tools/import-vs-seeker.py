"""Export the pinned FireRed Vs. Seeker rematch ladder and giver dialogue."""
import argparse
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered'
raw = (source / 'src/vs_seeker.c').read_text(encoding='utf8')
table = raw.split('static const struct RematchData sRematches[] = {', 1)[1].split('\n};', 1)[0]
rematches = {}
trainers = json.loads((root / 'assets/kanto/trainer-builds.json').read_text(encoding='utf8'))['trainers']
for ids, map_id in re.findall(r'\{\s*\{([^}]+)\},\s*MAP\((\w+)\)\s*\}', table):
    chain = [part.strip() for part in ids.split(',') if part.strip()]
    assert 2 <= len(chain) <= 6 and all(key == 'SKIP' or key in trainers for key in chain), chain
    rematches[chain[0]] = {'map': map_id, 'parties': ['' if key == 'SKIP' else key for key in chain]}
assert len(rematches) > 150
texts = {}
for path in (source / 'data').rglob('*.inc'):
    content = path.read_text(encoding='utf8')
    for label, body in re.findall(r'^(VermilionCity_PokemonCenter_1F_Text_\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)', content, re.M | re.S):
        texts[label] = ''.join(re.findall(r'\.string "([^"\n]*)"', body)).replace('\\p', '\n\n').replace('\\n', ' ').replace('\\l', ' ').replace('$', '')
result = {'revision': 'ce6406d8c2eaf46d543c8a2606de0c3cb1951982', 'rematches': rematches, 'texts': texts}
target = root / 'assets/kanto/vs-seeker.json'
payload = json.dumps(result, separators=(',', ':')) + '\n'
parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
if args.check:
    assert target.read_text(encoding='utf8') == payload
else:
    target.write_text(payload, encoding='utf8')
print('VS SEEKER SOURCE CHECK:', len(rematches), 'rematch ladders')
