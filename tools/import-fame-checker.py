"""Read all 96 Fame Checker facts and 16 completion letters from pinned FireRed."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'data/source/pokefirered'
text = (source / 'data/text/fame_checker.inc').read_text(encoding='utf8')
blocks = dict(re.findall(r'^(\w+)::[^\n]*\n(.*?)(?=^\w+::|\Z)', text, re.M | re.S))

def content(label):
    result = ''.join(re.findall(r'\.string "(.*)"', blocks[label]))
    result = re.sub(r'\{(?!PLAYER\}|RIVAL\})[^}]+\}', '', result)
    return result.replace('\\n', ' ').replace('\\l', ' ').replace('\\p', '\n\n').replace('$', '').strip()

people = ['ProfOak', 'Daisy', 'Brock', 'Misty', 'LtSurge', 'Erika', 'Koga', 'Sabrina',
          'Blaine', 'Lorelei', 'Bruno', 'Agatha', 'Lance', 'Bill', 'MrFuji', 'Giovanni']
book = {}
for person in people:
    key = 'FAMECHECKER_' + ('OAK' if person == 'ProfOak' else person.upper())
    book[key] = {'name': content('gFameCheckerPersonName_' + person),
                 'quote': content('gFameCheckerPersonQuote_' + person),
                 'facts': [content('gFameCheckerFlavorText_' + person + str(i)) for i in range(6)]}
assert len(book) == 16 and sum(len(p['facts']) for p in book.values()) == 96
(root / 'assets/kanto/fame-checker.json').write_text(json.dumps(book, ensure_ascii=False, indent=2), encoding='utf8')
print('Fame Checker: 16 people, 96 facts, 16 completion letters')
