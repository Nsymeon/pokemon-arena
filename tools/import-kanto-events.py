"""Compile supported FireRed event geometry and interaction locations, without a ROM."""
import json,re,runpy,struct
from pathlib import Path
c=runpy.run_path(str(Path(__file__).with_name('import-kanto.py')))
SRC,OUT=c['SRC'],c['OUT']; maps=c['maps']; layouts=c['layouts']; render=c['block']
constants={k:int(v,0) for k,v in re.findall(r'#define\s+(METATILE_\w+)\s+(0x[0-9A-Fa-f]+|\d+)',(SRC/'include/constants/metatile_labels.h').read_text())}
text='\n'.join(p.read_text(encoding='utf8') for p in (SRC/'data').rglob('*.inc'))
blocks=dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',text,re.M|re.S))
result={}; tiles=OUT/'event_tiles';tiles.mkdir(exist_ok=True)
for mid,m in maps.items():
    original=json.loads((SRC/'data/maps'/m['name']/'map.json').read_text()); layout=layouts[original['layout']]
    actions={}
    labels=[k for k in blocks if k.startswith(m['name']+'_')]
    if m['name'].startswith('PokemonMansion_'): labels += [k for k in blocks if k.startswith('PokemonMansion_EventScript_') and k.endswith('_'+m['name'].split('_')[-1])]
    if m['name'].startswith('SilphCo_'): labels += [k for k in blocks if re.match('EventScript_(Open|Close)'+m['name'].split('_')[-1]+'Door',k)]
    for label in labels:
        edits=[]
        for x,y,tile,solid in re.findall(r'setmetatile\s+(\d+),\s*(\d+),\s*(METATILE_\w+),\s*([01])',blocks[label]):
            if tile not in constants: continue
            name=m['name']+'_'+tile+'.png'; target=tiles/name
            if not target.exists(): render(layout['primary_tileset'],layout['secondary_tileset'],constants[tile]).save(target)
            edits.append({'x':int(x),'y':int(y),'solid':int(solid),'image':'res://assets/kanto/event_tiles/'+name})
        if edits: actions[label]=edits
    if m['name'] in ['SeafoamIslands_B3F','SeafoamIslands_B4F']:
        alt=layouts[original['layout']+'_CURRENT_STOPPED']
        raw=(SRC/alt['blockdata_filepath']).read_bytes(); calm=struct.unpack('<'+'H'*(len(raw)//2),raw)
        edits=[]
        for index,cell in enumerate(calm):
            if cell==m['cells'][index]: continue
            tile_id=cell&1023; filename=m['name']+'_calm_'+str(tile_id)+'.png'
            target=tiles/filename
            if not target.exists(): render(alt['primary_tileset'],alt['secondary_tileset'],tile_id).save(target)
            edits.append({'x':index%m['width'],'y':index//m['width'],'solid':int(bool(cell&0xC00)),'image':'res://assets/kanto/event_tiles/'+filename})
        actions['calm']=edits
    items=[]
    for i,o in enumerate(m['objects']):
        b=blocks.get(o.get('script',''),''); match=re.search(r'finditem\s+ITEM_(\w+)',b)
        if match: items.append({'x':o['x'],'y':o['y'],'id':str(i),'item':match[1]})
    behavior=[]
    tables=[]
    for symbol in [layout['primary_tileset'],layout['secondary_tileset']]:
        raw=(c['folders'][c['norm'](symbol.removeprefix('gTileset_'))]/'metatile_attributes.bin').read_bytes()
        tables.append(struct.unpack('<'+'I'*(len(raw)//4),raw))
    for cell in m['cells']:
        tid=cell&1023; table=tables[0 if tid<640 else 1]; idx=tid if tid<640 else tid-640
        behavior.append(table[idx]&511 if idx<len(table) else 0)
    result[mid]={'behavior':behavior,'patches':actions,'triggers':original.get('coord_events',[]),'items':items}
(OUT/'events.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
print('Event geometry:',sum(len(m['patches']) for m in result.values()),'blocks;',sum(len(m['items']) for m in result.values()),'items')
