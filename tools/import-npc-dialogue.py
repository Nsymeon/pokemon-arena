"""Resolve original FRLG text without executing scripts or choosing unknown conditions."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered/data'
blocks={}
for path in sorted(source.rglob('*.inc')):
 text=path.read_text(encoding='utf8')
 blocks.update(dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',text,re.M|re.S)))
def text_of(label):
 body=blocks.get(label,'')
 text=''.join(re.findall(r'\.string\s+"([^"\n]*)"',body))
 text=text.replace('\\p','\n\n').replace('\\n',' ').replace('\\l',' ').replace('$','')
 return text.strip()
def resolve(label,seen=()):
 if label in seen or len(seen)>20:return ''
 for line in blocks.get(label,'').splitlines():
  match=re.match(r'\s*(msgbox|message|goto|call)\s+(\w+)',line)
  if not match:continue
  op,dest=match.groups()
  text=text_of(dest) if op in ('msgbox','message') else resolve(dest,seen+(label,))
  if text:return text
 return ''
records={}
for label,body in blocks.items():
 text=resolve(label)
 record={'text':text} if text else {}
 match=re.search(r'trainerbattle_single\s+\w+,\s*(\w+),\s*(\w+)',body)
 if match:
  record['intro']=text_of(match[1]);record['defeat']=text_of(match[2]);record['post']=text
 branches=[]
 for line in body.splitlines():
  branch=re.match(r'\s*(goto_if_set|goto_if_unset|goto_if_eq|goto_if_ge|goto_if_lt)\s+(.+)',line)
  if branch:
   args=[x.strip() for x in branch[2].split(',')]
   if len(args) in (2,3): branches.append({'op':branch[1],'args':args})
 if branches:record['branches']=branches
 if record:records[label]=record
out=root/'assets/kanto'
(out/'npc-dialogue.json').write_text(json.dumps(records,ensure_ascii=False),encoding='utf8')
# Keep the legacy reader in sync for existing services.
(out/'dialogue.json').write_text(json.dumps({k:v['text'] for k,v in records.items() if v.get('text')},ensure_ascii=False),encoding='utf8')
print('Original dialogue records:',len(records),'Trainer introductions:',sum('intro' in v for v in records.values()))
