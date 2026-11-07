"""Export only Adventure Gym builds from the pinned FireRed source.

Run with --check to verify the committed data without changing it. Daily and
Free Battle presets are deliberately independent of this import.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/source/pokefirered/src/data'
TARGET = ROOT / 'assets/kanto/gym-leaders.json'
LEADERS = {
    'brock': 'BROCK', 'misty': 'MISTY', 'surge': 'LT_SURGE',
    'late_erika': 'ERIKA', 'late_koga': 'KOGA', 'late_sabrina': 'SABRINA',
    'late_blaine': 'BLAINE', 'late_giovanni': 'GIOVANNI',
}


def normalized(value):
    return re.sub('[^a-z0-9]', '', value.lower())


def export():
    trainers = (SOURCE / 'trainers.h').read_text(encoding='utf8')
    parties = (SOURCE / 'trainer_parties.h').read_text(encoding='utf8')
    roster = json.loads((ROOT / 'data/roster.json').read_text(encoding='utf8'))
    ids = {normalized(mon['key']): mon['id'] for mon in roster}
    moves = json.loads((ROOT / 'data/adventure-learnsets.json').read_text(encoding='utf8'))['moves']
    leaders = {}
    for kind, symbol in LEADERS.items():
        source_id = 'TRAINER_LEADER_' + symbol
        body = re.search(r'\[' + source_id + r'\] = \{(.*?)\n    \}', trainers, re.S)[1]
        party_symbol = re.search(r'\.party = NO_ITEM_CUSTOM_MOVES\((\w+)\)', body)[1]
        party = re.search(re.escape(party_symbol) + r'\[\] = \{(.*?)\n\};', parties, re.S)[1]
        team = []
        for entry in re.findall(r'\{((?:[^{}]|\{[^{}]*\})*)\}', party, re.S):
            level = re.search(r'\.lvl = (\d+)', entry)
            species = re.search(r'\.species = SPECIES_(\w+)', entry)
            attacks = [normalized(m) for m in re.findall(r'MOVE_(\w+)', entry) if m != 'NONE']
            assert level and species and 1 <= len(attacks) <= 4, source_id
            assert all(move in moves for move in attacks), (source_id, attacks)
            team.append({'id': ids[normalized(species[1])], 'level': int(level[1]),
                         'moves': attacks, 'held_item': ''})
        items = [normalized(item) for item in re.findall(r'ITEM_(\w+)', re.search(r'\.items = \{([^}]*)\}', body)[1]) if item != 'NONE']
        assert team and set(items) <= {'superpotion', 'hyperpotion', 'fullheal'}, source_id
        leaders[kind] = {'source_id': source_id, 'identity': kind.removeprefix('late_'),
                         'name': re.search(r'\.trainerName = _\("([^"]+)"\)', body)[1],
                         'items': items, 'party': team}
    reference = json.loads((ROOT / 'assets/kanto/source.json').read_text(encoding='utf8'))
    return {'repository': reference['repository'], 'revision': reference['revision'], 'leaders': leaders}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = export()
    if args.check:
        assert json.loads(TARGET.read_text(encoding='utf8')) == data, 'Adventure Gym data differs from pinned FireRed source'
        print('ADVENTURE GYM SOURCE CHECK: 8 exact teams, moves, held items and trainer inventories')
    else:
        TARGET.write_text(json.dumps(data, indent=2) + '\n', encoding='utf8')
        print('Exported 8 FireRed Adventure Gym builds to', TARGET.name)
