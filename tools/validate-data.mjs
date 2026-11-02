import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {moveRules} from './move-rules.mjs';
const json=async p=>JSON.parse(await fs.readFile(p,'utf8'));
const roster=await json('data/roster.json'), dex=await json('data/source/pokedex.json'), moves=await json('data/source/moves.json'), sets=await json('data/source/learnsets.json');
assert.equal(roster.length,388);
assert.equal(new Set(roster.map(p=>p.id)).size,388);
assert.deepEqual(roster.filter(p=>p.id<=386).map(p=>p.id),Array.from({length:386},(_,i)=>i+1));
assert.deepEqual(roster.filter(p=>p.id>386).map(p=>p.id),[599,821]);
let official=0, custom=0;
for(const p of roster) {
 assert.deepEqual(p.base_stats,dex[p.key].baseStats,p.name+' stats');
 assert.deepEqual(p.types,dex[p.key].types,p.name+' types');
 assert.equal(p.moves.length,4);
 assert.equal(new Set(p.moves.map(m=>m.id)).size,4,p.name+' distinct actions');
 const allowed=new Set(); let key=p.key;
 while(key) {for(const m of Object.keys(sets[key]?.learnset||{}))allowed.add(m);key=dex[key]?.prevo?.toLowerCase().replace(/[^a-z0-9]/g,'');}
 for(const m of p.moves) {
  if(m.arena_only) {assert([132,201,235].includes(p.id));custom++;continue;}
  assert(allowed.has(m.id),`${p.name}: ${m.name} is learnable`);
  assert.equal(m.type,moves[m.id].type);
  assert.equal(m.category,moves[m.id].category);
  assert.equal(m.name,moves[m.id].name);
  assert(m.cooldown>0 && m.cost>=0 && m.damage>=0);
  const rules=moveRules(moves[m.id],m.id);
  for(const [key,value] of Object.entries(rules)) assert.deepEqual(m[key],value,`${p.name}/${m.name}: ${key}`);
  official++;
 }
 const png=await fs.readFile(`assets/pokemon/${p.id}.png`);
 assert.equal(png.subarray(1,4).toString(),'PNG');
}
console.log(`PASS: 386 National IDs, 2 retained guests, exact modern base stats/types, ${official} learnset-validated moves, ${custom} marked arena actions, 388 PNG assets.`);

const battle=await json('data/battle-learnsets.json');
for(const mon of roster){
 const ids=battle.species[mon.id];
 assert(ids?.length>=4 && new Set(ids).size===ids.length, mon.name+' battle move pool');
 for(const id of ids){
  const m=battle.moves[id];
  assert(m?.id===id && m.name && m.type && m.kind && Number.isFinite(m.damage) && Number.isFinite(m.cost) && Number.isFinite(m.cooldown), mon.name+' usable definition '+id);
 }
}
assert(battle.species[6].includes('fly'));
assert(!battle.species[129].includes('flamethrower'));
console.log('PASS: custom battle move catalog');
