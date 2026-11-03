"""Download credited animation forms at the same pinned SpriteCollab revision."""
import json,urllib.request,xml.etree.ElementTree as ET,concurrent.futures,time
from pathlib import Path
r=Path(__file__).resolve().parents[1]
rev=json.loads((r/'assets/animated/source.json').read_text(encoding='utf8'))['revision']
base=f'https://raw.githubusercontent.com/PMDCollab/SpriteCollab/{rev}/'
def get(remote,path):
 if path.exists():return path.read_bytes()
 for attempt in range(4):
  try:
   data=urllib.request.urlopen(base+remote,timeout=40).read();path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);return data
  except Exception:
   if attempt==3:raise
   time.sleep(1)
tracker=json.loads(get('tracker.json',r/'data/source/sprite-tracker.json'))
tasks=[]
for species in [201,351,386]:
 forms=tracker[f'{species:04}']['subgroups']
 for code,info in forms.items():
  if int(code)==0 or int(code)>(27 if species==201 else 3):continue
  print(species,code,info['name'],flush=True)
  for shiny in [False,True]:tasks.append((species,code,info['name'],shiny))
def load(task):
 species,code,name,shiny=task
 folder=r/f'assets/forms/{species}/{code}/{"shiny" if shiny else "normal"}'
 remote=f'sprite/{species:04}/{code}/'+('0001/' if shiny else '')
 xml=get(remote+'AnimData.xml',folder/'AnimData.xml')
 anims={node.findtext('Name'):node for node in ET.fromstring(xml).find('Anims')};entry={}
 for state in ['Idle','Walk','Attack','Shoot','Hurt']:
  node=anims.get(state)
  if node is None:continue
  seen=set()
  while node.find('CopyOf') is not None:
   target=node.findtext('CopyOf');assert target not in seen;seen.add(target);node=anims[target]
  path=folder/(state+'.png');get(remote+node.findtext('Name')+'-Anim.png',path)
  entry[state]={'width':int(node.findtext('FrameWidth')),'height':int(node.findtext('FrameHeight')),'durations':[int(d.text) for d in node.find('Durations')],'path':'res://'+path.relative_to(r).as_posix()}
 assert 'Idle' in entry and 'Walk' in entry,(species,code)
 credit=get(remote+'credits.txt',folder/'credits.txt').decode('utf8')
 (folder/'CREDITS.md').write_text(credit,encoding='utf8')
 return f'{species}:{int(code)}:{"shiny" if shiny else "normal"}',{'name':name,'animations':entry}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:manifest=dict(pool.map(load,tasks))
(r/'assets/forms/manifest.json').write_text(json.dumps(manifest,separators=(',',':')),encoding='utf8')
(r/'assets/forms/CREDITS.md').write_text(f'# Pokemon form artwork\n\nPMD SpriteCollab, revision `{rev}`: https://github.com/PMDCollab/SpriteCollab\n\nOriginal sprites and community edits are unmodified. See each form folder for the full contributor history. Same noncommercial CC BY-NC 4.0 policy as the main animation library.\n',encoding='utf8')
print('Form animation libraries:',len(manifest),flush=True)
