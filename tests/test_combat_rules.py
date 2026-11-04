#!/usr/bin/env python3
"""Run shared cooldown, autoskip and target-split rules under the Luau CLI."""
import pathlib, subprocess, sys, tempfile
if len(sys.argv) != 2:
    raise SystemExit('Provide the path to the Luau CLI')
root = pathlib.Path(__file__).resolve().parent.parent
source = (root / 'src/ReplicatedStorage/CombatRules.luau').read_text(encoding='utf-8')
assert source.rstrip().endswith('return Rules')
tests = '''
assert(Rules.readyAt(nil, 10, 45)==0)
assert(Rules.readyAt(20, 10, 45)==65)
assert(Rules.readyAt(20, 80, 45)==125)
assert(not Rules.canUltimate("Wave",false,124,125,1))
assert(Rules.canUltimate("Wave",false,125,125,1))
assert(not Rules.canUltimate("Wave",true,200,125,1))
assert(not Rules.canUltimate("Intermission",false,200,125,1))
assert(not Rules.canUltimate("Wave",false,200,125,0))
assert(not Rules.canUltimate("Wave",false,200,0,1))
assert(Rules.intermission(false,false,18)==18)
assert(Rules.intermission(true,false,18)==0)
assert(Rules.intermission(false,true,18)==0)
assert(Rules.sniperSplit(1)==0 and Rules.sniperSplit(2)==0 and Rules.sniperSplit(3)==1 and Rules.sniperSplit(8)==3)
print("OK: cooldown, activation, autoskip and sniper phases")
'''
with tempfile.TemporaryDirectory() as tmp:
    test = pathlib.Path(tmp) / 'rules_test.luau'
    test.write_text(source.rsplit('return Rules', 1)[0] + tests, encoding='utf-8')
    subprocess.run([sys.argv[1], str(test)], check=True)
