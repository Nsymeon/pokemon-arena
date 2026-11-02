"""Compile National evolution and event data from the pinned FireRed source."""
import json, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered'
norm=lambda s:re.sub('[^a-z0-9]','',s.lower())
roster=json.loads((root/'data/roster.json').read_text())
ids={norm(m['key']):m['id'] for m in roster}
def write(name,data): (root/'assets/kanto'/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')
evolutions={}
text=(source/'src/data/pokemon/evolution.h').read_text()
for species,body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*\{(.*?)\},?\s*(?=\[|\n\};)',text,re.S):
    rules=[]
    for method,param,target in re.findall(r'\{EVO_(\w+),\s*(\w+),\s*SPECIES_(\w+)\}',body+'}'):
        if norm(target) in ids: rules.append(dict(method=method,param=int(param) if param.isdigit() else norm(param.removeprefix('ITEM_')),target=ids[norm(target)]))
    if norm(species) in ids and rules: evolutions[str(ids[norm(species)])]=rules
assert evolutions['1'][0]==dict(method='LEVEL',param=16,target=2)
assert evolutions['290'][1]['target']==292
write('evolutions.json',evolutions)
roamer=(source/'src/roamer.c').read_text()
routes={}
for row in re.findall(r'\{MAP_NUM\(MAP_ROUTE.*?\}',roamer):
    maps=re.findall(r'MAP_NUM\((MAP_\w+)\)',row)
    if maps: routes[maps[0]]=maps[1:]
specials=(source/'src/field_specials.c').read_text()
coords=re.search(r'sDeoxysCoords\[\]\[2\] = \{(.*?)\};',specials,re.S)[1]
caps=re.search(r'sDeoxysStepCaps\[\] = \{(.*?)\};',specials,re.S)[1]
write('postgame.json',dict(routes=routes,triangle=[[int(x),int(y)] for x,y in re.findall(r'\{\s*(\d+),\s*(\d+)\}',coords)],caps=[int(x) for x in re.findall(r'\d+',caps)]))
trainers=(source/'src/data/trainers.h').read_text(); parties=(source/'src/data/trainer_parties.h').read_text()
teams={}; alias={'hijumpkick':'highjumpkick','vicegrip':'visegrip','faintattack':'feintattack','smellingsalt':'smellingsalts'}
for key,body in re.findall(r'\[TRAINER_((?:ELITE_FOUR_(?:LORELEI|BRUNO|AGATHA|LANCE)(?:_2)?|CHAMPION_(?:FIRST|REMATCH)_\w+))\]\s*=\s*\{(.*?)\n    \},',trainers,re.S):
    symbol=re.search(r'\.party\s*=\s*\w+\((\w+)\)',body)[1]
    party=re.search(re.escape(symbol)+r'\[\]\s*=\s*\{(.*?)\n\};',parties,re.S)[1]
    members=[]
    for mon in re.findall(r'\{(.*?)\n    \}',party,re.S):
        species=re.search(r'\.species = SPECIES_(\w+)',mon)[1]
        moves=[alias.get(norm(m),norm(m)) for m in re.findall(r'MOVE_(\w+)',mon) if m!='NONE']
        item=re.search(r'\.heldItem = ITEM_(\w+)',mon)
        members.append(dict(id=ids[norm(species)],level=int(re.search(r'\.lvl = (\d+)',mon)[1]),moves=moves,item=norm(item[1]) if item else ''))
    assert len(members) in (5,6),key
    teams[key]=members
assert len(teams)==14
write('league-parties.json',teams)
entries=json.loads((root/'assets/kanto/pokedex-entries.json').read_text(encoding='utf8'))
text=(source/'src/data/pokemon/pokedex_text_fr.h').read_text(encoding='utf8')
descriptions={name:' '.join(''.join(re.findall(r'"(.*?)"',body)).replace('\\n',' ').split()) for name,body in re.findall(r'const u8 (\w+)\[\] = _\((.*?)\);',text,re.S)}
for species,body in re.findall(r'\[NATIONAL_DEX_(\w+)\]\s*=\s*\{(.*?)\n    \}',(source/'src/data/pokemon/pokedex_entries.h').read_text(),re.S):
    if norm(species) not in ids: continue
    description=re.search(r'\.description = (\w+)',body)[1]
    if description not in descriptions: continue
    entries[str(ids[norm(species)])]=dict(category=re.search(r'\.categoryName = _\("(.*?)"\)',body)[1],height=int(re.search(r'\.height = (\d+)',body)[1])/10,weight=int(re.search(r'\.weight = (\d+)',body)[1])/10,text=descriptions[description],source='Pokemon FireRed')
assert all(str(i) in entries for i in range(1,387))
write('pokedex-entries.json',entries)
dex=json.loads((root/'data/source/pokedex.json').read_text(encoding='utf8'))
write('gender-ratios.json',{str(m['id']):(-1 if dex[m['key']].get('gender')=='N' else 0 if dex[m['key']].get('gender')=='M' else 1 if dex[m['key']].get('gender')=='F' else dex[m['key']].get('genderRatio',{'F':.5})['F']) for m in roster})
print(f'National content: {len(evolutions)} evolution families, {len(routes)} roaming routes, {len(teams)} League parties')
