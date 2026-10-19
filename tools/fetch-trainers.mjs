import fs from 'node:fs/promises';
import crypto from 'node:crypto';
const names=['red','blue','brock','misty','ltsurge','erika','koga','sabrina','blaine','giovanni','lorelei','bruno','agatha','lance'];
await fs.mkdir('assets/trainers',{recursive:true});
const sources=[];
for(const name of names){
 const url=`https://play.pokemonshowdown.com/sprites/trainers/${name}-gen3.png`;
 const response=await fetch(url);
 if(!response.ok)throw new Error(`${url}: ${response.status}`);
 const bytes=Buffer.from(await response.arrayBuffer());
 if(bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw new Error('Expected PNG: '+url);
 const id=name==='ltsurge'?'surge':name;
 await fs.writeFile(`assets/trainers/${id}.png`,bytes);
 sources.push({id,url,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
}
await fs.writeFile('assets/trainers/sources.json',JSON.stringify({source:'Pokemon Showdown trainer sprite archive',artwork:'Pokemon FireRed/LeafGreen (Generation III), Game Freak / Nintendo / Creatures',sources},null,2)+'\n');
console.log(`Downloaded ${sources.length} original Gen III trainer sprites.`);
