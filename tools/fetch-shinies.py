"""Download canonical shiny portraits and credited PMDCollab animation variants."""
import json, urllib.request, time, concurrent.futures, xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
REV = json.loads((ROOT/'assets/animated/source.json').read_text())['revision']
BASE = f'https://raw.githubusercontent.com/PMDCollab/SpriteCollab/{REV}/sprite/'
def fetch(url, path):
    if path.exists(): return path.read_bytes()
    for attempt in range(3):
        try:
            data = urllib.request.urlopen(url, timeout=25).read()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            return data
        except Exception:
            if attempt == 2: raise
            time.sleep(1)
def species(mon):
    n = mon['id']; folder = ROOT/f'assets/shiny/{n}'
    fetch(f'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/{n}.png', ROOT/f'assets/shiny/{n}.png')
    base = BASE+f'{n:04}/0000/0001/'
    try:
        xml = fetch(base+'AnimData.xml', folder/'AnimData.xml')
        anims = {a.findtext('Name'):a for a in ET.fromstring(xml).find('Anims')}
        entry = {}
        for state in ['Idle','Walk','Attack','Shoot','Hurt']:
            a = anims.get(state)
            if a is None: continue
            while a.find('CopyOf') is not None: a = anims[a.findtext('CopyOf')]
            name = a.findtext('Name')
            path = folder/(state+'.png')
            fetch(base+name+'-Anim.png', path)
            entry[state] = dict(width=int(a.findtext('FrameWidth')),height=int(a.findtext('FrameHeight')),durations=[int(d.text) for d in a.find('Durations')],path='res://'+path.relative_to(ROOT).as_posix())
        credits = fetch(base+'credits.txt',folder/'credits.txt').decode()
        (folder/'CREDITS.md').write_text(credits,encoding='utf8')
        return str(n),entry
    except Exception as error:
        print(f'{n}: portrait fallback ({error})',flush=True)
        return str(n),{}
if __name__=='__main__':
    roster=json.loads((ROOT/'data/roster.json').read_text(encoding='utf8'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool: result=dict(pool.map(species,roster))
    (ROOT/'assets/shiny/manifest.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(f'Finished: {len(result)} portraits, {sum(bool(v) for v in result.values())} animated species',flush=True)
