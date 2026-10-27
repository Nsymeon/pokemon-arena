import json,urllib.request,concurrent.futures,hashlib
from pathlib import Path
root=Path('.')
folder=root/'assets/audio/cries';folder.mkdir(parents=True,exist_ok=True)
roster=json.loads((root/'data/roster.json').read_text(encoding='utf8'))
base='https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/'
def fetch(mon):
    id=mon['id']; url=base+str(id)+'.ogg'; file=folder/(str(id)+'.ogg')
    if not file.exists():
        with urllib.request.urlopen(url,timeout=40) as r: file.write_bytes(r.read())
    data=file.read_bytes()
    assert data[:4]==b'OggS' or data[:3]==b'ID3' or data[:2] in [b'\xff\xfb',b'\xff\xf3',b'\xff\xf2'],id
    if data[:4]!=b'OggS':
        target=file.with_suffix('.mp3');target.write_bytes(data);file.unlink();file=target
    return str(id),{'url':url,'file':file.name,'sha256':hashlib.sha256(data).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: entries=dict(pool.map(fetch,roster))
(folder/'sources.json').write_text(json.dumps(entries,indent=2)+'\n',encoding='utf8')
print('Verified',len(entries),'Pokemon cries')
