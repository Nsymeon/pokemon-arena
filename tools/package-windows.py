"""Build the Windows portable ZIP from an explicit allowlist (no caches or secrets)."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--runtime', required=True, type=Path)
p.add_argument('--version', default='local-playtest')
a = p.parse_args()
if not a.runtime.is_file():
    raise SystemExit('Missing Godot Windows runtime')
out = root / 'dist'
out.mkdir(exist_ok=True)
archive = out / 'PokemonArena-Windows.zip'
files = [*root.glob('*.gd'), root/'arena.tscn', root/'project.godot', root/'CREDITS.md']
files += [root/'data/abilities.json', root/'data/move-flags.json', root/'data/roster.json', root/'data/trainers.json', root/'data/adventure-learnsets.json', root/'data/battle-learnsets.json']
files += [f for f in (root/'assets').rglob('*') if f.is_file() and f.suffix in ('.png','.json','.md','.ogg','.mp3')]
files += list((root/'licenses').glob('*.txt'))
with ZipFile(archive, 'w', ZIP_DEFLATED, compresslevel=6) as z:
    prefix = 'PokemonArena-Windows/'
    for f in files:
        z.write(f, prefix+f.relative_to(root).as_posix())
    z.write(a.runtime, prefix+'PokemonArena.exe')
    z.writestr(prefix+'PLAY.bat', '@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nstart "Pokemon Arena" "%~dp0PokemonArena.exe" --path . --log-file game.log\r\n')
    z.writestr(prefix+'VERSION.txt', a.version+'\n')
    z.writestr(prefix+'CHECK-FOR-UPDATES.bat', '@echo off\r\nstart "" "https://github.com/Nsymeon/pokemon-arena/releases/latest"\r\n')
    z.writestr(prefix+'READ-ME.txt', '''POKEMON ARENA - WINDOWS PLAYTEST
Extract the WHOLE ZIP into a folder, then open PLAY.bat.
No separate Godot installation needed. Do not run inside the ZIP.
WASD/arrows: move. Mouse: aim. Q/LMB, E, F, C: moves. Space: sprint.
B / 1-6: switch. Tab: roster. Esc: pause.
Adventure: E interact, P team/moves, I Bag, G capture in wild battles.
Choose Play, then Adventure / Gym Leaders / Free Battles. Progress autosaves.
Single-player against AI; online multiplayer is not implemented.
For updates download the latest release ZIP and extract into a NEW folder.
CHECK-FOR-UPDATES.bat opens the latest release page in your browser.
Report problems with VERSION.txt and game.log.
This portable source build bundles the Godot 4.3 editor as its runtime.
Godot/third-party notices are in licenses/. Pokemon credits: CREDITS.md.
''')
with ZipFile(archive) as z:
    if z.testzip(): raise SystemExit('Archive corruption')
    names = z.namelist()
    assert all('/.godot/' not in n and '/captures/' not in n for n in names)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
( out / 'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n', encoding='utf-8')
print(json.dumps({'zip':str(archive),'megabytes':round(archive.stat().st_size/1048576,1),'sha256':digest}))
