"""Export starter-dependent FireRed story parties from the pinned decompilation."""
import json, re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered/src/data'
trainers=(source/'trainers.h').read_text()
parties=(source/'trainer_parties.h').read_text()
norm=lambda value: re.sub('[^a-z0-9]','',value.lower())
ids={norm(m['key']):m['id'] for m in json.loads((root/'data/roster.json').read_text())}
result={}
for match in re.finditer(r'\[(TRAINER_(?:RIVAL_[A-Z0-9_]+|LEADER_BROCK|GIOVANNI_[A-Z0-9_]+))\]\s*=\s*\{(.*?)\n    \},',trainers,re.S):
    key,body=match.groups()
    symbol=re.search(r'\.party\s*=\s*\w+\((\w+)\)',body)[1]
    party=re.search(re.escape(symbol)+r'\[\]\s*=\s*\{(.*?)\n\};',parties,re.S)[1]
    members=[]
    for level,species in re.findall(r'\.lvl\s*=\s*(\d+),\s*\.species\s*=\s*SPECIES_(\w+)',party):
        if norm(species) not in ids: break
        members.append([ids[norm(species)],int(level)])
    else:
        assert members, key
        result[key.removeprefix('TRAINER_')]=members
target=root/'assets/kanto/story-parties.json'
target.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(f'Exported {len(result)} source story parties to {target.name}')
