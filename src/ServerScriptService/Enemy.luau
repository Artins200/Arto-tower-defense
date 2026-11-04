--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Config=require(ReplicatedStorage.Config)
local Enemy={}; Enemy.__index=Enemy
local function block(model,name,size,pos,color)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=CFrame.new(pos); p.Color=color; p.Material=Enum.Material.SmoothPlastic; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.Parent=model; return p
end
local function build(kind, templates)
 local info=Config.Enemies[kind]; local m=Instance.new("Model"); m.Name=kind
 local c=info.color; local dark=Color3.fromRGB(52,61,61); local patch=Color3.fromRGB(88,105,91); local bone=Color3.fromRGB(200,207,187)
 local root=block(m,"Root",Vector3.new(3.4,2.7,4.3),Vector3.new(0,2.5,0),c); m.PrimaryPart=root
 block(m,"Head",Vector3.new(3.4,3,3),Vector3.new(0,4,-2.3),c)
 block(m,"Mask",Vector3.new(3.42,1.2,0.12),Vector3.new(0,4.2,-3.83),dark)
 for _,x in {-0.9,0.9} do
  block(m,"Eye",Vector3.new(.35,.48,.15),Vector3.new(x,4.3,-3.91),Color3.fromRGB(255,91,75))
  for _,z in {-1.3,1.3} do block(m,"Leg",Vector3.new(.8,1.6,.85),Vector3.new(x,0.8,z),dark) end
 end
 block(m,"Muzzle",Vector3.new(1.3,.8,.55),Vector3.new(0,3.5,-4),bone)
 block(m,"Nose",Vector3.new(.5,.3,.12),Vector3.new(0,3.7,-4.31),dark)
 -- Геометрия и детали отличаются у каждого животного, но все сохраняют кубический стиль референса.
 local earH=kind=="Rabbit" and 2.7 or (kind=="Bear" and .65 or 1.2)
 for _,x in {-1.15,1.15} do block(m,"Ear",Vector3.new(.75,earH,.65),Vector3.new(x,5.45+earH/2,-2.2),c) end
 if kind=="Dog" then for _,x in {-1.8,1.8} do block(m,"FloppyEar",Vector3.new(.55,1.5,.8),Vector3.new(x,4,-2.2),patch) end end
 if kind=="Cat" then block(m,"Tail",Vector3.new(.55,.55,3),Vector3.new(0,3,3),c) end
 if kind=="Rabbit" then block(m,"Tail",Vector3.new(.8,.8,.8),Vector3.new(0,2.8,2.5),bone) end
 if kind=="Bear" then block(m,"Brow",Vector3.new(2.4,.35,.2),Vector3.new(0,4.9,-3.9),patch) end
 if kind=="Raccoon" then
  for i=1,3 do block(m,"RingTail",Vector3.new(1,1,1),Vector3.new(0,2.7,2+i),i%2==0 and dark or c) end
  block(m,"Crown",Vector3.new(2,.5,1),Vector3.new(0,5.75,-2.2),Color3.fromRGB(211,177,81))
 end
 for _,side in {-1,1} do for i=1,3 do block(m,"ZombiePatch",Vector3.new(.08,.35,.5),Vector3.new(side*1.72,2+i*.48,(i-2)*1.1),patch) end end
 m.Parent=templates; return m
end
function Enemy.prepare(templates)
 for kind in pairs(Config.Enemies) do build(kind,templates) end
end
function Enemy.new(kind, difficulty, coords, templates, onDeath, onEscape)
 local config=Config.Enemies[kind]; local model=templates:FindFirstChild(kind):Clone(); model.Parent=workspace.Enemies
 local hp=math.floor(config.hp*difficulty.hp)
 local self=setmetatable({kind=kind,model=model,hp=hp,maxHp=hp,speed=config.speed*difficulty.speed,coords=coords,segment=1,distance=0,progress=0,slowFactor=1,slowUntil=0,alive=true,onDeath=onDeath,onEscape=onEscape},Enemy)
 model:SetAttribute("EnemyKind",kind); model:SetAttribute("HP",hp); model:SetAttribute("MaxHP",hp)
 -- Сохраняем локальные положения лап: каждая двигается относительно корпуса.
 self.legs={}; self.walkTime=0
 for _,p in model:GetChildren() do
  if p:IsA("BasePart") and p.Name=="Leg" then
   local relative=model.PrimaryPart.CFrame:ToObjectSpace(p.CFrame)
   table.insert(self.legs,{part=p,offset=relative,phase=relative.Position.X*relative.Position.Z>0 and 0 or math.pi})
  end
 end
 local gui=Instance.new("BillboardGui"); gui.Name="Health"; gui.Size=UDim2.fromOffset(76,30); gui.StudsOffset=Vector3.new(0,5.5,0); gui.AlwaysOnTop=true; gui.Parent=model.PrimaryPart
 local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,16); title.BackgroundTransparency=1; title.Text=config.name; title.TextColor3=Color3.new(1,1,1); title.TextStrokeTransparency=.4; title.Font=Enum.Font.GothamBold; title.TextScaled=true; title.Parent=gui
 local back=Instance.new("Frame"); back.Position=UDim2.new(0,0,0,18); back.Size=UDim2.new(1,0,0,6); back.BackgroundColor3=Color3.fromRGB(37,42,46); back.BorderSizePixel=0; back.Parent=gui
 local fill=Instance.new("Frame"); fill.Size=UDim2.fromScale(1,1); fill.BorderSizePixel=0; fill.BackgroundColor3=Color3.fromRGB(124,235,146); fill.Parent=back; self.fill=fill
 model:PivotTo(CFrame.lookAt(coords[1]+Vector3.new(0,2.5,0),coords[2]+Vector3.new(0,2.5,0)))
 return self
end
function Enemy:effect(amount)
 local root=self.model.PrimaryPart; if not root then return end
 local emitter=Instance.new("ParticleEmitter"); emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"; emitter.Rate=0; emitter.Lifetime=NumberRange.new(.25,.45); emitter.Speed=NumberRange.new(3,7); emitter.Color=ColorSequence.new(Color3.fromRGB(174,255,153)); emitter.Parent=root; emitter:Emit(self.hp<=0 and 18 or 5); Debris:AddItem(emitter,1)
 local gui=Instance.new("BillboardGui"); gui.Size=UDim2.fromOffset(80,35); gui.StudsOffset=Vector3.new(0,5,0); gui.AlwaysOnTop=true; gui.Parent=root
 local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Text="-"..math.floor(amount); t.TextColor3=Color3.fromRGB(255,224,121); t.TextStrokeTransparency=.25; t.TextScaled=true; t.Font=Enum.Font.GothamBold; t.Parent=gui
 TweenService:Create(gui,TweenInfo.new(.6),{StudsOffset=Vector3.new(0,7,0)}):Play(); TweenService:Create(t,TweenInfo.new(.6),{TextTransparency=1,TextStrokeTransparency=1}):Play(); Debris:AddItem(gui,.7)
end
function Enemy:hit(damage, slow, duration)
 if not self.alive then return end
 self.hp=math.max(0,self.hp-damage); self.model:SetAttribute("HP",self.hp); self.fill.Size=UDim2.fromScale(self.hp/self.maxHp,1); self:effect(damage)
 -- Замедления не перемножаются: сильнейшее обновляет длительность, слабее не заменяет его.
 if slow and (os.clock()>=self.slowUntil or slow<=self.slowFactor) then self.slowFactor=slow; self.slowUntil=os.clock()+duration end
 if self.hp<=0 then self.alive=false; self.onDeath(self); local model=self.model; task.delay(.35,function() model:Destroy() end) end
end
-- Ульта льда останавливает движение, а оболочка следует за моделью через PivotTo.
function Enemy:freeze(duration)
 if not self.alive then return end
 self.slowFactor=0; self.slowUntil=math.max(self.slowUntil,os.clock()+duration)
 if not self.model:FindFirstChild("IcePrison") and self.model.PrimaryPart then
  local ice=Instance.new("Part"); ice.Name="IcePrison"; ice.Size=Vector3.new(5,6,7); ice.CFrame=self.model.PrimaryPart.CFrame; ice.Anchored=true; ice.CanCollide=false; ice.CanTouch=false; ice.CanQuery=false; ice.Material=Enum.Material.Ice; ice.Color=Color3.fromRGB(130,224,255); ice.Transparency=.55; ice.Parent=self.model
 end
end
-- Бanish засчитывается как устранение, но противник ненадолго появляется за картой.
function Enemy:banish(destination)
 if not self.alive then return end
 self.alive=false; self.model:PivotTo(CFrame.new(destination)); self.onDeath(self)
 local model=self.model; task.delay(1.5,function() model:Destroy() end)
end
function Enemy:update(dt)
 if not self.alive then return end
 if os.clock()>=self.slowUntil then local ice=self.model:FindFirstChild("IcePrison"); if ice then ice:Destroy() end end
 local factor=os.clock()<self.slowUntil and self.slowFactor or 1
 self.walkTime+=dt*factor
 local remaining=self.speed*factor*dt
 while remaining>0 and self.segment<#self.coords do
  local a=self.coords[self.segment]; local b=self.coords[self.segment+1]; local length=(b-a).Magnitude; local step=math.min(remaining,length-self.distance)
  self.distance+=step; self.progress+=step; remaining-=step
  local bob=math.abs(math.sin(self.walkTime*8))*0.12
  local pos=a:Lerp(b,self.distance/length)+Vector3.new(0,2.5+bob,0); self.model:PivotTo(CFrame.lookAt(pos,pos+(b-a)))
  local root=self.model.PrimaryPart
  if root then for _,leg in ipairs(self.legs) do leg.part.CFrame=root.CFrame*leg.offset*CFrame.Angles(math.sin(self.walkTime*8+leg.phase)*.5,0,0) end end
  if self.distance>=length-0.001 then self.segment+=1; self.distance=0 end
 end
 if self.segment>=#self.coords then self.alive=false; self.onEscape(self); self.model:Destroy() end
end
return Enemy
