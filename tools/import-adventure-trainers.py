"""Import FireRed trainer builds and map-script identities, without changing maps.

Default moves emulate GiveBoxMonInitialMoveset, using the FireRed branch of the
source learnsets. Custom trainer moves bypass player learnset restrictions.
--check validates the committed export against the pinned source.
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/source/pokefirered'
TARGET = ROOT / 'assets/kanto/trainer-builds.json'
ALIASES = {'hijumpkick': 'highjumpkick', 'vicegrip': 'visegrip',
           'faintattack': 'feintattack', 'smellingsalt': 'smellingsalts'}


def norm(value):
    key = re.sub('[^a-z0-9]', '', value.lower())
    return ALIASES.get(key, key)


def read(path):
    return (SOURCE / path).read_text(encoding='utf8')


def firered(text):
    # These data files contain only this version conditional, not a script VM.
    return re.sub(r'#if defined\(FIRERED\)\s*\n(.*?)#elif defined\(LEAFGREEN\).*?#endif', r'\1', text, flags=re.S)


def export():
    roster = json.loads((ROOT / 'data/roster.json').read_text(encoding='utf8'))
    ids = {norm(mon['key']): mon['id'] for mon in roster}
    moves = json.loads((ROOT / 'data/adventure-learnsets.json').read_text(encoding='utf8'))['moves']
    moves = moves | json.loads((ROOT / 'data/battle-learnsets.json').read_text(encoding='utf8'))['moves']
    learnsets = {symbol: [(int(level), norm(move)) for level, move in re.findall(r'LEVEL_UP_MOVE\((\d+), MOVE_(\w+)\)', body)]
                for symbol, body in re.findall(r'static const u16 (\w+)\[\] = \{(.*?)\};', firered(read('src/data/pokemon/level_up_learnsets.h')), re.S)}
    pointers = dict(re.findall(r'\[SPECIES_(\w+)\] = (\w+)', read('src/data/pokemon/level_up_learnset_pointers.h')))
    parties = {}
    for symbol, body in re.findall(r'^static const struct \w+ (sParty_\w+)\[\] = \{(.*?)(?=^static const|\Z)', read('src/data/trainer_parties.h'), re.M | re.S):
        team = []
        for entry in re.findall(r'\{((?:[^{}]|\{[^{}]*\})*)\}', body, re.S):
            level = re.search(r'\.lvl = (\d+)', entry)
            species = re.search(r'\.species = SPECIES_(\w+)', entry)
            if not level or not species:
                continue  # Unused Ruby/Sapphire placeholder macros.
            level = int(level[1]); species = species[1]
            custom = re.search(r'\.moves = \{([^}]*)\}', entry)
            attacks = []
            if custom:
                attacks = [norm(move) for move in re.findall(r'MOVE_(\w+)', custom[1]) if move != 'NONE']
            else:
                for at, move in learnsets[pointers[species]]:
                    if at > level:
                        break
                    if move not in attacks:
                        attacks.append(move)
                        attacks = attacks[-4:]
            item = re.search(r'\.heldItem = ITEM_(\w+)', entry)
            assert 1 <= len(attacks) <= 4 and len(set(attacks)) == len(attacks), (symbol, attacks)
            assert all(move in moves for move in attacks), (symbol, set(attacks) - moves.keys())
            team.append({'id': ids[norm(species)], 'level': level, 'moves': attacks,
                         'held_item': norm(item[1]) if item and item[1] != 'NONE' else '',
                         'custom_moves': bool(custom)})
        if team:
            parties[symbol] = team
    trainers = {}
    for key, body in re.findall(r'\[(TRAINER_\w+)\] = \{(.*?)\n    \}', read('src/data/trainers.h'), re.S):
        party = re.search(r'\.party = \w+\((sParty_\w+)\)', body)
        if not party or party[1] not in parties:
            continue
        item_list = re.search(r'\.items = \{([^}]*)\}', body)
        trainers[key] = {
            'name': re.search(r'\.trainerName = _\("([^"\n]*)"\)', body)[1],
            'trainer_class': re.search(r'\.trainerClass = TRAINER_CLASS_(\w+)', body)[1],
            'picture': re.search(r'\.trainerPic = TRAINER_PIC_(\w+)', body)[1],
            'items': [norm(item) for item in re.findall(r'ITEM_(\w+)', item_list[1]) if item != 'NONE'],
            'double_battle': '.doubleBattle = TRUE' in body,
            'party': parties[party[1]],
        }
    text = '\n'.join(p.read_text(encoding='utf8') for p in (SOURCE / 'data').rglob('*.inc'))
    blocks = dict(re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)', text, re.M | re.S))
    scripts = {}
    for label, body in blocks.items():
        match = re.search(r'trainerbattle[^\n]*?\b(TRAINER_\w+)', body)
        if match and match[1] in trainers:
            scripts[label] = match[1]
    # This actor calls a separate battle label; the legacy map importer likewise
    # resolves its actual identity instead of treating it as a generic scientist.
    scripts['MtMoon_B2F_EventScript_Miguel'] = 'TRAINER_SUPER_NERD_MIGUEL'
    maps = json.loads((ROOT / 'assets/kanto/maps.json').read_text(encoding='utf8'))
    actors = [(m['name'], o['script']) for m in maps.values() for o in m['objects'] if 'battle' in o]
    missing = [(m, script) for m, script in actors if script not in scripts]
    assert not missing, ('Unresolved imported trainer actors', missing)
    reference = json.loads((ROOT / 'assets/kanto/source.json').read_text(encoding='utf8'))
    return {'repository': reference['repository'], 'revision': reference['revision'],
            'trainers': trainers, 'scripts': scripts}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = export()
    if args.check:
        assert json.loads(TARGET.read_text(encoding='utf8')) == data, 'Trainer builds differ from FireRed source'
    else:
        TARGET.write_text(json.dumps(data, separators=(',', ':')) + '\n', encoding='utf8')
    print('ADVENTURE TRAINER SOURCE CHECK:', len(data['trainers']), 'builds /', len(data['scripts']), 'script identities')
    print('Trainer bag items:', dict(Counter(item for trainer in data['trainers'].values() for item in trainer['items'])))
    print('Held items:', dict(Counter(mon['held_item'] for trainer in data['trainers'].values() for mon in trainer['party'] if mon['held_item'])))
