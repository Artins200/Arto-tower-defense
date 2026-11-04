#!/usr/bin/env python3
"""Exercise the actual server ultimate state machine with fake enemies and vectors.
Usage: python tests/test_ultimate_flow.py /path/to/luau
"""
import pathlib, subprocess, sys, tempfile
if len(sys.argv) != 2:
    raise SystemExit('Provide the path to the Luau CLI')
root = pathlib.Path(__file__).resolve().parent.parent
source = (root / 'src/ServerScriptService/Game.server.luau').read_text(encoding='utf-8')
start = source.index('local function updateUltimate(dt)')
end = source.index('connections[#connections+1]=RunService.Heartbeat:Connect', start)
function = source[start:end]
prefix = '''
local Vector3={}; local vector={}
vector.__index=function(t,k) if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end end
vector.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end
local Config={UltimateIntro=3,SniperUltimateEnd=12,stats=function(kind,level) return {damage=10,range=30} end}
local Rules={sniperSplit=function(n) return math.max(0,math.floor((n-1)/2)) end}
local events={}; local function teamFx(...) table.insert(events,{...}) end
local function teamMessage(...) end
local towers={}; local enemies={}; local groups={{},{}}; local groupIndex=1; local spawnRemaining=3; local forceNextWave=false; local ultimate=nil
local function endUltimate() if ultimate then ultimate.tower.suppressed=false end; ultimate=nil end
local function enemy(x,hp,progress)
 local e={alive=true,hp=hp,progress=progress,model={PrimaryPart={Position=Vector3.new(x,4,0)}}}
 function e:hit(damage) self.hp=math.max(0,self.hp-damage); if self.hp==0 then self.alive=false end end
 function e:freeze(duration) if self.alive then self.frozen=duration end end
 function e:banish(destination) self.alive=false; self.destination=destination end
 return e
end
local function tower(kind)
 local model={Parent=true}; local t={kind=kind,position=Vector3.new(0,0,0),level=1,model=model,suppressed=true}; towers[model]=t; return t
end
'''
tests = '''
-- Вступление, лазер, телепорт, бан и отмена очереди только после конца сцены.
local s=tower("Sniper"); enemies={enemy(1,100,4),enemy(2,100,3),enemy(3,100,2),enemy(4,100,1)}
ultimate={kind="Sniper",tower=s,targets=enemies,elapsed=0,done={},beamTimer=0}
assert(updateUltimate(2.9) and enemies[1].alive and groupIndex==1)
assert(updateUltimate(2.1) and not enemies[1].alive and enemies[2].alive and groupIndex==1)
assert(updateUltimate(3) and not enemies[2].alive and enemies[2].destination.Z==-300 and not enemies[3].alive and enemies[4].alive)
assert(updateUltimate(3) and not enemies[4].alive and groupIndex==1)
assert(updateUltimate(1) and ultimate==nil and groupIndex==3 and spawnRemaining==0 and forceNextWave and not s.suppressed)
-- При удалении башни сцена прекращается без пропуска очереди.
groupIndex=1; spawnRemaining=3; forceNextWave=false
local removed=tower("Sniper"); ultimate={kind="Sniper",tower=removed,targets={},elapsed=1,done={},beamTimer=0}; towers[removed.model]=nil
assert(not updateUltimate(.1) and ultimate==nil and groupIndex==1 and spawnRemaining==3)
-- Лёд замораживает только живых врагов в радиусе; пушка наносит AoE.
local ice=tower("Ice"); local near=enemy(5,100,1); local far=enemy(50,100,0); enemies={near,far}; ultimate={kind="Ice",tower=ice,targets=enemies,elapsed=0,done={},beamTimer=0}
assert(updateUltimate(2.9) and near.hp==100); assert(not updateUltimate(.1) and near.hp==70 and near.frozen==8 and far.hp==100 and ultimate==nil)
local cannon=tower("Cannon"); near=enemy(5,500,2); far=enemy(50,500,0); enemies={near,far}; ultimate={kind="Cannon",tower=cannon,targets=enemies,elapsed=0,done={},beamTimer=0}
assert(not updateUltimate(3) and near.hp==380 and far.hp==500 and ultimate==nil)
-- Непрерывный луч работает во время ульты, после чего башня освобождается.
local shooter=tower("Shooter"); near=enemy(5,100,1); enemies={near}; ultimate={kind="Shooter",tower=shooter,targets=enemies,elapsed=0,done={},beamTimer=0}
assert(not updateUltimate(3) and near.hp==94 and ultimate~=nil)
assert(not updateUltimate(.15) and near.hp==88)
assert(not updateUltimate(6) and ultimate==nil and not shooter.suppressed)
print("OK: sniper phases, abort, freeze, AoE and sustained beam")
'''
with tempfile.TemporaryDirectory() as tmp:
    path = pathlib.Path(tmp) / 'ultimate_test.luau'
    path.write_text(prefix + function + tests, encoding='utf-8')
    subprocess.run([sys.argv[1], str(path)], check=True)
