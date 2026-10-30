"""Compile visual-only terrain/structure metadata. Never changes gameplay tiles.

The original collision, warps and events remain in maps.json/events.json. Explicit
General tileset rules cover Kanto exteriors; secondary tiles are classified by
their source palette. Building footprints are flood-filled, not placed at random.
"""
import json
import io
import time
from collections import deque, Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'data/source/pokefirered'
maps = json.loads((ROOT/'assets/kanto/maps.json').read_text())
events = json.loads((ROOT/'assets/kanto/events.json').read_text())
layouts = {x['id']: x for x in json.loads((SRC/'data/layouts/layouts.json').read_text())['layouts'] if 'id' in x}
sources = {x['id']: x for p in (SRC/'data/maps').glob('*/map.json') for x in [json.loads(p.read_text())]}

def write_changed(path, data):
    if path.exists() and path.read_bytes()==data: return
    temporary=path.with_suffix(path.suffix+'.tmp')
    for attempt in range(5):
        try:
            temporary.write_bytes(data)
            temporary.replace(path)
            return
        except OSError:
            if attempt==4: raise
            time.sleep(.1)

def classify(tile, primary, idx, behavior, blocked, outdoor, underground):
    pixels = list(tile.convert('RGB').getdata())
    green = sum(g > r*1.14 and g > b*1.05 for r,g,b in pixels)/256
    blue = sum(b > r*1.3 and b > g*1.02 for r,g,b in pixels)/256
    dark = sum(max(r,g,b)<65 for r,g,b in pixels)/256
    bright = sum(min(r,g,b)>175 for r,g,b in pixels)/256
    rgb = tuple(sum(p[c] for p in pixels)//256 for c in range(3))
    if behavior in [0x38,0x39,0x3a,0x3b]: return 'ledge',rgb
    if behavior==0x13: return 'waterfall',rgb
    if behavior in [0x10,0x11,0x12,0x15,0x16,0x17,0x19,0x1a,0x1b,0x28]: return 'water',rgb
    if behavior in [0x20,0x23,0x26,0x27] or 0x40<=behavior<=0x58: return 'puzzle',rgb
    if primary=='gTileset_Building' and idx in [0x5,0x6,0xd,0xe,0x15,0x16,0x17,0x1e,0x1f]: return 'floor',rgb
    if not outdoor:
        furniture={0x80:'table',0x81:'cabinet',0x82:'cabinet',0x83:'computer',0x86:'computer',0x89:'cabinet',0x8a:'cabinet',0x8b:'cabinet',0x95:'computer',0x97:'computer',0xa0:'computer'}
        if behavior in furniture and blocked: return furniture[behavior],rgb
    if primary=='gTileset_General' and idx<640:
        if idx in range(0x14,0x28) or idx in [0x0a,0x0b,0x0c,0x0e,0x0f,0x13]: return 'tree',rgb
        if idx==5: return 'shrub',rgb
        if idx in [2,3,0x168]: return 'sign',rgb
        if idx==4: return 'flowers',rgb
        if idx in [0xe7,0xec,0xed,0xf4,0xf5,0xfc,0xfd]: return 'fence',rgb
        if 0x28<=idx<=0x63 or 0x141<=idx<=0x163 or idx in [0x150,0x151,0x186,0x187,0x18f,0x197,0x19d,0x19e,0x19f]: return 'building',rgb
        if (0x69<=idx<=0xbb) and blocked: return 'cliff',rgb
    if outdoor:
        if behavior in [2,3]: return 'grass',rgb
        if not blocked:
            if green>.45: return ('path' if rgb[0]>145 and rgb[1]>195 else 'lawn'),rgb
            return 'path',rgb
        if green>.7: return ('tree' if bright<.04 and sum(rgb)<430 else 'shrub'),rgb
        if green>.35: return 'lawn',rgb
        return 'building',rgb
    if underground:
        return ('cliff' if blocked and dark<.7 else 'void' if dark>.7 else 'sand'),rgb
    if primary=='gTileset_Building' and idx<640:
        if idx in [0x4b,0x4e]: return ('chair' if blocked else 'floor'),rgb
        if idx in [0x47,0x57,0x4f,0x5f]: return 'plant',rgb
        if idx in [0x62,0x63]: return 'computer',rgb
        if idx in [0x31,0x32,0x35,0x36,0x37,0x39,0x3a,0x3d,0x3e,0x3f]: return ('cabinet' if blocked else 'floor'),rgb
        if idx in [0x4c,0x4d,0x54,0x55]: return ('table' if blocked else 'floor'),rgb
        if idx in [0x20,0x21,0x22,0x28,0x29,0x2a,0x2d,0x2e,0x2f]: return ('wall' if blocked else 'floor'),rgb
    if dark>.75: return 'void',rgb
    if blocked: return ('wall' if idx<0x20 else 'furniture'),rgb
    return 'floor',rgb

result={}
for key,m in maps.items():
    w,h=m['width'],m['height']; src=sources[key]; layout=layouts[src['layout']]
    outdoor=m['type'] in ['MAP_TYPE_TOWN','MAP_TYPE_CITY','MAP_TYPE_ROUTE'] or 'Forest' in m['name'] or 'SafariZone' in m['name'] or m['name'].endswith('_Exterior')
    cave=m['type']=='MAP_TYPE_UNDERGROUND'
    if 'Forest' in m['name']: cave=False
    original=Image.open(ROOT/m['image'].replace('res://',''))
    kinds=[]; colors=[]; cache={}
    for i,cell in enumerate(m['cells']):
        idx=cell&1023; b=int(events[key]['behavior'][i]); blocked=bool(cell&0xc00)
        ck=(idx,b,blocked)
        if ck not in cache:
            x,y=i%w*16,i//w*16
            cache[ck]=classify(original.crop((x,y,x+16,y+16)),layout['primary_tileset'],idx,b,blocked,outdoor,cave)
        kind,color=cache[ck]; kinds.append(kind); colors.append(color)
        if layout['secondary_tileset']=='gTileset_GenericBuilding1':
            if idx==0x28c: kinds[-1]='bed'
            elif idx==0x294: kinds[-1]='bed_foot'
            elif idx==0x297: kinds[-1]='chair'
    # Explicit source footprint of Pallet's houses and Oak's laboratory.
    buildings=[]
    if key=='MAP_PALLET_TOWN':
        for x,y,bw,bh,style in [(5,3,5,5,'house'),(14,3,5,5,'house'),(13,9,7,5,'lab')]:
            buildings.append([x,y,bw,bh,style,'cf6659' if style=='house' else '637a9b'])
            for yy in range(y,y+bh):
                for xx in range(x,x+bw): kinds[yy*w+xx]='foundation'
        for i,c in enumerate(m['cells']):
            if c&1023 in [0x284,0x287,0x288]: kinds[i]='fence'
            elif c&1023==0x2ad: kinds[i]='sign'
    # All source doors remain visibly reachable even if a palette heuristic differs.
    for door in m['warps']:
        i=door['y']*w+door['x']
        if 0<=i<len(kinds) and not outdoor and kinds[i] not in ['water']: kinds[i]='floor' if not cave else 'sand'
    # Anchor real buildings to their actual indoor entrance. Palette-only flood
    # fills can join neighboring roofs or mistake a mountain for an entire house.
    claimed=set()
    def blocked_at(x,y):
        return 0<=x<w and 0<=y<h and bool(m['cells'][y*w+x]&0xc00)
    def structural(x,y):
        if not blocked_at(x,y): return False
        idx=m['cells'][y*w+x]&1023
        if layout['primary_tileset']=='gTileset_General' and idx<640:
            return kinds[y*w+x] in ['building','foundation']
        return kinds[y*w+x] in ['building','foundation']
    if outdoor and key!='MAP_PALLET_TOWN':
        entrances={}
        for door in m['warps']:
            if maps.get(door['dest_map'],{}).get('type')=='MAP_TYPE_INDOOR':
                prior=entrances.get(door['dest_map'])
                if prior is None or door['y']>prior['y']: entrances[door['dest_map']]=door
        for door in entrances.values():
            destination=maps.get(door['dest_map'],{})
            if destination.get('type')!='MAP_TYPE_INDOOR': continue
            dx,dy=int(door['x']),int(door['y'])
            if not structural(dx,dy-1): continue
            left=right=dx
            while left>0 and dx-left<9 and structural(left-1,dy-1): left-=1
            while right<w-1 and right-dx<9 and structural(right+1,dy-1): right+=1
            for other in entrances.values():
                ox,oy=int(other['x']),int(other['y'])
                if other is door or abs(oy-dy)>3 or abs(ox-dx)<2: continue
                if ox<dx: left=max(left,(ox+dx)//2+1)
                else: right=min(right,(ox+dx)//2)
            if right-left<2: continue
            top=dy-1
            while top>0 and dy-top<11:
                row=[structural(xx,top-1) for xx in range(left,right+1)]
                if sum(row)<len(row)*.7: break
                top-=1
            # Do not cover source paths or courtyards with a solid building.
            while top<dy-2 and any(not blocked_at(xx,yy) for yy in range(top,dy) for xx in range(left,right+1)):
                top+=1
            rect=(left,top,right-left+1,dy-top+1)
            if rect[3]<2 or rect in claimed: continue
            if any(max(left,b[0])<min(right+1,b[0]+b[2]) and max(top,b[1])<min(dy+1,b[1]+b[3]) for b in buildings): continue
            claimed.add(rect)
            dest=door['dest_map']
            style='center' if 'POKEMON_CENTER' in dest else 'mart' if 'MART' in dest else 'gym' if 'GYM' in dest else 'tower' if rect[3]>7 or 'SILPH' in dest or 'TOWER' in dest else 'house'
            roof={'center':'cf5861','mart':'548cbb','gym':'b8a170','tower':'83889a'}.get(style,'719a78' if 'VIRIDIAN' in key else 'b8826d' if 'PEWTER' in key else '8e80a2' if 'LAVENDER' in key else 'c67a65')
            buildings.append([*rect,style,roof])
            for yy in range(top,dy+1):
                for xx in range(left,right+1): kinds[yy*w+xx]='foundation'
    # Unclaimed blocked structures get low relief, never an opaque roof over paths.
    for i,kind in enumerate(kinds):
        if kind=='building': kinds[i]='cliff' if ('Ember' in m['name'] or 'Kindle' in m['name'] or 'Route23' in m['name']) else 'fence'
    # Rounded path edges and fine soil variation avoid a solid checkerboard floor.
    ground=Image.new('RGB',(w*16,h*16),'#86ad76' if outdoor else '#938e7b' if cave else '#bdbba9')
    pen=ImageDraw.Draw(ground)
    palette={'path':'#d9cb9e','sand':'#a49a80','grass':'#70965b','water':'#4c94a5','floor':'#bdbba9','void':'#3e4c4d'}
    for i,k in enumerate(kinds):
        if k in palette:
            x,y=i%w*16,i//w*16;pen.rectangle((x,y,x+15,y+15),fill=palette[k])
    ground=ground.filter(ImageFilter.GaussianBlur(2))
    # Fixed noise is reproducible and evaluated in Pillow, not millions of Python loops.
    noise=Image.new('L',(64,64)); noise.putdata([128+((i*73+i//64*31)%7)-3 for i in range(4096)])
    grain=Image.new('L',ground.size)
    for y in range(0,ground.height,64):
        for x in range(0,ground.width,64): grain.paste(noise,(x,y))
    ground=ImageChops.add(ground,grain.convert('RGB'),offset=-128)
    # Keep the actual room's rugs, parquet and stair artwork. A generic tiled
    # overlay erased interior identity and hid the staircase entrances.
    if not outdoor and not cave:
        for i,kind in enumerate(kinds):
            if kind!='floor': continue
            x,y=i%w*16,i//w*16
            ground.paste(original.crop((x,y,x+16,y+16)),(x,y))
    folder=ROOT/'assets/kanto/modern';folder.mkdir(exist_ok=True)
    buffer=io.BytesIO(); ground.save(buffer,format='PNG')
    write_changed(folder/(m['name']+'.png'),buffer.getvalue())
    trees=[]; covered=set()
    for i,kind in enumerate(kinds):
        if kind!='tree' or i in covered or not (m['cells'][i]&0xc00): continue
        x,y=i%w,i//w
        block=[yy*w+xx for yy in range(y,min(y+2,h)) for xx in range(x,min(x+2,w)) if kinds[yy*w+xx]=='tree' and (m['cells'][yy*w+xx]&0xc00)]
        if not block: continue
        covered.update(block)
        trees.append([sum(j%w+.5 for j in block)/len(block),sum(j//w+.5 for j in block)/len(block),len(block)<3])
    result[key]={'outdoor':outdoor,'cave':cave,'tiles':kinds,'trees':trees,'buildings':buildings,'ground':'res://assets/kanto/modern/'+m['name']+'.png'}

path=ROOT/'assets/kanto/world-3d.json'
write_changed(path,json.dumps(result,separators=(',',':')).encode('utf8'))
print(f'{len(result)} maps; {sum(len(v["buildings"]) for v in result.values())} building footprints; {path.stat().st_size//1024} KiB')
