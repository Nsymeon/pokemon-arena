"""Export FireRed encounter slot weights; runtime encounters require explicit interaction."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered/src/data/wild_encounters.json'
roster=json.loads((root/'data/roster.json').read_text(encoding='utf8'))
norm=lambda x:re.sub('[^a-z0-9]','',x.lower())
ids={norm(m['key']):m['id'] for m in roster}
maps=json.loads((root/'assets/kanto/maps.json').read_text())
result={}
for group in json.loads(source.read_text())['wild_encounter_groups']:
    if not group.get('for_maps'): continue
    weights={f['type']:f['encounter_rates'] for f in group['fields']}
    for record in group['encounters']:
        if record['map'] not in maps or 'LeafGreen' in record['base_label']: continue
        entry={}
        for kind in ['land_mons','water_mons','fishing_mons']:
            if kind not in record: continue
            slots=[]
            for i,mon in enumerate(record[kind]['mons']):
                key=norm(mon['species'].removeprefix('SPECIES_'))
                if key in ids: slots.append({'id':ids[key],'min':mon['min_level'],'max':mon['max_level'],'weight':weights[kind][i]})
            if kind=='fishing_mons':
                for rod,indices in next(f['groups'] for f in group['fields'] if f['type']==kind).items(): entry[rod]=[slots[i] for i in indices]
            elif slots: entry[kind]=slots
        if entry: result[record['map']]=entry
(root/'assets/kanto/encounters.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
print('Exported manual encounter tables for',len(result),'Kanto maps')
