"""Extract Kanto FireRed NPC trade offers from the local pret source checkout."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered'
text=(source/'src/data/ingame_trades.h').read_text()
text=re.sub(r'#if defined\(FIRERED\)(.*?)#elif defined\(LEAFGREEN\).*?#endif',r'\1',text,flags=re.S)
norm=lambda v:re.sub('[^a-z0-9]','',v.lower())
ids={norm(m['key']):m['id'] for m in json.loads((root/'data/roster.json').read_text())}
records={}
for name,body in re.findall(r'\[(INGAME_TRADE_\w+)\]\s*=\s*\{(.*?)\n    \}',text,re.S):
    records[name]={'give':ids[norm(re.search(r'\.requestedSpecies = SPECIES_(\w+)',body)[1])], 'receive':ids[norm(re.search(r'\.species = SPECIES_(\w+)',body)[1])], 'nickname':re.search(r'\.nickname = _\("(.*?)"\)',body)[1], 'trainer':re.search(r'\.otName = _\("(.*?)"\)',body)[1], 'ability':int(re.search(r'\.abilityNum = (\d+)',body)[1])}
result={}
for m in json.loads((root/'assets/kanto/maps.json').read_text()).values():
    path=source/'data/maps'/m['name']/'scripts.inc'
    if not path.exists():continue
    blocks=dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',path.read_text(),re.M|re.S))
    for o in m['objects']:
        match=re.search(r'setvar VAR_0x8008, (INGAME_TRADE_\w+)',blocks.get(o.get('script',''),''))
        if match:result[o['script']]=records[match[1]]
assert len(result)==9,len(result)
(root/'assets/kanto/trades.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print('Imported',len(result),'FireRed NPC trades')
