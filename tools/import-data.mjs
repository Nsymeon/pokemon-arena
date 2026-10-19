import fs from 'node:fs/promises';
import path from 'node:path';
const root = process.cwd();
await fs.mkdir(path.join(root, 'data', 'source'), {recursive:true});
for (const name of ['pokedex','moves','learnsets']) {
  const file = path.join(root, 'data', 'source', `${name}.json`);
  try { await fs.access(file); } catch {
    const url = `https://play.pokemonshowdown.com/data/${name}.json`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`${res.status}: ${url}`);
    const body = await res.text();
    JSON.parse(body);
    await fs.writeFile(file, body);
  }
  console.log(`${name}: cached`);
}
