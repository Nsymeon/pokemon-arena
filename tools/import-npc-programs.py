"""Compile bounded, ordered FireRed NPC dialogue programs (not a cartridge VM).

Unknown gameplay opcodes exclude the entire reachable program. Cosmetic commands
are explicit no-ops; dedicated story/battle/service handlers retain priority.
"""
import argparse
import ast
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/source/pokefirered'
TARGET = ROOT / 'assets/kanto/npc-programs.json'
NOOPS = set('lock lockall release releaseall faceplayer textcolor closemessage waitmessage waitbuttonpress waitfanfare playfanfare waitse playse waitmoncry delay showmoneybox hidemoneybox updatemoneybox showcoinsbox hidecoinsbox updatecoinsbox putitemaway applymovement waitmovement normalmsg signmsg'.split())
OPS = set('end return goto call switch case setvar copyvar addvar subvar compare compare_var_to_value checkflag setflag clearflag checkitem checkitemspace additem removeitem giveitem giveitem_msg msgreceiveditem msgbox message multichoice multichoicedefault multichoicegrid yesnobox checkplayergender bufferitemname bufferitemnameplural buffernumberstring bufferspeciesname bufferpartymonnick bufferstring checkmoney addmoney removemoney checkcoins addcoins removecoins checkpartymove getpartysize playmoncry goto_if_questlog famechecker'.split())
SPECIALS = {'QuestLog_CutRecording', 'GetPokedexCount', 'GetPlayerFacingDirection', 'GetLeadMonFriendship', 'GetLeadMonIndex'}
BRANCH = re.compile(r'(?:goto|call)_if_(?:eq|ne|lt|le|gt|ge|set|unset)$')


def literal(value):
    """Only arithmetic literals from trusted source constants, never eval()."""
    try:
        node = ast.parse(value, mode='eval').body
        def calc(n):
            if isinstance(n, ast.Constant) and isinstance(n.value, int): return n.value
            if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub): return -calc(n.operand)
            if isinstance(n, ast.BinOp):
                x, y = calc(n.left), calc(n.right)
                if isinstance(n.op, ast.Add): return x+y
                if isinstance(n.op, ast.Sub): return x-y
                if isinstance(n.op, ast.Mult): return x*y
            raise ValueError()
        return calc(node)
    except (SyntaxError, ValueError): return value


def export():
    blocks, texts, issues = {}, {}, {}
    constants = {'TRUE':'1','FALSE':'0','YES':'1','NO':'0','MALE':'0','FEMALE':'1', 'MAX_COINS':'9999',
                 'DIR_SOUTH':'1','DIR_NORTH':'2','DIR_WEST':'3','DIR_EAST':'4'}
    for path in sorted((SOURCE/'data').rglob('*.inc')):
        raw = path.read_text(encoding='utf8')
        local = constants | dict(re.findall(r'^\.(?:set|equ)\s+(\w+),\s*([^\n@]+)',raw,re.M))
        entries=re.findall(r'^(\w+)::?[^\n]*\n(.*?)(?=^\w+::?|\Z)',raw,re.M|re.S)
        for index, (label, body) in enumerate(entries):
            strings = re.findall(r'\.string\s+"([^"\n]*)"',body)
            if strings:
                texts[label]=''.join(strings).replace('\\p','\n\n').replace('\\n',' ').replace('\\l',' ').replace('$','').strip()
                continue
            program=[]; bad=[]
            for line in body.splitlines():
                line=line.split('@')[0].strip()
                if not line or line.startswith(('.', '#')): continue
                parts=line.split(None,1); op=parts[0]
                args=[v.strip() for v in parts[1].split(',')] if len(parts)>1 else []
                args=[literal(re.sub(r'\b\w+\b',lambda m:local.get(m[0],m[0]),v)) for v in args]
                # This source list menu is fixed; other engine list menus remain dedicated.
                if path.parent.name=='CeruleanCity_House1':
                    if op=='waitstate': continue
                    if op=='special' and args[0] in ('ListMenu','ReturnToListMenu'):
                        program.append(['badgemenu']); continue
                if op in NOOPS: continue
                if op in ('special','specialvar'):
                    if args[-1] not in SPECIALS: bad.append(op+':'+str(args[-1]))
                elif op not in OPS and not BRANCH.fullmatch(op): bad.append(op)
                program.append([op,*args])
                if op in ('end','return','goto'): break  # Source labels explicitly terminate.
            if program and program[-1][0] not in ('end','return','goto'):
                if index+1<len(entries): program.append(['goto',entries[index+1][0]])
                else: bad.append('missing termination')
            blocks[label]=program
            if bad: issues[label]=sorted(set(bad))
    # Cosmetic shared subroutines need no source engine state.
    for label in ('EventScript_RestorePrevTextColor',):
        blocks[label]=[['return']]; issues.pop(label,None)
    menu_source=(SOURCE/'src/script_menu.c').read_text(encoding='utf8')
    ctexts=(SOURCE/'src/strings.c').read_text(encoding='utf8')
    cstrings=dict(re.findall(r'const u8 (\w+)\[\]\s*=\s*_\("(.*?)"\);',ctexts))
    lists={label:[cstrings.get(key,re.sub(r'^g(?:Other)?Text_','',key)) for key in re.findall(r'\{\s*(g\w+)',body)] for label,body in re.findall(r'static const struct MenuAction (\w+)\[\] = \{(.*?)\};',menu_source,re.S)}
    choices={key:lists[label] for key,label in re.findall(r'\[(MULTICHOICE_\w+)\]\s*=\s*MULTICHOICE\((\w+)\)',menu_source)}
    def dependencies(label):
        for cmd in blocks.get(label,[]):
            if cmd[0] in ('goto','call','case') or BRANCH.fullmatch(cmd[0]): yield str(cmd[-1])
    def reachable(root):
        found=set(); pending=[root]
        while pending:
            at=pending.pop()
            if at in found: continue
            found.add(at); pending.extend(dependencies(at))
        return found
    roots=set()
    for path in (SOURCE/'data/maps').glob('*/map.json'):
        data=json.loads(path.read_text(encoding='utf8'))
        roots.update(o.get('script','') for key in ('object_events','bg_events') for o in data.get(key,[]))
    roots.discard(''); roots.discard('NULL')
    supported=[]; unsupported={}
    for root in sorted(roots):
        labels=reachable(root); bad=set()
        for label in labels:
            if label not in blocks: bad.add('missing:'+label)
            bad.update(issues.get(label,[]))
            for cmd in blocks.get(label,[]):
                if cmd[0] in ('multichoice','multichoicedefault','multichoicegrid') and cmd[3] not in choices: bad.add('choice:'+str(cmd[3]))
        if bad: unsupported[root]=sorted(bad)
        else: supported.append(root)
    needed=set().union(*(reachable(root) for root in supported))
    species={row['key'].upper().replace('-','_'):row['id'] for row in json.loads((ROOT/'data/roster.json').read_text(encoding='utf8'))}
    species.update({'NIDORAN_F':29,'NIDORAN_M':32,'MR_MIME':122,'FARFETCHD':83})
    return {'source':'pret/pokefirered ce6406d8c2eaf46d543c8a2606de0c3cb1951982',
            'roots':supported,'programs':{k:blocks[k] for k in sorted(needed)},'texts':texts,'choices':choices,
            'species':species,'unsupported':unsupported}


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    result=export(); payload=json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n'
    if args.check:
        assert TARGET.read_text(encoding='utf8')==payload,'NPC program export differs from pinned source'
    else: TARGET.write_text(payload,encoding='utf8')
    print('Executable NPC/sign roots:',len(result['roots']),'Dedicated/fallback roots:',len(result['unsupported']))
    print('Remaining commands:',Counter(op for ops in result['unsupported'].values() for op in ops).most_common(22))
