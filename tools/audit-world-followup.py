"""Guard against missing Kanto trainers, buildings, museum props and stair markers."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def data(name):return json.loads((root/'assets/kanto'/name).read_text(encoding='utf8'))
rooms=data('maps.json'); visual=data('world-3d.json'); events=data('events.json'); checked=0
for key,room in rooms.items():
    if key=='MAP_VIRIDIAN_FOREST' or key.endswith('_GYM') or key.startswith('MAP_ROUTE'):
        for npc in room['objects']:
            if npc.get('trainer_type')=='TRAINER_TYPE_NORMAL':
                assert npc.get('battle',{}).get('party'), (key,npc['script'])
                checked+=1
    if room['type'] in ['MAP_TYPE_CITY','MAP_TYPE_TOWN']:
        for dest in {d['dest_map'] for d in room['warps']}:
            if rooms.get(dest,{}).get('type')!='MAP_TYPE_INDOOR':continue
            # City boundary gates, ferry map transitions and the ship are not houses.
            if '_HARBOR' in dest or dest.startswith('MAP_ROUTE') or dest=='MAP_SSANNE_EXTERIOR':continue
            doors=[d for d in room['warps'] if d['dest_map']==dest]
            assert any(b[0]<=d['x']<b[0]+b[2] and b[1]<=d['y']<b[1]+b[3] for b in visual[key]['buildings'] for d in doors),(key,dest)
    for i,behavior in enumerate(events[key]['behavior']):
        if behavior in [0x2a,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f]:assert i in visual[key]['stairs'],(key,i,'stairs')
        if behavior==0x61:assert i in visual[key]['ladders'],(key,i,'ladder')
for floor in ['1F','2F']:assert len(visual['MAP_PEWTER_CITY_MUSEUM_'+floor]['exhibits'])==2
print(f'PASS: {checked} Kanto trainers, all city building destinations, both museum floors, all source stair/ladder behaviors')
