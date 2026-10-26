import fs from 'node:fs';
import {moveRules} from './move-rules.mjs';
const read=n=>JSON.parse(fs.readFileSync('data/'+n,'utf8'));
const roster=read('roster.json'), moves=read('source/moves.json'), learn=read('source/learnsets.json');
const normalize=s=>s.toLowerCase().replace(/[^a-z0-9]/g,'');
const alias={hijumpkick:'highjumpkick',vicegrip:'visegrip',faintattack:'feintattack',smellingsalt:'smellingsalts'};
const key=s=>alias[normalize(s)]||normalize(s);
const levelText=fs.readFileSync('data/source/frlg-level-up.h','utf8').replace(/#if defined\(FIRERED\)([\s\S]*?)#elif defined\(LEAFGREEN\)[\s\S]*?#endif/g,'$1');
const tmText=fs.readFileSync('data/source/frlg-tmhm.h','utf8');
const levels={};
for(const match of levelText.matchAll(/s(\w+)LevelUpLearnset\[\]\s*=\s*\{([\s\S]*?)\};/g)) levels[normalize(match[1])]=[...match[2].matchAll(/LEVEL_UP_MOVE\((\d+), MOVE_(\w+)\)/g)].map(m=>({level:+m[1],move:key(m[2])}));
const compat={},tms={};
for(const match of tmText.matchAll(/\[SPECIES_(\w+)\]\s*=\s*TMHM_LEARNSET\(([\s\S]*?)\),/g)) {
 const list=[];
 for(const m of match[2].matchAll(/TMHM\((TM\d+)_(\w+)\)/g)) {list.push(m[1]);tms[m[1]]={move:key(m[2]),name:m[1]+' / '+moves[key(m[2])]?.name};}
 compat[normalize(match[1])]=list;
}
const species={};
for(const mon of roster) {
 const k=mon.key==='nidoranf'?'nidoranf':mon.key==='nidoranm'?'nidoranm':normalize(mon.key);
 let entries=levels[k];
 let source='FireRed/LeafGreen';
 if(!entries){
  source='Latest recorded generation (retained extra)';
  const ls=learn[mon.key]?.learnset||{};
  const generation=Math.max(...Object.values(ls).flat().filter(v=>/^\dL\d+$/.test(v)).map(v=>+v[0]));
  entries=Object.entries(ls).flatMap(([move,sources])=>sources.filter(v=>v.startsWith(generation+'L')).map(v=>({level:+v.slice(2),move})));
 }
 if(!entries?.length)throw Error('No levels for '+mon.key);
 entries.sort((a,b)=>a.level-b.level);
 const machineList=compat[k]||Object.entries(tms).filter(([,tm])=>(learn[mon.key]?.learnset?.[tm.move]||[]).some(s=>/^\dM/.test(s))).map(([id])=>id);
 species[mon.id]={source,levels:entries,tms:machineList};
}
const existing=new Map(roster.flatMap(p=>p.moves.map(m=>[m.id,m])));
const catalog={};
const ids=new Set(["fly","surf","megapunch","megakick","swordsdance","bodyslam","doubleedge","counter","seismictoss","mimic","metronome","softboiled","dreameater","thunderwave","explosion","rockslide","substitute",...Object.values(species).flatMap(s=>s.levels.map(l=>l.move)),...Object.values(tms).map(t=>t.move)]);
for(const id of ids){
 const m=moves[id];if(!m)throw Error('Missing move '+id);
 if(existing.has(id)){catalog[id]={...existing.get(id),pp:m.pp};continue;}
 const heal=['recover','softboiled','rest','synthesis','moonlight','morningsun','slackoff','roost'].includes(id);
 const guard=['protect','detect','harden','withdraw','defensecurl','reflect','lightscreen','irondefense','acidarmor','amnesia'].includes(id);
 const buff=m.target==='self'&&m.category==='Status'&&!!m.boosts;
 let kind=m.category==='Status'?(heal?'heal':guard?'guard':buff?'buff':id==='teleport'?'teleport':id==='splash'?'splash':id==='transform'?'transform':'status'):(m.flags?.contact?'dash':'bolt');
 if(['earthquake','surf','rockslide','icywind'].includes(id))kind='pulse';
 const bp=m.basePower||(m.category!=='Status'?60:0);
 catalog[id]={id,name:m.name,type:m.type,category:m.category,base_power:bp,kind,damage:m.category==='Status'?0:Math.round((8+bp*.26)*10)/10,cost:m.category==='Status'?25:Math.round(5+bp*.19),cooldown:m.category==='Status'?6:Math.round((.4+bp/55+(kind==='dash'?.5:0))*100)/100,drain:!!m.drain,recoil:!!m.recoil,arena_only:false,pp:m.pp,...moveRules(m,id)};
}
fs.writeFileSync('data/adventure-learnsets.json',JSON.stringify({sources:['https://github.com/pret/pokefirered/blob/master/src/data/pokemon/level_up_learnsets.h','https://github.com/pret/pokefirered/blob/master/src/data/pokemon/tmhm_learnsets.h','https://play.pokemonshowdown.com/data/learnsets.json'],species,tms,moves:catalog},null,2)+'\n');
if(species[4].levels.find(x=>x.move==='ember').level!==7||species[4].levels.find(x=>x.move==='metalclaw').level!==13||Object.keys(tms).length!==50)throw Error('FRLG sanity checks failed');
console.log(`PASS: ${Object.keys(species).length} learnsets, ${Object.keys(tms).length} TMs, ${ids.size} move definitions`);

