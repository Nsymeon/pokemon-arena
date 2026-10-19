import fs from 'node:fs/promises';
const root='https://raw.githubusercontent.com/PMDCollab/SpriteCollab/';
const roster=JSON.parse(await fs.readFile('data/roster.json','utf8'));
const revision=await fetch('https://api.github.com/repos/PMDCollab/SpriteCollab/commits/master').then(r=>r.json()).then(r=>r.sha);
if(!revision) throw Error('Cannot pin sprite revision');
const base=root+revision+'/';
async function get(path){for(let i=0;i<3;i++){const r=await fetch(base+path);if(r.ok)return Buffer.from(await r.arrayBuffer());if(r.status===404)return null;}throw Error(path);}
await fs.mkdir('assets/animated',{recursive:true});
const manifest={};let next=0;
async function worker(){while(next<roster.length){const mon=roster[next++], folder=String(mon.id).padStart(4,'0'), dir=`assets/animated/${mon.id}`;
 const xml=await get(`sprite/${folder}/AnimData.xml`);if(!xml){console.log('Missing',mon.name);continue;}
 await fs.mkdir(dir,{recursive:true});await fs.writeFile(`${dir}/AnimData.xml`,xml);
 const blocks=[...xml.toString().matchAll(/<Anim>([\s\S]*?)<\/Anim>/g)].map(m=>m[1]);
 const tag=(b,k)=>b.match(new RegExp(`<${k}>(.*?)</${k}>`))?.[1];
 const animations={};
 for(const name of ['Idle','Walk','Attack','Shoot','Hurt']){
  let b=blocks.find(b=>tag(b,'Name')===name);if(!b)continue;
  let source=name;const visited=new Set();
  while(tag(b,'CopyOf')){if(visited.has(source))throw Error('Animation cycle');visited.add(source);source=tag(b,'CopyOf');b=blocks.find(b=>tag(b,'Name')===source);if(!b)break;}
  if(!b)continue;
  const png=await get(`sprite/${folder}/${source}-Anim.png`);if(!png)continue;
  await fs.writeFile(`${dir}/${name}.png`,png);
  animations[name]={width:Number(tag(b,'FrameWidth')),height:Number(tag(b,'FrameHeight')),durations:[...b.matchAll(/<Duration>(\d+)<\/Duration>/g)].map(m=>Number(m[1])),path:`res://${dir}/${name}.png`};
 }
 const credits=await get(`sprite/${folder}/credits.txt`);if(credits)await fs.writeFile(`${dir}/credits.txt`,credits);
 manifest[mon.id]=animations;
 if(Object.keys(manifest).length%20===0)console.log('Animated species',Object.keys(manifest).length);
}}
await Promise.all(Array.from({length:8},worker));
await fs.writeFile('assets/animated/manifest.json',JSON.stringify(manifest,null,2));
for(const name of ['README.md','credit_names.txt']){const b=await get(name);if(b)await fs.writeFile(`assets/animated/${name}`,b);}
await fs.writeFile('assets/animated/source.json',JSON.stringify({repository:'https://github.com/PMDCollab/SpriteCollab',revision,downloaded:new Date().toISOString(),species:Object.keys(manifest).length},null,2));
console.log('Done',Object.keys(manifest).length);
