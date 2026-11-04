#!/usr/bin/env python3
"""Test the actual shared Luau placement geometry with lightweight vector stubs.
Usage: python tests/test_placement.py /path/to/luau
"""
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) != 2:
    raise SystemExit('Provide the path to the Luau CLI')
prefix = '''
local Vector2 = {}
local mt = {}
mt.__index=function(t,k) if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y) elseif k=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y end end end
mt.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
mt.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
mt.__mul=function(a,b) return Vector2.new(a.X*b,a.Y*b) end
mt.__div=function(a,b) return Vector2.new(a.X/b,a.Y/b) end
function Vector2.new(x,y) return setmetatable({X=x,Y=y},mt) end
local function v(x,y,z) return {X=x,Y=y,Z=z} end
'''
suffix = '''
local arena={Position=v(300,-1,0),Size=v(200,2,170)}
local spawn={Position=v(245,0,0),Size=v(12,1,12)}
local points={v(215,0,-60),v(265,0,-60),v(265,0,-20),v(335,0,-20),v(335,0,25),v(270,0,25),v(270,0,60),v(385,0,60)}
local function check(label,point,expected,footprint)
 local ok,reason=Placement.valid(point,arena,points,spawn,footprint)
 assert(ok==expected,label..": unexpected "..tostring(ok).." "..reason); print("OK",label)
end
check("free grass",v(230,0,-40),true)
check("road horizontal",v(230,0,-60),false)
check("road vertical",v(265,0,-40),false)
check("square corner",v(272,0,-53),false)
check("outside road border",v(230,0,-52.9),true)
check("spawn",v(245,0,0),false)
check("next to spawn",v(252,0,0),true)
check("arena exact edge",v(200,0,0),true)
check("outside arena",v(199.9,0,0),false)
check("footprint leaves arena",v(202,0,0),false,Vector2.new(3,2))
check("footprint inside arena",v(204,0,0),true,Vector2.new(3,2))
check("wrong height",v(230,20,-40),false)
check("NaN",v(0/0,0,0),false)
'''
source = (root / 'src/ReplicatedStorage/Placement.luau').read_text(encoding='utf-8')
assert source.rstrip().endswith('return Placement')
source = source.rsplit('return Placement', 1)[0]
with tempfile.TemporaryDirectory() as tmp:
    test = pathlib.Path(tmp) / 'placement_test.luau'
    test.write_text(prefix + source + suffix, encoding='utf-8')
    subprocess.run([sys.argv[1], str(test)], check=True)
