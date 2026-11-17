"""Export the four local FireRed Trainer Tower sets and floor-dependent team picks."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered'
sets = (source / 'src/trainer_tower_sets.c').read_text()
engine = (source / 'src/trainer_tower.c').read_text()
def body(text, start):
    begin = text.index('{', start)
    depth = 1
    for i in range(begin + 1, len(text)):
        depth += (text[i] == '{') - (text[i] == '}')
        if depth == 0: return text[begin + 1:i]
    raise ValueError('Unbalanced source initializer')
def objects(text):
    depth = 0
    begin = 0
    result = []
    for i, char in enumerate(text):
        if char == '{':
            if depth == 0: begin = i + 1
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0: result.append(text[begin:i])
    return result
def token(text, field): return re.search(r'\.'+field+r'\s*=\s*([^,\n]+)',text)[1].strip()
normalize = lambda text: re.sub('[^a-z0-9]', '', text.lower())
aliases={'hijumpkick':'highjumpkick','vicegrip':'visegrip','faintattack':'feintattack','smellingsalt':'smellingsalts'}
move_id=lambda value: aliases.get(normalize(value),normalize(value))
roster = json.loads((root/'data/roster.json').read_text(encoding='utf8'))
ids = {normalize(mon['key']):mon['id'] for mon in roster}
natures = ['Hardy','Lonely','Brave','Adamant','Naughty','Bold','Docile','Relaxed','Impish','Lax','Timid','Hasty','Serious','Jolly','Naive','Modest','Mild','Quiet','Bashful','Rash','Calm','Gentle','Sassy','Careful','Quirky']
stats = {'hp':'hp','attack':'atk','defense':'def','speed':'spe','spAttack':'spa','spDefense':'spd'}
floors = {}
for match in re.finditer(r'static const struct TrainerTowerFloor (\w+)\s*=', sets):
    floor = body(sets,match.end()); trainers=[]
    for trainer in objects(body(floor,floor.index('.trainers'))):
        if '.name' not in trainer: continue
        mons=[]
        for mon in objects(body(trainer,trainer.index('.mons'))):
            species=token(mon,'species').removeprefix('SPECIES_')
            personality=int(token(mon,'personality'),0)
            ot=token(mon,'otId')
            numbers=[int(n,0) for n in re.findall(r'0x[0-9a-fA-F]+|\d+',ot)]
            otid=numbers[0] | (numbers[1]<<numbers[2]) if len(numbers)==3 else numbers[0]
            mons.append({'id':ids[normalize(species)],'moves':[move_id(m) for m in re.findall(r'MOVE_(\w+)',body(mon,mon.index('.moves')))],
                         'held_item':normalize(token(mon,'heldItem').removeprefix('ITEM_')),
                         'ivs':{value:int(token(mon,key+'IV')) for key,value in stats.items()},
                         'training':{value:int(token(mon,key+'EV')) for key,value in stats.items()},
                         'ability_slot':int(token(mon,'abilityNum')),'nature':natures[personality%25],
                         'shiny':((otid&65535)^(otid>>16)^(personality&65535)^(personality>>16))<8})
        trainers.append({'name':re.search(r'\.name\s*=\s*_\("([^"]*)"\)',trainer)[1],
                         'class':token(trainer,'facilityClass').removeprefix('FACILITY_CLASS_'),'mons':mons})
    floors[match[1]]={'type':token(floor,'challengeType').removeprefix('CHALLENGE_TYPE_').lower(),
                     'prize':normalize(token(floor,'prize').removeprefix('TTPRIZE_')),'trainers':trainers}
formats={}
mapping=body(sets,sets.index('gTrainerTowerFloors['))
for match in re.finditer(r'\[CHALLENGE_TYPE_(\w+)\]\s*=',mapping):
    formats[match[1].lower()]=re.findall(r'&([\w]+)',body(mapping,match.end()))
indices={}
for name, key in [('sSingleBattleChallengeMonIdxs','single'),('sDoubleBattleChallengeMonIdxs','double'),('sKnockoutChallengeMonIdxs','knockout')]:
    indices[key]=[[int(n) for n in re.findall(r'\d+',row)] for row in objects(body(engine,engine.index(name+'[')))]
assert len(formats)==4 and all(len(f)==8 for f in formats.values())
for mode in formats:
    for i,label in enumerate(formats[mode]):
        floor=floors[label]
        for j,index in enumerate(indices[floor['type']][i]):
            assert len(floor['trainers'][j if floor['type']!='single' else 0]['mons'])>index
graphics={}
for gfx, facility in re.findall(r'\{(OBJ_EVENT_GFX_\w+),\s*(FACILITY_CLASS_\w+),',engine):
    graphics[facility.removeprefix('FACILITY_CLASS_')]=[gfx]
for left, right, facility in re.findall(r'\{(OBJ_EVENT_GFX_\w+),\s*(OBJ_EVENT_GFX_\w+),\s*(FACILITY_CLASS_\w+),',engine):
    graphics[facility.removeprefix('FACILITY_CLASS_')]=[left,right]
result={'formats':formats,'floors':floors,'indices':indices,'graphics':graphics}
(root/'assets/kanto/trainer-tower.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(f'Trainer Tower: {len(floors)} floor definitions, 4 formats x 8 floors')
