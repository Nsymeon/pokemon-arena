import fs from 'node:fs/promises';
import {moveRules} from './move-rules.mjs';
const source=JSON.parse(await fs.readFile('data/source/moves.json','utf8'));
const mon=(id,level,moves)=>({id,level,moves:moves.split(' ')});
const common=[mon(18,61,'whirlwind wingattack skyattack mirrormove'),mon(65,59,'psybeam recover psychic reflect'),mon(112,61,'tailwhip furyattack horndrill leer')];
const egg=l=>mon(103,l,'barrage hypnosis stomp');
const gyara=l=>mon(130,l,'dragonrage leer hydropump hyperbeam');
const arc=l=>mon(59,l,'roar ember leer takedown');
const trainers=[
{id:'lorelei',name:'Lorelei',title:'Elite Four / Ice',team:[mon(87,54,'growl aurorabeam rest takedown'),mon(91,53,'supersonic clamp aurorabeam spikecannon'),mon(80,54,'growl watergun withdraw amnesia'),mon(124,56,'doubleslap icepunch bodyslam thrash'),mon(131,56,'bodyslam confuseray blizzard hydropump')]},
{id:'bruno',name:'Bruno',title:'Elite Four / Fighting',team:[mon(95,53,'rockthrow rage slam harden'),mon(107,55,'icepunch thunderpunch megapunch counter'),mon(106,55,'jumpkick focusenergy highjumpkick megakick'),mon(95,56,'rockthrow rage slam harden'),mon(68,58,'leer focusenergy fissure submission')]},
{id:'agatha',name:'Agatha',title:'Elite Four / Ghost',team:[mon(94,56,'confuseray nightshade hypnosis dreameater'),mon(42,56,'supersonic confuseray wingattack haze'),mon(93,55,'confuseray nightshade hypnosis dreameater'),mon(24,58,'bite glare screech acid'),mon(94,60,'confuseray nightshade toxic dreameater')]},
{id:'lance',name:'Lance',title:'Elite Four / Dragon',team:[gyara(58),mon(148,56,'agility slam dragonrage hyperbeam'),mon(148,56,'agility slam dragonrage hyperbeam'),mon(142,60,'supersonic bite takedown hyperbeam'),mon(149,62,'agility slam barrier hyperbeam')]},
{id:'blue_charizard',name:'Blue',title:'Champion / Charizard',team:[...common,egg(61),gyara(63),mon(6,65,'rage slash fireblast firespin')]},
{id:'blue_blastoise',name:'Blue',title:'Champion / Blastoise',team:[...common,arc(61),egg(63),mon(9,65,'bite withdraw blizzard hydropump')]},
{id:'blue_venusaur',name:'Blue',title:'Champion / Venusaur',team:[...common,gyara(61),arc(63),mon(3,65,'razorleaf growth megadrain solarbeam')]}
];
trainers.push(
{id:'brock',name:'Brock',title:'Pewter Gym / Rock',team:[mon(74,12,'tackle defensecurl'),mon(95,14,'tackle screech bide')]},
{id:'misty',name:'Misty',title:'Cerulean Gym / Water',team:[mon(120,18,'tackle watergun'),mon(121,21,'tackle watergun harden bubblebeam')]},
{id:'surge',name:'Lt. Surge',title:'Vermilion Gym / Electric',team:[mon(100,21,'tackle screech sonicboom'),mon(25,18,'thundershock thunderwave growl quickattack'),mon(26,24,'thunderbolt thundershock thunderwave growl')]},
{id:'erika',name:'Erika',title:'Celadon Gym / Grass',team:[mon(71,29,'wrap poisonpowder sleeppowder razorleaf'),mon(114,24,'bind constrict'),mon(45,29,'poisonpowder megadrain sleeppowder petaldance')]},
{id:'koga',name:'Koga',title:'Fuchsia Gym / Poison',team:[mon(109,37,'tackle smog sludge smokescreen'),mon(89,39,'disable poisongas minimize sludge'),mon(109,37,'tackle smog sludge smokescreen'),mon(110,43,'smog sludge toxic selfdestruct')]},
{id:'sabrina',name:'Sabrina',title:'Saffron Gym / Psychic',team:[mon(64,38,'disable psybeam recover psychic'),mon(122,37,'confusion barrier lightscreen doubleslap'),mon(49,38,'poisonpowder leechlife stunspore psybeam'),mon(65,43,'psybeam recover psywave reflect')]},
{id:'blaine',name:'Blaine',title:'Cinnabar Gym / Fire',team:[mon(58,42,'ember leer takedown agility'),mon(77,40,'tailwhip stomp growl firespin'),mon(78,42,'tailwhip stomp growl firespin'),mon(59,47,'roar ember takedown fireblast')]},
{id:'giovanni',name:'Giovanni',title:'Viridian Gym / Ground',team:[mon(111,45,'stomp tailwhip furyattack hornattack'),mon(51,42,'growl dig sandattack slash'),mon(31,44,'scratch tailwhip poisonsting bodyslam'),mon(34,45,'tackle hornattack poisonsting thrash'),mon(112,50,'stomp tailwhip fissure horndrill')]}
);
function convert(id,level) {
 const m=source[id];if(!m)throw Error(id);
 const bp=m.basePower||60;
 let kind=m.category==='Physical'&&m.flags?.contact?'dash':'bolt';
 if(m.category==='Status')kind=['rest','recover'].includes(id)?'heal':['withdraw','harden','barrier','reflect','amnesia'].includes(id)?'guard':['agility','growth','focusenergy'].includes(id)?'buff':'status';
 if(['fissure','blizzard'].includes(id))kind='pulse';
 const out={id,name:m.name,type:m.type,category:m.category,base_power:bp,kind,damage:m.category==='Status'?0:Math.round((8+bp*.26)*10)/10,cost:m.category==='Status'?22:Math.round(5+bp*.19),cooldown:m.category==='Status'?6:Math.round((.4+bp/55+(kind==='dash'?.5:0))*100)/100,drain:!!m.drain,recoil:!!m.recoil,arena_only:false,...moveRules(m,id)};
 if(m.multihit)out.damage=Math.round((8+bp*.26*3)*10)/10;
 if(['nightshade','dragonrage'].includes(id)){out.fixed_damage=true;out.damage=id==='dragonrage'?40:level;}
 if(['fissure','horndrill'].includes(id)){out.damage=65;out.cost=32;out.cooldown=5;}
 if(id==='rage')out.self_effect={boosts:{atk:1}};
 if(['defensecurl','lightscreen'].includes(id))out.kind='guard';
 if(id==='minimize')out.kind='buff';
 if(id==='sonicboom'){out.fixed_damage=true;out.damage=20;}
 if(id==='psywave'){out.fixed_damage=true;out.damage=level;}
 return out;
}
for(const t of trainers)for(const p of t.team)p.moves=p.moves.map(id=>typeof id === 'string' ? convert(id,p.level) : structuredClone(id));
await fs.writeFile('data/trainers.json',JSON.stringify({edition:'Pokemon Red/Blue - Kanto gyms and first Indigo Plateau challenge',source:'https://bulbapedia.bulbagarden.net/wiki/Indigo_Plateau/Generation_I',gym_source:'https://www.serebii.net/rb/gyms.shtml',trainers},null,2)+'\n');
console.log('Built 15 opponent presets: eight Kanto gyms, Elite Four and all three Blue teams.');

