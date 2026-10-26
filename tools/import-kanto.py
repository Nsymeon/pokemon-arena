"""Compile the checked-out FRLG layouts into Godot-ready maps and encounter data."""
import json, re, struct, subprocess
from pathlib import Path
from functools import lru_cache
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'data/source/pokefirered'
OUT=ROOT/'assets/kanto'
OUT.mkdir(exist_ok=True)
def read(p): return (SRC/p).read_text(encoding='utf8')
def norm(s): return re.sub('[^a-z0-9]','',s.lower())
layouts={x['id']:x for x in json.loads(read('data/layouts/layouts.json'))['layouts'] if 'id' in x}
folders={norm(p.name):p for group in ['primary','secondary'] for p in (SRC/'data/tilesets'/group).iterdir() if p.is_dir()}
@lru_cache(None)
def tileset(symbol):
    p=folders[norm(symbol.removeprefix('gTileset_'))]
    header=re.search(r'const struct Tileset '+symbol+r'\s*=\s*\{(.*?)\};',read('src/data/tilesets/headers.h'),re.S)[1]
    tile_folder=folders[norm(re.search(r'\.tiles = gTilesetTiles_(\w+)',header)[1])]
    palette_folder=folders[norm(re.search(r'\.palettes = gTilesetPalettes_(\w+)',header)[1])]
    image=Image.open(tile_folder/'tiles.png')
    assert image.mode=='P', (p,image.mode)
    tiles=[]
    for y in range(0,image.height,8):
        for x in range(0,image.width,8): tiles.append(list(image.crop((x,y,x+8,y+8)).getdata()))
    pal={int(f.stem):[tuple(map(int,line.split())) for line in f.read_text().splitlines()[3:19]] for f in (palette_folder/'palettes').glob('*.pal')}
    raw=(p/'metatiles.bin').read_bytes()
    return tiles,pal,list(struct.unpack('<'+'H'*(len(raw)//2),raw))
@lru_cache(None)
def block(primary,secondary,idx):
    pt,pp,pm=tileset(primary); st,sp,sm=tileset(secondary)
    table=pm if idx<640 else sm
    offset=(idx if idx<640 else idx-640)*8
    result=Image.new('RGBA',(16,16))
    for i,value in enumerate(table[offset:offset+8]):
        tid=value&1023; palette=value>>12
        pixels=(pt[tid] if tid<640 and tid<len(pt) else st[tid-640] if tid>=640 and tid-640<len(st) else [0]*64)
        colors=(pp if palette<7 else sp).get(palette,pp.get(0))
        tile=Image.new('RGBA',(8,8))
        tile.putdata([(*colors[p%16],0 if p%16==0 and i>=4 else 255) for p in pixels])
        if value&1024: tile=tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if value&2048: tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        result.alpha_composite(tile,((i%2)*8,((i%4)//2)*8))
    return result
prefixes=('PalletTown','Viridian','Pewter','Cerulean','Lavender','Vermilion','Celadon','Fuchsia','Cinnabar','IndigoPlateau','PokemonLeague','Saffron','Route','MtMoon','RockTunnel','PokemonTower','RocketHideout','SilphCo','SafariZone','Seafoam','VictoryRoad','DiglettsCave','PowerPlant','PokemonMansion','UndergroundPath','SSAnne','OneIsland','TwoIsland','ThreeIsland','FourIsland','FiveIsland','SixIsland','SevenIsland','MtEmber','TrainerTower')
maps={}
for path in sorted((SRC/'data/maps').glob('*/map.json')):
    m=json.loads(path.read_text())
    if not m['name'].startswith(prefixes) or m['layout'] not in layouts: continue
    layout=layouts[m['layout']]; w=layout['width']; h=layout['height']
    raw=(SRC/layout['blockdata_filepath']).read_bytes(); cells=list(struct.unpack('<'+'H'*(len(raw)//2),raw))
    if len(cells)!=w*h: raise ValueError(m['name'])
    target=OUT/(m['name']+'.png')
    if not target.exists():
        image=Image.new('RGBA',(w*16,h*16))
        for i,cell in enumerate(cells): image.paste(block(layout['primary_tileset'],layout['secondary_tileset'],cell&1023),((i%w)*16,(i//w)*16))
        image.save(target)
    maps[m['id']]={'name':m['name'],'width':w,'height':h,'image':'res://assets/kanto/'+target.name,'cells':cells,'warps':m.get('warp_events',[]),'connections':m.get('connections') or [],'objects':m.get('object_events',[]),'signs':m.get('bg_events',[]),'type':m['map_type']}
# Preserve trainer coordinates and cartridge parties; no sight-trigger battles.
roster=json.loads((ROOT/'data/roster.json').read_text(encoding='utf8'))
species={norm(m['key']):m['id'] for m in roster}
parties={}
for name,body in re.findall(r'static const struct \w+ (sParty_\w+)\[\] = \{(.*?)\n\};',read('src/data/trainer_parties.h'),re.S):
    team=[]
    for entry in re.findall(r'\{([^{}]+)\}',body,re.S):
        level=re.search(r'\.lvl = (\d+)',entry); mon=re.search(r'\.species = SPECIES_(\w+)',entry)
        if level and mon and norm(mon[1]) in species: team.append([species[norm(mon[1])],int(level[1])])
    if team: parties[name]=team
trainers={}
for name,body in re.findall(r'\[(TRAINER_\w+)\] = \{(.*?)\n    \}',read('src/data/trainers.h'),re.S):
    party=re.search(r'\.party = \w+\((sParty_\w+)\)',body); label=re.search(r'\.trainerName = _\("([^"\n]+)"\)',body)
    if party and party[1] in parties: trainers[name]={'name':label[1].title() if label else name,'party':parties[party[1]]}
scripts='\n'.join(p.read_text(encoding='utf8') for p in (SRC/'data').rglob('*.inc'))
lookup={}
for match in re.finditer(r'^(\w+)::?\s*\n([^:]*?trainerbattle[^\n]*?\b(TRAINER_\w+))',scripts,re.M):
    if match[3] in trainers: lookup[match[1]]=trainers[match[3]]
for m in maps.values():
    for obj in m['objects']:
        if obj.get('script') in lookup: obj['battle']=lookup[obj['script']]
print('Trainer actors:',sum('battle' in o for m in maps.values() for o in m['objects']),flush=True)
(OUT/'maps.json').write_text(json.dumps(maps,separators=(',',':')),encoding='utf8')
(OUT/'source.json').write_text(json.dumps({'repository':'https://github.com/pret/pokefirered','revision':subprocess.check_output(['git','-c',f'safe.directory={SRC.as_posix()}','-C',str(SRC),'rev-parse','HEAD'],text=True).strip(),'maps':len(maps)},indent=2),encoding='utf8')
print(f'Compiled {len(maps)} original Kanto maps',flush=True)


actors={}
folder=OUT/'actors'; folder.mkdir(exist_ok=True)
for path in (SRC/'graphics/object_events/pics/people').glob('*.png'):
    source=Image.open(path)
    image=source.convert('RGBA'); pixels=list(image.getdata()); indices=list(source.getdata())
    image.putdata([(r,g,b,0 if indices[i]==0 else 255) for i,(r,g,b,alpha) in enumerate(pixels)])
    target=folder/path.name; image.save(target)
    actors[norm(path.stem)]='res://assets/kanto/actors/'+path.name
(OUT/'actors.json').write_text(json.dumps(actors),encoding='utf8')
