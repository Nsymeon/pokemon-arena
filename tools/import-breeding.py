"""Compile FRLG breeding families, egg groups, cycles and inherited moves."""
import json,re
from PIL import Image
from pathlib import Path
r=Path(__file__).resolve().parents[1];src=r/'data/source/pokefirered'
read=lambda p: p.read_text(encoding='utf8')
norm=lambda s:re.sub('[^a-z0-9]','',s.lower())
roster=json.loads(read(r/'data/roster.json')); ids={norm(m['key']):int(m['id']) for m in roster}
book=json.loads(read(r/'data/adventure-learnsets.json')); evolution=json.loads(read(r/'assets/kanto/evolutions.json'))
prevo={int(rule['target']):int(parent) for parent,rules in evolution.items() for rule in rules}
aliases={'hijumpkick':'highjumpkick','vicegrip':'visegrip','faintattack':'feintattack','smellingsalt':'smellingsalts'}
egg={ids[norm(name)]:[aliases.get(norm(move),norm(move)) for move in re.findall(r'MOVE_(\w+)',moves)] for name,moves in re.findall(r'egg_moves\((\w+),(.*?)\)',read(src/'src/data/pokemon/egg_moves.h'),re.S) if norm(name) in ids}
out={}
for name,body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*\{\s*\n(.*?)\n    \}',read(src/'src/data/pokemon/species_info.h'),re.S):
 if norm(name) not in ids:continue
 id=ids[norm(name)];base=id
 while base in prevo:base=prevo[base]
 out[str(id)]={'groups':re.findall(r'EGG_GROUP_(\w+)',body),'cycles':int(re.search(r'\.eggCycles = (\d+)',body)[1]),'baby':base,'moves':[m for m in egg.get(id,[]) if m in book['moves']]}
missing=set(range(1,387))-{int(i) for i in out}
assert len(out)==386 and out['1']['baby']==1 and out['26']['baby']==172, (len(out),out.get('26'))
(r/'assets/kanto/breeding.json').write_text(json.dumps(out,separators=(',',':'))+'\n',encoding='utf8')
print('Compiled breeding rules:',len(out),'species,',sum(len(x['moves']) for x in out.values()),'egg moves')
image=Image.open(src/'graphics/pokemon/egg/front.png')
image.info['transparency']=0
image=image.convert('RGBA'); image=image.crop(image.getbbox())
image.save(r/'assets/kanto/egg.png')
