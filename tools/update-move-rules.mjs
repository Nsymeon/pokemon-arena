import fs from 'node:fs/promises';
import {moveRules} from './move-rules.mjs';
const roster=JSON.parse(await fs.readFile('data/roster.json','utf8'));
const source=JSON.parse(await fs.readFile('data/source/moves.json','utf8'));
for(const mon of roster) for(const move of mon.moves) if(source[move.id]) Object.assign(move,moveRules(source[move.id],move.id));
await fs.writeFile('data/roster.json',JSON.stringify(roster,null,2)+'\n');
console.log('Updated move effects and action timing without changing loadouts.');
