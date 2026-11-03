"""Report source dialogue coverage; requires the pinned local FireRed checkout.

Missing first text is not a missing service: items, warps and scripted battles
often have no direct dialogue. Runtime service handlers live in adventure_*.gd.
"""
import json,re
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=json.loads((r/'assets/kanto/maps.json').read_text(encoding='utf8'))
d=json.loads((r/'assets/kanto/npc-dialogue.json').read_text(encoding='utf8'))
blocks={}
for path in (r/'data/source/pokefirered/data').rglob('*.inc'):
 blocks.update(dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',path.read_text(encoding='utf8'),re.M|re.S)))
missing=[];gifts=[]
for key,room in m.items():
 for o in room['objects']+room['signs']:
  s=o.get('script','')
  if not s or s=='0x0':continue
  if not d.get(s,{}).get('text') and not o.get('battle'): missing.append(s)
  body=blocks.get(s,'')
  if re.search(r'(giveitem|givemon|givedecoration)',body):gifts.append((s,re.findall(r'giveitem\s+([^\n]+)|givemon\s+([^\n]+)',body)))
print('Dialogue missing first text:',len(set(missing)));print('\n'.join(sorted(set(missing))[:40]))
print('Direct gift scripts:',len(gifts))
