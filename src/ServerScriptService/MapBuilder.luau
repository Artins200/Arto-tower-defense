--!strict
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local MapBuilder={}
local palette={ground=Color3.fromRGB(57,91,72), deep=Color3.fromRGB(25,44,42), stone=Color3.fromRGB(62,74,77), road=Color3.fromRGB(117,111,93), trim=Color3.fromRGB(42,52,54), gold=Color3.fromRGB(249,200,112), mint=Color3.fromRGB(102,231,203), purple=Color3.fromRGB(154,110,255)}
local function part(parent,name,size,position,color,material)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Position=position; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent; return p
end
local function decor(parent,name,size,position,color,material)
 local p=part(parent,name,size,position,color,material); p.CanCollide=false; p.CanQuery=false; return p
end
local function label(part0,title,sub,color)
 local gui=Instance.new("BillboardGui"); gui.Size=UDim2.fromOffset(260,65); gui.StudsOffset=Vector3.new(0,5,0); gui.AlwaysOnTop=true; gui.Parent=part0
 local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Text=title.."\n"..sub; t.TextColor3=color or Color3.new(1,1,1); t.TextStrokeTransparency=.3; t.TextScaled=true; t.Font=Enum.Font.GothamBold; t.Parent=gui
end
local function tree(root,x,z,scale)
 decor(root,"Trunk",Vector3.new(2,6,2)*scale,Vector3.new(x,3*scale,z),Color3.fromRGB(70,60,54),Enum.Material.Wood)
 for i=1,3 do local s=(9-i*1.5)*scale; local crown=decor(root,"Pine",Vector3.new(s,4*scale,s),Vector3.new(x,(4+i*2.4)*scale,z),i%2==0 and Color3.fromRGB(35,80,64) or Color3.fromRGB(42,99,71)); crown.Shape=Enum.PartType.Ball end
end
function MapBuilder.build()
 -- Исходные риги Place13 не уничтожаются; предпросмотр — отдельная безопасная копия.
 local originals=Instance.new("Folder"); originals.Name="Place13Originals"; originals.Parent=ServerStorage
 for _,child in workspace:GetChildren() do
  if child:IsA("Model") and (child.Name=="dibil1488777" or child:FindFirstChildOfClass("Humanoid")) then child.Parent=originals end
  if child:IsA("SpawnLocation") then child:Destroy() end
  if child.Name=="Baseplate" and child:IsA("BasePart") then child:Destroy() end
 end
 local templates=Instance.new("Folder"); templates.Name="Templates"; templates.Parent=ServerStorage
 for _,n in {"Towers","Enemies","Projectiles"} do local f=Instance.new("Folder"); f.Name=n; f.Parent=templates end
 local projectile=part(templates.Projectiles,"Projectile",Vector3.new(.8,.8,.8),Vector3.zero,Color3.new(1,1,1),Enum.Material.Neon); projectile.Shape=Enum.PartType.Ball; projectile.CanCollide=false; projectile.CanQuery=false
 for _,name in {"HitSound","DeathSound"} do local sound=Instance.new("Sound"); sound.Name=name; sound.SoundId=""; sound.Parent=templates.Projectiles end
 local original=originals:FindFirstChild("dibil1488777")
 if original then
  local copy=original:Clone(); copy.Name="StarterUnit"; copy.Parent=templates.Towers
  local preview=copy:Clone(); preview.Name="StarterPreview"
  for _,d in preview:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=false elseif d:IsA("Humanoid") then d.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end end
  preview.Parent=ReplicatedStorage
 end
 local root=Instance.new("Folder"); root.Name="TDMap"; root.Parent=workspace
 for _,n in {"Towers","Enemies","Waypoints"} do local f=Instance.new("Folder"); f.Name=n; f.Parent=workspace end
 -- Лобби: широкая центральная площадь, обрамлённый портал и отдельная зона призыва.
 part(root,"Lobby",Vector3.new(110,2,110),Vector3.new(0,-1,0),palette.deep,Enum.Material.Slate)
 decor(root,"LobbyInlay",Vector3.new(82,.15,82),Vector3.new(0,.04,0),Color3.fromRGB(38,59,58),Enum.Material.Slate)
 for _,x in {-48,48} do decor(root,"LobbyBorder",Vector3.new(1,.2,98),Vector3.new(x,.15,0),palette.mint,Enum.Material.Neon) end
 local spawn=Instance.new("SpawnLocation"); spawn.Name="LobbySpawn"; spawn.Size=Vector3.new(12,1,12); spawn.Position=Vector3.new(0,.5,25); spawn.Anchored=true; spawn.Neutral=true; spawn.Color=palette.mint; spawn.Material=Enum.Material.Neon; spawn.Parent=root
 decor(root,"PortalStep",Vector3.new(24,1,12),Vector3.new(0,.5,-35),palette.stone,Enum.Material.Slate)
 for _,x in {-9,9} do decor(root,"PortalPillar",Vector3.new(3,22,4),Vector3.new(x,11,-39),palette.trim,Enum.Material.Slate); decor(root,"PortalLight",Vector3.new(.5,16,4.2),Vector3.new(x,11,-39),palette.purple,Enum.Material.Neon) end
 decor(root,"PortalArch",Vector3.new(21,3,4),Vector3.new(0,22,-39),palette.trim,Enum.Material.Slate)
 local portal=part(root,"Portal",Vector3.new(15,18,2),Vector3.new(0,10,-39),palette.purple,Enum.Material.Neon); portal.CanCollide=false; portal.Transparency=.35; label(portal,"ПОРТАЛ","ВЫБЕРИ ИСПЫТАНИЕ")
 local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Войти"; prompt.ObjectText="Портал испытаний"; prompt.HoldDuration=0; prompt.MaxActivationDistance=15; prompt.Parent=portal
 decor(root,"SummonPedestal",Vector3.new(20,2,16),Vector3.new(-30,1,-10),palette.stone,Enum.Material.Slate)
 local sign=part(root,"SpinSign",Vector3.new(10,9,2),Vector3.new(-30,7,-14),palette.gold,Enum.Material.Neon); sign.CanCollide=false; label(sign,"ПРИЗЫВ","ОТКРОЙ ЮНИТОВ")
 local spin=Instance.new("ProximityPrompt"); spin.ActionText="Открыть призыв"; spin.ObjectText="Новые юниты"; spin.MaxActivationDistance=15; spin.Parent=sign
 for _,x in {-42,42} do for _,z in {-38,38} do tree(root,x,z,.8) end end
 -- Арена — остров с рамкой и лесом по краям; центральная поверхность остаётся свободной для постройки.
 local arena=part(root,"Arena",Vector3.new(200,2,170),Vector3.new(300,-1,0),palette.ground,Enum.Material.Grass)
 decor(root,"IslandBase",Vector3.new(208,7,178),Vector3.new(300,-5,0),palette.deep,Enum.Material.Slate)
 for _,z in {-85,85} do decor(root,"ArenaRim",Vector3.new(204,1,2),Vector3.new(300,.2,z),palette.stone,Enum.Material.Slate) end
 for _,x in {200,400} do decor(root,"ArenaRim",Vector3.new(2,1,170),Vector3.new(x,.2,0),palette.stone,Enum.Material.Slate) end
 -- Направление дороги видно по золотым шевронам. Путь и зоны запрета используют одинаковые waypoint.
 local coords={Vector3.new(215,0,-60),Vector3.new(265,0,-60),Vector3.new(265,0,-20),Vector3.new(335,0,-20),Vector3.new(335,0,25),Vector3.new(270,0,25),Vector3.new(270,0,60),Vector3.new(385,0,60)}
 for i,pos in ipairs(coords) do
  local marker=part(workspace.Waypoints,string.format("%02d",i),Vector3.new(1,1,1),pos,Color3.new(1,1,1)); marker.Transparency=1; marker.CanCollide=false; marker.CanQuery=false
  if i>1 then
   local prev=coords[i-1]; local delta=pos-prev; local distance=delta.Magnitude; local mid=(pos+prev)/2
   local border=decor(root,"RoadBorder",Vector3.new(14,.18,distance+14),mid+Vector3.new(0,.09,0),palette.trim,Enum.Material.Slate); border.CFrame=CFrame.lookAt(border.Position,Vector3.new(pos.X,border.Position.Y,pos.Z))
   local road=decor(root,"Road",Vector3.new(12,.18,distance+12),mid+Vector3.new(0,.2,0),palette.road,Enum.Material.Slate); road.CFrame=CFrame.lookAt(road.Position,Vector3.new(pos.X,road.Position.Y,pos.Z))
   for step=10,distance-4,18 do
    local at=prev+delta.Unit*step+Vector3.new(0,.31,0); local facing=CFrame.lookAt(at,at+delta.Unit)
    for _,side in {-1,1} do local arrow=decor(root,"Direction",Vector3.new(.35,.06,2.5),at,palette.gold,Enum.Material.Neon); arrow.CFrame=facing*CFrame.new(side*.8,0,0)*CFrame.Angles(0,side*math.rad(45),0) end
   end
  end
 end
 -- Вход и база — узнаваемые ориентиры, которые не перекрывают игровую поверхность.
 local entrance=coords[1]
 for _,z in {-8,8} do decor(root,"GatePillar",Vector3.new(4,15,3),entrance+Vector3.new(0,7.5,z),palette.trim,Enum.Material.Slate) end
 decor(root,"GateArch",Vector3.new(4,3,19),entrance+Vector3.new(0,16,0),palette.trim,Enum.Material.Slate)
 local gate=decor(root,"EnemyGate",Vector3.new(1,13,13),entrance+Vector3.new(0,7,0),Color3.fromRGB(255,93,99),Enum.Material.Neon); gate.Transparency=.4; label(gate,"ВХОД","ВРАГИ ИДУТ ОТСЮДА")
 local endPos=coords[#coords]
 decor(root,"BasePedestal",Vector3.new(14,1,14),endPos+Vector3.new(0,.5,0),palette.stone,Enum.Material.Slate)
 local base=part(workspace,"Base",Vector3.new(7,10,7),endPos+Vector3.new(0,6,0),palette.mint,Enum.Material.Neon); base.Shape=Enum.PartType.Ball; base.CanCollide=false; base.CanQuery=false; label(base,"БАЗА","ЗАЩИТИ КРИСТАЛЛ")
 for i=0,10 do local x=205+i*19; tree(root,x,-92,.7+(i%3)*.13); tree(root,x,92,.75+((i+1)%3)*.13) end
 for i=0,7 do local z=-75+i*21; tree(root,193,z,.8+(i%2)*.14); tree(root,407,z,.8+((i+1)%2)*.14) end
 Lighting.ClockTime=15.5; Lighting.Brightness=2; Lighting.Ambient=Color3.fromRGB(122,141,137); Lighting.OutdoorAmbient=Color3.fromRGB(140,158,148)
 return {portal=prompt,spin=spin,arena=arena,arenaSpawn=CFrame.new(245,4,0),lobbySpawn=CFrame.new(0,4,25),coords=coords,templates=templates}
end
return MapBuilder
