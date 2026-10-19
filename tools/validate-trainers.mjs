import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const data=JSON.parse(await fs.readFile('data/trainers.json','utf8'));
const roster=JSON.parse(await fs.readFile('data/roster.json','utf8'));
const source=JSON.parse(await fs.readFile('data/source/moves.json','utf8'));
const expected=[[87,91,80,124,131],[95,107,106,95,68],[94,42,93,24,94],[130,148,148,142,149],[18,65,112,103,130,6],[18,65,112,59,103,9],[18,65,112,130,59,3]];
expected.push([74,95],[120,121],[100,25,26],[71,114,45],[109,89,109,110],[64,122,49,65],[58,77,78,59],[111,51,31,34,112]);
assert.equal(data.trainers.length,15);
assert.equal(new Set(data.trainers.map(t=>t.id)).size,15);
const report=['# Kanto opponents — Red/Blue','','Sources: '+data.source+' and '+data.gym_source,'','Teams and move selections follow Red/Blue gyms and the first League challenge. Levels are reference metadata; the arena retains its existing modern stats, damage categories and real-time rules.',''];
for(const [i,t] of data.trainers.entries()){
 assert.deepEqual(t.team.map(p=>p.id),expected[i]);
 report.push('## '+t.name+' — '+t.title,'','| Pokémon | Original level | Moves |','|---|---|---|');
 for(const p of t.team){
  const mon=roster.find(x=>x.id===p.id);assert(mon);
  const shortSets={7:[2,3],8:[2,4],9:[3,4,4],10:[4,2,4]};
  assert.equal(p.moves.length,shortSets[i]?.[t.team.indexOf(p)]??(p.id===103?3:4));
  assert(p.level>=12&&p.level<=65);
  for(const m of p.moves){assert(source[m.id]);assert.equal(m.name,source[m.id].name);assert(Number.isFinite(m.damage)&&Number.isFinite(m.cooldown));}
  report.push(`| ${mon.name} | ${p.level} | ${p.moves.map(m=>m.name).join(' / ')} |`);
 }
 report.push('');
}
assert.notDeepEqual(data.trainers[2].team[0].moves,data.trainers[2].team[4].moves);
assert(data.trainers[3].team[4].moves.some(m=>m.id==='barrier'));
await fs.writeFile('data/trainer-teams.md',report.join('\n')+'\n');
console.log('PASS: 15 historical party presets, duplicate species and variable moveset lengths.');
