#!/usr/bin/env python3
"""Run the real Placement module against a minimal Vector2 stub (no Roblox Studio needed).
Usage: python tests/test_placement.py /path/to/luau
"""
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) != 2:
    raise SystemExit("Provide the path to the Luau CLI")
prefix = 'local Vector2 = {}\nlocal mt = {}\nmt.__index=function(t,k) if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y) elseif k=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y end end end\nmt.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end\nmt.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end\nmt.__mul=function(a,b) return Vector2.new(a.X*b,a.Y*b) end\nfunction Vector2.new(x,y) return setmetatable({X=x,Y=y},mt) end\nlocal function v(x,y,z) return {X=x,Y=y,Z=z} end\n'
suffix = 'local arena={Position=v(300,-1,0),Size=v(200,2,170)}\nlocal points={v(215,0,-60),v(265,0,-60),v(265,0,-20),v(335,0,-20),v(335,0,25),v(270,0,25),v(270,0,60),v(385,0,60)}\nlocal function check(label,point,towers,expected)\n local ok,reason=Placement.valid(point,arena,points,towers)\n assert(ok==expected,label..": unexpected "..tostring(ok).." "..reason)\n print("OK",label)\nend\ncheck("free grass",v(230,0,-40),{},true)\ncheck("road horizontal",v(230,0,-60),{},false)\ncheck("road vertical",v(265,0,-40),{},false)\ncheck("road corner",v(272,0,-53),{},false)\ncheck("road margin",v(230,0,-51),{},false)\ncheck("outside island",v(198,0,0),{},false)\ncheck("wrong height",v(230,20,-40),{},false)\ncheck("other unit",v(230,0,-40),{v(234,0,-40)},false)\ncheck("unit spacing",v(230,0,-40),{v(238,0,-40)},true)\ncheck("NaN",v(0/0,0,0),{},false)\n'
source = (root / "src/ReplicatedStorage/Placement.luau").read_text(encoding="utf-8")
assert source.rstrip().endswith("return Placement")
source = source.rsplit("return Placement", 1)[0]
with tempfile.TemporaryDirectory() as tmp:
    test = pathlib.Path(tmp) / "placement_test.luau"
    test.write_text(prefix + source + suffix, encoding="utf-8")
    subprocess.run([sys.argv[1], str(test)], check=True)
