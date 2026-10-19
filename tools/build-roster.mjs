import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import {moveRules} from './move-rules.mjs';
const read = async n => JSON.parse(await fs.readFile(`data/source/${n}.json`, 'utf8'));
const dex = await read('pokedex'), moves = await read('moves'), learnsets = await read('learnsets');
const id = s => s.toLowerCase().replace(/[^a-z0-9]/g,'');
const extraIds = [152,185,197,355,361,599,821];
const selected = Object.entries(dex).filter(([key,p]) => ((p.num >= 1 && p.num <= 151) || extraIds.includes(p.num)) && !p.forme && !p.baseSpecies).sort((a,b)=>a[1].num-b[1].num);
if(selected.length !== 158) throw Error(`Expected 158, got ${selected.length}`);
const plans = new Map();
function family(numbers, text) {for(const n of numbers) plans.set(n,text.split('|').map(s=>s.trim().split('/')));}
family([1,2,3], 'razorleaf/vinewhip|sludgebomb|energyball/seedbomb|synthesis');
family([4,5,6], 'ember/flamethrower|dragonclaw/metalclaw|flamethrower/fireblast|smokescreen');
family([7,8,9], 'watergun/waterpulse|bite|icebeam|withdraw/protect');
family([10], 'tackle|bugbite|electroweb|stringshot');
family([11], 'bugbite|tackle|electroweb|irondefense/harden');
family([12], 'airslash/gust|bugbuzz/silverwind|psychic|sleeppowder');
family([13], 'poisonsting|bugbite|electroweb|stringshot');
family([14], 'poisonsting|bugbite|electroweb|irondefense/harden');
family([15], 'twineedle/poisonjab|xscissor|drillrun|agility');
family([16,17,18], 'gust/airslash|quickattack|steelwing|roost');
family([19,20], 'quickattack|bite/crunch|hyperfang|focusenergy');
family([21,22], 'peck|aerialace/drillpeck|drillrun|roost');
family([23,24], 'poisonsting|bite/crunch|sludgebomb|glare');
family([25,26], 'thundershock|quickattack|thunderbolt|thunderwave');
family([27,28], 'mudshot/mudslap|slash/scratch|rockslide|sandtomb');
family([29,30,31], 'poisonsting|bite|earthpower|toxic');
family([32,33,34], 'poisonsting|hornattack|earthpower|focusenergy');
family([35,36], 'disarmingvoice|moonblast|flamethrower|moonlight');
family([37,38], 'ember|quickattack|flamethrower|willowisp');
family([39,40], 'disarmingvoice|bodyslam|dazzlinggleam|sing');
family([41,42], 'aircutter|poisonfang|leechlife|confuseray');
family([43,44,45], 'absorb/megadrain|sludgebomb|gigadrain|sleeppowder');
family([46,47], 'bugbite|seedbomb|xscissor|spore');
family([48,49], 'confusion|bugbuzz/signalbeam|sludgebomb|sleeppowder');
family([50,51], 'mudslap|dig|rockslide|sandattack');
family([52,53], 'payday|bite|slash|fakeout');
family([54,55], 'watergun|confusion|hydropump|amnesia');
family([56,57], 'karatechop/lowkick|crosschop/brickbreak|rockslide|bulkup');
family([58,59], 'ember|bite|flamethrower|agility');
family([59], 'ember|bite|flamethrower|extremespeed');
family([60,61], 'bubblebeam|bodyslam|icebeam|hypnosis');
family([62], 'waterfall|brickbreak|icepunch|bulkup');
family([63,64,65], 'confusion/psybeam|shadowball|psychic|recover/reflect');
family([66,67,68], 'karatechop/lowkick|crosschop/brickbreak|rockslide|bulkup');
family([69,70,71], 'vinewhip|razorleaf|sludgebomb|sleeppowder');
family([72,73], 'waterpulse|acid|surf|toxic');
family([74,75,76], 'rockthrow|bulldoze|rockslide|defensecurl');
family([77,78], 'flamecharge|stomp|fireblast|agility');
family([79,80], 'watergun|confusion|surf|slackoff');
family([81,82], 'thundershock|mirror shot/mirrorshot|flashcannon|thunderwave');
family([83], 'aircutter|slash|leafblade|swordsdance');
family([84,85], 'peck|quickattack|drillpeck|agility');
family([86,87], 'aquajet|icywind|icebeam|rest');
family([88,89], 'sludge|poisonjab|sludgebomb|acidarmor');
family([90,91], 'iceshard|iciclespear|surf|withdraw');
family([92,93,94], 'lick|shadowball|sludgebomb|hypnosis');
family([95], 'rockthrow|bulldoze|rockslide|sandtomb');
family([96,97], 'confusion|headbutt|psychic|hypnosis');
family([98,99], 'bubblebeam|visegrip|crabhammer|harden');
family([100,101], 'spark|swift|thunderbolt|lightscreen');
family([102,103], 'confusion|seedbomb|psychic|synthesis');
family([104,105], 'bonemerang|headbutt|boneclub/bonerush|focusenergy');
family([106], 'doublekick|blazekick|highjumpkick|bulkup');
family([107], 'machpunch|icepunch|drainpunch|bulkup');
family([108], 'lick|bodyslam|powerwhip|rest');
family([109,110], 'smog|sludge|sludgebomb|willowisp');
family([111,112], 'rockblast|hornattack|earthquake|scaryface');
family([113], 'disarmingvoice|seismictoss|icebeam|softboiled');
family([114], 'megadrain|ancientpower|gigadrain|sleeppowder');
family([115], 'fakeout|bite|dizzypunch|rest');
family([116,117], 'watergun|dragonbreath|hydropump|smokescreen');
family([118,119], 'waterpulse|hornattack|waterfall|agility');
family([120,121], 'watergun|psybeam/psychic|surf|recover');
family([122], 'confusion|dazzlinggleam|psychic|reflect');
family([123], 'quickattack|xscissor|aerialace|swordsdance');
family([124], 'powdersnow|drainingkiss|psychic|lovelykiss');
family([125], 'thundershock|thunderpunch|icepunch|thunderwave');
family([126], 'ember|firepunch|flamethrower|confuseray');
family([127], 'furycutter|xscissor|brickbreak|swordsdance');
family([128], 'hornattack|zenheadbutt|earthquake|scaryface');
family([129], 'tackle|flail|bounce|splash');
family([130], 'waterfall|crunch|icefang|dragondance');
family([131], 'waterpulse|icebeam|thunderbolt|sing');
family([132], 'transform');
family([133], 'swift|quickattack|shadowball|babydolleyes');
family([134], 'waterpulse|icebeam|surf|acidarmor');
family([135], 'thundershock|pinmissile|thunderbolt|thunderwave');
family([136], 'ember|bite|flareblitz|willowisp');
family([137], 'psybeam|triattack|icebeam|recover');
family([138,139], 'watergun|ancientpower|surf|withdraw');
family([140,141], 'aquajet|rockslide|leechlife|harden');
family([142], 'wingattack|rockslide|crunch|roost');
family([143], 'lick|bodyslam|crunch|rest');
family([144], 'iceshard|airslash|icebeam|roost');
family([145], 'thundershock|drillpeck|thunderbolt|roost');
family([146], 'ember|airslash|flamethrower|roost');
family([147,148], 'dragonbreath|aquatail|dragonpulse|thunderwave');
family([149], 'dragonclaw|wingattack|firepunch|dragondance');
family([150], 'confusion|shadowball|psystrike|recover');
family([151], 'psychic|aurasphere|energyball|lifedew');
family([152], 'razorleaf|bodyslam|energyball|synthesis');
family([185], 'rockthrow|lowkick|rockslide|irondefense');
family([197], 'snarl|foulplay|darkpulse|moonlight');
family([355], 'astonish|shadowball|icywind|willowisp');
family([361], 'powdersnow|bite|icebeam|protect');
family([599], 'thundershock|visegrip|flashcannon|autotomize');
family([821], 'peck|powertrip|pluck|roost');
// Evolved specialists use stronger signature attacks and both STAB types where practical.
family([3], 'razorleaf|sludgebomb|solarbeam|synthesis');
family([6], 'airslash|dragonclaw|flamethrower|roost');
family([9], 'waterpulse|icebeam|hydropump|irondefense');
family([18], 'airslash|quickattack|steelwing|roost');
family([26], 'spark|quickattack|thunderbolt|thunderwave');
family([31], 'earthpower|poisonjab|icebeam|toxic');
family([34], 'earthpower|poisonjab|thunderbolt|focusenergy');
family([149], 'dragonclaw|hurricane|firepunch|dragondance');

// Weather setters retain three attacking moves and a legal fourth-slot weather move.
family([38], 'ember|quickattack|flamethrower|sunnyday');
family([55], 'watergun|confusion|hydropump|raindance');
family([28], 'mudshot|slash|rockslide|sandstorm');
family([87], 'aquajet|icywind|icebeam|hail');
const heal = new Set('recover roost synthesis moonlight softboiled slackoff rest lifedew'.split(' '));
const guard = new Set('protect detect withdraw harden irondefense defensecurl acidarmor reflect lightscreen amnesia'.split(' '));
const buff = new Set('bulkup swordsdance growth dragondance focusenergy agility autotomize'.split(' '));
const slow = new Set('thunderwave stringshot glare hypnosis sleeppowder spore sing lovelykiss confuseray smokescreen sandattack scaryface babydolleyes'.split(' '));
const poison = new Set(['toxic','poisonpowder']);
const burn = new Set(['willowisp']);
const area = new Set('earthquake bulldoze surf rockslide icywind discharge'.split(' '));
const allowedStatus = new Set([...heal,...guard,...buff,...slow,...poison,...burn,'splash','transform']);
function legalMoves(key) {
  const allowed = new Set(); let current = key;
  while(current) {
    for(const m of Object.keys(learnsets[current]?.learnset || {})) allowed.add(m);
    current = dex[current]?.prevo ? id(dex[current].prevo) : null;
  }
  return allowed;
}
const report = [];
const roster = selected.map(([key,p])=>{
 const legal = legalMoves(key), chosen = [];
 for(const candidates of plans.get(p.num) || []) {
   const found = candidates.map(id).find(m=>legal.has(m) && moves[m] && !chosen.includes(m));
   if(found) chosen.push(found); else report.push(`${p.name}: unavailable preferred ${candidates.join('/')}`);
 }
 const score = key => {
   const m=moves[key]; if(!m || m.isZ || m.isMax || m.isNonstandard==='Custom') return -999;
   if(m.category==='Status') return allowedStatus.has(key) ? 15 : -999;
   if(!m.basePower || m.basePower>130 || m.selfdestruct || m.recharge || key==='hiddenpower' || key==='terablast') return -999;
   return (p.types.includes(m.type)?40:0) + Math.min(m.basePower,90)*0.35 + (m.category==='Physical'?p.baseStats.atk:p.baseStats.spa)*0.15;
 };
 if(p.num!==132) {
   const candidates = [...legal].filter(m=>!chosen.includes(m) && score(m)>-999).sort((a,b)=>score(b)-score(a));
   while(chosen.length<4 && candidates.length) chosen.push(candidates.shift());
   if(chosen.length!==4) throw Error(`${p.name}: only ${chosen.length} moves`);
 }
 const converted = chosen.map((key,slot)=>{
   const m=moves[key];
   let kind=m.category==='Physical' && m.flags?.contact ? 'dash' : slot===2?'orb':'bolt';
   if(area.has(key)) kind='pulse';
   if(m.category==='Status') kind=heal.has(key)?'heal':guard.has(key)?'guard':buff.has(key)?'buff':key==='transform'?'transform':key==='splash'?'splash':'status';
   let effect=poison.has(key)?'poison':burn.has(key)?'burn':slow.has(key)?'slow':'';
   const bp=m.basePower || (m.damage?60:0) || (m.category!=='Status'?60:0);
   const damage = m.category==='Status'?0:Math.round((8+bp*0.26)*10)/10;
   const cooldown = kind==='heal'?9:kind==='guard'?7:kind==='buff'?8:kind==='status'?6:kind==='transform'?8:kind==='splash'?2:Math.round((0.4+bp/55+(kind==='dash'?0.5:0))*100)/100;
   return {id:key,name:m.name,type:m.type,category:m.category,base_power:bp,kind,effect,damage,cost:m.category==='Status'?kind==='splash'?0:25:Math.round(5+bp*.19),cooldown,drain:!!m.drain,recoil:!!m.recoil,arena_only:false,...moveRules(m,key)};
 });
 if(p.num===132) converted.push(
   {id:'arena_reposition',name:'Reposition',type:'Normal',category:'Status',kind:'teleport',damage:0,cost:15,cooldown:3,effect:'',arena_only:true},
   {id:'arena_struggle',name:'Struggle (Arena)',type:'Normal',category:'Physical',kind:'dash',damage:18,cost:12,cooldown:1.6,effect:'',recoil:true,arena_only:true},
   {id:'arena_guard',name:'Guard (Arena)',type:'Normal',category:'Status',kind:'guard',damage:0,cost:25,cooldown:7,effect:'',arena_only:true}
 );
 for(const m of chosen) if(!legal.has(m)) throw Error(`Illegal move ${p.name}/${m}`);
 return {id:p.num,key,name:p.name,types:p.types,type:p.types[0],base_stats:p.baseStats,hp:130+2*p.baseStats.hp,speed:Math.round(Math.min(340,150+p.baseStats.spe*1.1)),power:1,role:p.baseStats.spe>=100?'speedster':p.baseStats.def>=100?'defender':p.baseStats.atk>p.baseStats.spa+15?'brawler':converted.some(m=>m.kind==='heal')?'sustain':'ranged',moves:converted,sprite:`res://assets/pokemon/${p.num}.png`,source:'Pokemon Showdown / modern National Dex',learnset_scope:'Union of recorded generations and pre-evolution moves; not restricted to one cartridge'};
});
await fs.mkdir('data',{recursive:true});
await fs.writeFile('data/roster.json',JSON.stringify(roster,null,2)+'\n');
await fs.writeFile('data/movesets.md','# Gen 1 + retained Pokémon\n\nModern base stats and typings. Moves checked against recorded learnsets, including pre-evolutions across generations. Real-time execution is adapted. Ditto has Transform plus three explicitly marked arena actions until transformation.\n\n| No. | Pokémon | Types | HP / Atk / Def / SpA / SpD / Spe | Q | E | F | C |\n|---|---|---|---|---|---|---|---|\n'+roster.map(p=>`| ${p.id} | ${p.name} | ${p.types.join('/')} | ${Object.values(p.base_stats).join(' / ')} | ${p.moves.map(m=>m.name).join(' | ')} |`).join('\n')+'\n');
const hashes={};
for(const n of ['pokedex','moves','learnsets']) hashes[n]={url:`https://play.pokemonshowdown.com/data/${n}.json`,sha256:crypto.createHash('sha256').update(await fs.readFile(`data/source/${n}.json`)).digest('hex')};
await fs.writeFile('data/sources.json',JSON.stringify({retrieved:new Date().toISOString(),data:hashes,sprites:'https://github.com/PokeAPI/sprites/tree/master/sprites/pokemon',total:roster.length,retained:extraIds},null,2));
console.log(report.join('\n')||'All curated choices available.');
console.log(`Built ${roster.length} Pokémon / ${roster.reduce((n,p)=>n+p.moves.length,0)} actions.`);


