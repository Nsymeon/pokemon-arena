"""Export source reel strips and pay lines; stop timing is adapted to desktop UI."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parents[1]
text = (root / 'data/source/pokefirered/src/slot_machine.c').read_text()
def table(name):
    return re.search(r'\b' + name + r'[^=]*=\s*\{(.*?)\n\};', text, re.S)[1]
reels = [re.findall(r'ICON_(\w+)', body) for body in re.findall(r'\{([^{}]+)\}', table('sReelIconAnimByReelAndPos'))]
lines = [[int(n,16) for n in re.findall(r'0x[0-9a-fA-F]+', row)] for row in re.findall(r'\{([^{}]+)\}', table('sRowAttributes'))]
assert len(reels) == 3 and all(len(r) == 21 for r in reels) and len(lines) == 5
book = {'reels':reels, 'lines':lines, 'payouts':{'CHERRIES':2,'CHERRIES_PAIR':6,'MAGNEMITE':8,'SHELLDER':8,'PIKACHU':15,'PSYDUCK':15,'ROCKET':100,'7':300}}
(root / 'assets/kanto/game-corner.json').write_text(json.dumps(book, indent=2), encoding='utf8')
print('Game Corner: 3 source reels, 21 symbols each, 5 bet-gated pay lines')
