import fs from 'node:fs';
import {moveRules} from './move-rules.mjs';
const read=n=>JSON.parse(fs.readFileSync('data/'+n,'utf8'));
const roster=read('roster.json'), moves=read('source/moves.json'), learn=read('source/learnsets.json'), dex=read('source/pokedex.json');
const key=s=>s.toLowerCase().replace(/[^a-z0-9]/g,'');
const existing=new Map([...Object.entries(read('adventure-learnsets.json').moves),...roster.flatMap(p=>p.moves.map(m=>[m.id,m]))]);
const species={}, catalog={};
for(const mon of roster){
 const ids=new Set(mon.moves.map(m=>m.id));
 let k=mon.key;
 const seen=new Set();
 while(k&&!seen.has(k)){
  seen.add(k);
  for(const id of Object.keys(learn[k]?.learnset||{})) if(moves[id])ids.add(id);
  k=dex[k]?.prevo?key(dex[k].prevo):null;
 }
 species[mon.id]=[...ids].sort();
 for(const id of ids){
  if(catalog[id])continue;
  if(existing.has(id)){catalog[id]={...existing.get(id)};continue;}
  const m=moves[id];
  const heal=['recover','softboiled','rest','synthesis','moonlight','morningsun','slackoff','roost','shoreup','healorder'].includes(id);
  const guard=['protect','detect','harden','withdraw','defensecurl','reflect','lightscreen','irondefense','acidarmor','amnesia'].includes(id);
  const buff=m.target==='self'&&m.category==='Status'&&!!m.boosts;
  let kind=m.category==='Status'?(heal?'heal':guard?'guard':buff?'buff':id==='teleport'?'teleport':id==='splash'?'splash':id==='transform'?'transform':'status'):(m.flags?.contact?'dash':'bolt');
  const bp=m.basePower||(m.category!=='Status'?60:0);
  catalog[id]={id,name:m.name,type:m.type,category:m.category,base_power:bp,kind,damage:m.category==='Status'?0:Math.round((8+bp*.26)*10)/10,cost:m.category==='Status'?25:Math.round(5+bp*.19),cooldown:m.category==='Status'?6:Math.round((.4+bp/55+(kind==='dash'?.5:0))*100)/100,drain:!!m.drain,recoil:!!m.recoil,arena_only:false,pp:m.pp,...moveRules(m,id)};
 }
}
if(!species[6].includes('fly')||species[129].includes('flamethrower'))throw Error('Species compatibility failed');
fs.writeFileSync('data/battle-learnsets.json',JSON.stringify({source:'Recorded Showdown learnsets across generations, including pre-evolution moves and existing arena defaults',species,moves:catalog},null,2)+'\n');
console.log(`PASS: ${Object.keys(species).length} battle learnsets, ${Object.keys(catalog).length} moves`);
