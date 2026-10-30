"""Check modern map coverage and visual geometry against authoritative source tiles."""
import json
import struct
from pathlib import Path

root=Path(__file__).resolve().parents[1]
maps=json.loads((root/'assets/kanto/maps.json').read_text(encoding='utf8'))
modern=json.loads((root/'assets/kanto/world-3d.json').read_text(encoding='utf8'))
assert maps.keys()==modern.keys(), 'Modern map coverage differs from playable maps'
buildings=0
for key,room in maps.items():
    view=modern[key]; width=room['width']; height=room['height']
    assert len(view['tiles'])==width*height,key
    ground=root/view['ground'].removeprefix('res://')
    assert ground.is_file(),ground
    with ground.open('rb') as file: header=file.read(24)
    assert header[:8]==b'\x89PNG\r\n\x1a\n',ground
    assert struct.unpack('>II',header[16:24])==(width*16,height*16),ground
    doors={(d['x'],d['y']) for d in room['warps']}
    for x,y,w,h,style,color in view['buildings']:
        buildings+=1
        assert 0<=x<x+w<=width and 0<=y<y+h<=height,(key,x,y,w,h)
        assert len(color)==6 and int(color,16)>=0
        for yy in range(y+1,y+h-1):
            for xx in range(x+1,x+w-1):
                assert (xx,yy) in doors or room['cells'][yy*width+xx]&0xc00,(key,'roof hides walkable source tile',xx,yy)
print(f'PASS: {len(modern)} modern maps, matching terrain textures, {buildings} building footprints; no roofs over interior walkable tiles.')
