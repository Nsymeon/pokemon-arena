"""Export FireRed HM and tutor compatibility from the pinned source checkout."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=root/'data/source/pokefirered/src/data/pokemon'
norm=lambda s:re.sub('[^a-z0-9]','',s.lower())
roster=json.loads((root/'data/roster.json').read_text(encoding='utf8'))
ids={norm(m['key']):str(m['id']) for m in roster}
result={str(m['id']):{'hms':[],'tutors':[]} for m in roster}
for name,body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*TMHM_LEARNSET\((.*?)\),',(src/'tmhm_learnsets.h').read_text(),re.S):
 if norm(name) in ids: result[ids[norm(name)]]['hms']=[norm(x) for x in re.findall(r'TMHM\(HM\d+_(\w+)\)',body)]
for name,body in re.findall(r'\[SPECIES_(\w+)\]\s*=\s*(.*?)(?=,)',(src/'tutor_learnsets.h').read_text(),re.S):
 if norm(name) in ids: result[ids[norm(name)]]['tutors']=[norm(x) for x in re.findall(r'TUTOR\(MOVE_(\w+)\)',body)]
(root/'assets/kanto/field-learning.json').write_text(json.dumps(result,indent=2)+'\n')
print('Exported HM/tutor compatibility for',len(result),'species')
