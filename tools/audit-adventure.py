"""Validate map connectivity/data; runtime quest gates are checked by Godot smoke tests."""
import json, re, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
maps=json.loads((root/'assets/kanto/maps.json').read_text(encoding='utf8'))
ports=re.findall(r'"(MAP_[A-Z0-9_]+)"',(root/'adventure_sevii.gd').read_text(encoding='utf8').split('const PORTS=')[1].split('\n')[0])
external={'MAP_DYNAMIC','MAP_TRADE_CENTER','MAP_UNION_ROOM'}
warps=0
for key,room in maps.items():
    assert len(room['cells'])==room['width']*room['height'],key
    for link in room['connections']: assert link['map'] in maps,(key,link)
    for warp in room['warps']:
        warps+=1
        dest=warp['dest_map']
        assert dest in maps or dest in external,(key,warp)
        if dest in maps: assert 0<=int(warp['dest_warp_id'])<len(maps[dest]['warps']),(key,warp)
reached={'MAP_PALLET_TOWN'};todo=list(reached)
while todo:
    key=todo.pop();room=maps[key]
    targets=[x['map'] for x in room['connections']]+[x['dest_map'] for x in room['warps']]+(ports if key in ports else [])
    for dest in targets:
        if dest in maps and dest not in reached: reached.add(dest);todo.append(dest)
unused=set(maps)-reached
assert all('UNUSED_HOUSE' in key for key in unused),unused
assert len(reached)==388 and len(maps)==392,(len(reached),len(maps))
manifest=json.loads((root/'assets/audio/cries/sources.json').read_text())
roster=json.loads((root/'data/roster.json').read_text())
for mon in roster:
    entry=manifest[str(mon['id'])];path=root/'assets/audio/cries'/entry['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],path
print(f'PASS: {len(maps)} maps, {warps} valid warp targets, {len(reached)} connected maps with ferries; four original unused houses excluded. {len(roster)} verified cry assets.')
