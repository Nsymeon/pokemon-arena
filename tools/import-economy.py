"""Export FireRed trainer prize multipliers and official item prices."""
import argparse
import json
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'data/source/pokefirered'
items=json.loads((source/'src/data/items.json').read_text(encoding='utf8'))['items']
prices={row['itemId'].removeprefix('ITEM_').lower().replace('_',''):row['price'] for row in items}
text=(source/'src/battle_main.c').read_text(encoding='utf8').split('const struct TrainerMoney gTrainerMoneyTable[] =',1)[1].split('};',1)[0]
classes={key:int(amount) for key,amount in re.findall(r'\{TRAINER_CLASS_(\w+),\s*(\d+)\}',text)}
shops={}
for path in (source/'data/maps').glob('*/scripts.inc'):
 text=path.read_text(encoding='utf8')
 blocks=dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',text,re.M|re.S))
 for key,body in blocks.items():
  match=re.search(r'^\s*pokemart\s+(\w+)',body,re.M)
  if match:
   shops[key]=[item if item.startswith('TM') else 'balls' if item=='POKE_BALL' else item.lower().replace('_','') for item in re.findall(r'\.2byte ITEM_(\w+)',blocks[match[1]]) if item!='NONE']
result={'revision':'ce6406d8c2eaf46d543c8a2606de0c3cb1951982','prices':prices,'trainer_classes':classes,'shops':dict(sorted(shops.items()))}
payload=json.dumps(result,separators=(',',':'))+'\n'
target=root/'assets/kanto/economy.json'
parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
if args.check: assert target.read_text(encoding='utf8')==payload
else: target.write_text(payload,encoding='utf8')
print('FireRed economy:',len(prices),'item prices;',len(classes),'trainer classes')
