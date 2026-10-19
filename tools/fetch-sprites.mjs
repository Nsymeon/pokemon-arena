import fs from 'node:fs/promises';
const roster = JSON.parse(await fs.readFile('data/roster.json','utf8'));
await fs.mkdir('assets/pokemon',{recursive:true});
let next=0, completed=0;
async function worker() {
 while(next<roster.length) {
  const mon=roster[next++], file=`assets/pokemon/${mon.id}.png`;
  try {const b=await fs.readFile(file); if(b.length>8 && b.subarray(1,4).toString()==='PNG') {completed++; continue;}} catch {}
  const url=`https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${mon.id}.png`;
  let success=false;
  for(let attempt=0;attempt<3;attempt++) {
   try {
    const response=await fetch(url);
    if(!response.ok) throw Error(`${response.status} ${url}`);
    const b=Buffer.from(await response.arrayBuffer());
    if(b.subarray(1,4).toString()!=='PNG') throw Error(`Invalid PNG ${url}`);
    await fs.writeFile(file,b); success=true; break;
   } catch(error) {if(attempt===2) throw error;}
  }
  if(success) completed++;
 }
}
await Promise.all(Array.from({length:6},worker));
console.log(`Verified ${completed} local Pokémon sprites.`);
