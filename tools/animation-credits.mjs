import fs from 'node:fs/promises';
const root='assets/animated';
const names=new Map((await fs.readFile(`${root}/credit_names.txt`,'utf8')).split(/\r?\n/).slice(1).map(line=>{const [name,id,contact]=line.split('\t');return [id,{name,contact}]}));
const roster=JSON.parse(await fs.readFile('data/roster.json','utf8'));
const source=JSON.parse(await fs.readFile(`${root}/source.json`,'utf8'));
let out=`# Animated Pokémon artwork credits\n\nSource: [PMD SpriteCollab](${source.repository}), revision \`${source.revision}\`.\n\nOriginal Mystery Dungeon sprites: Chunsoft / respective Pokémon rights holders. Community contributions follow the repository's [CC BY-NC 4.0 policy](https://github.com/PMDCollab/SpriteCollab#submission-and-use-policy). This is a noncommercial fan prototype.\n\nThe sprite sheets are unmodified. Runtime code selects frames, scales them and applies transient colors. Per-species original credit histories and original AnimData.xml files are retained in this folder. The table credits every contributor listed in those histories; detailed animation assignments remain in each credits.txt.\n\n| Pokémon | Credited artists |\n|---|---|\n`;
for(const mon of roster){
 const lines=(await fs.readFile(`${root}/${mon.id}/credits.txt`,'utf8')).trim().split(/\r?\n/);
 const authors=[...new Set(lines.map(l=>l.split('\t')[1]))].map(id=>{const n=names.get(id);if(!n)return id;return n.contact?.startsWith('https://')?`[${n.name}](${n.contact})`:n.name;});
 out+=`| #${mon.id} ${mon.name} | ${authors.join(', ')} |\n`;
}
await fs.writeFile(`${root}/CREDITS.md`,out);
console.log('Wrote animation attributions for',roster.length,'species');
