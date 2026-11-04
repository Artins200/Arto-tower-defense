--!strict
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local MapBuilder = {}
local function part(parent, name, size, position, color, material)
 local p = Instance.new("Part"); p.Name=name; p.Size=size; p.Position=position; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent; return p
end
local function label(part0, text, color)
 local gui=Instance.new("BillboardGui"); gui.Size=UDim2.fromOffset(250,55); gui.StudsOffset=Vector3.new(0,5,0); gui.AlwaysOnTop=true; gui.Parent=part0
 local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Text=text; t.TextColor3=color or Color3.new(1,1,1); t.TextStrokeTransparency=0.4; t.TextScaled=true; t.Font=Enum.Font.GothamBold; t.Parent=gui
end
function MapBuilder.build()
 -- Исходные риги из Place13 храним в ServerStorage, а не уничтожаем.
 local originals=Instance.new("Folder"); originals.Name="Place13Originals"; originals.Parent=ServerStorage
 for _, child in workspace:GetChildren() do
  if child:IsA("Model") and (child.Name=="dibil1488777" or child:FindFirstChildOfClass("Humanoid")) then child.Parent=originals end
  if child:IsA("SpawnLocation") then child:Destroy() end
  if child.Name=="Baseplate" and child:IsA("BasePart") then child:Destroy() end
 end
 local templates=Instance.new("Folder"); templates.Name="Templates"; templates.Parent=ServerStorage
 for _, n in {"Towers","Enemies","Projectiles"} do local f=Instance.new("Folder"); f.Name=n; f.Parent=templates end
 local projectile=part(templates.Projectiles,"Projectile",Vector3.new(.8,.8,.8),Vector3.zero,Color3.new(1,1,1),Enum.Material.Neon); projectile.Shape=Enum.PartType.Ball; projectile.CanCollide=false; projectile.CanQuery=false
 -- Звуки — заглушки: замените SoundId на свои разрешённые Roblox-ассеты.
 for _,name in {"HitSound","DeathSound"} do local sound=Instance.new("Sound"); sound.Name=name; sound.SoundId=""; sound.Parent=templates.Projectiles end
 local original=originals:FindFirstChild("dibil1488777")
 if original then local copy=original:Clone(); copy.Name="StarterUnit"; copy.Parent=templates.Towers end
 local root=Instance.new("Folder"); root.Name="TDMap"; root.Parent=workspace
 for _,n in {"Towers","Enemies","Waypoints","Plots"} do local f=Instance.new("Folder"); f.Name=n; f.Parent=workspace end
 local lobby=part(root,"Lobby",Vector3.new(110,2,110),Vector3.new(0,-1,0),Color3.fromRGB(38,52,66),Enum.Material.Slate)
 local spawn=Instance.new("SpawnLocation"); spawn.Name="LobbySpawn"; spawn.Size=Vector3.new(12,1,12); spawn.Position=Vector3.new(0,0.5,20); spawn.Anchored=true; spawn.Neutral=true; spawn.Color=Color3.fromRGB(107,225,210); spawn.Material=Enum.Material.Neon; spawn.Parent=root
 local portal=part(root,"Portal",Vector3.new(14,18,2),Vector3.new(0,9,-38),Color3.fromRGB(112,91,235),Enum.Material.Neon); portal.CanCollide=false; portal.Transparency=0.3; label(portal,"ПОРТАЛ  •  В БОЙ")
 local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Войти"; prompt.ObjectText="Портал испытаний"; prompt.HoldDuration=0; prompt.MaxActivationDistance=15; prompt.Parent=portal
 local sign=part(root,"SpinSign",Vector3.new(14,9,2),Vector3.new(-28,5,-12),Color3.fromRGB(245,170,71),Enum.Material.Neon); sign.CanCollide=false; label(sign,"ПРИЗЫВ  •  ОТКРОЙ ЮНИТОВ")
 local spin=Instance.new("ProximityPrompt"); spin.ActionText="Открыть призыв"; spin.ObjectText="Новые юниты"; spin.MaxActivationDistance=15; spin.Parent=sign
 part(root,"Arena",Vector3.new(200,2,170),Vector3.new(300,-1,0),Color3.fromRGB(64,100,80),Enum.Material.Grass)
 -- Маршрут от красного портала к кристаллу. Невидимые waypoint-маркеры — источник пути.
 local coords={Vector3.new(215,0,-60),Vector3.new(265,0,-60),Vector3.new(265,0,-20),Vector3.new(335,0,-20),Vector3.new(335,0,25),Vector3.new(270,0,25),Vector3.new(270,0,60),Vector3.new(385,0,60)}
 for i,pos in ipairs(coords) do
  local marker=part(workspace.Waypoints,string.format("%02d",i),Vector3.new(1,1,1),pos,Color3.new(1,1,1)); marker.Transparency=1; marker.CanCollide=false
  if i>1 then local prev=coords[i-1]; local mid=(pos+prev)/2; local d=(pos-prev).Magnitude; local road=part(root,"Road",Vector3.new(12,0.25,d+12),mid+Vector3.new(0,0.15,0),Color3.fromRGB(62,66,76),Enum.Material.Slate); road.CFrame=CFrame.lookAt(road.Position,Vector3.new(pos.X,road.Position.Y,pos.Z)); local stripe=part(root,"RoadStripe",Vector3.new(0.35,0.04,d),mid+Vector3.new(0,0.3,0),Color3.fromRGB(248,203,112),Enum.Material.Neon); stripe.CFrame=CFrame.lookAt(stripe.Position,Vector3.new(pos.X,stripe.Position.Y,pos.Z)); stripe.CanCollide=false end
 end
 local entry=part(root,"EnemyGate",Vector3.new(4,12,16),coords[1]+Vector3.new(0,6,0),Color3.fromRGB(242,88,101),Enum.Material.Neon); entry.CanCollide=false; label(entry,"ВХОД ВРАГОВ")
 local base=part(workspace,"Base",Vector3.new(8,10,8),coords[#coords]+Vector3.new(0,5,0),Color3.fromRGB(110,231,224),Enum.Material.Neon); base.Shape=Enum.PartType.Ball; base.CanCollide=false; label(base,"ЗАЩИТИ КРИСТАЛЛ")
 -- Слоты заранее отстоят от дорожки: сервер проверяет только их, а не координаты клиента.
 local spots={{225,-43},{245,-43},{280,-45},{250,-6},{280,-6},{305,-35},{320,-6},{350,-6},{350,12},{320,10},{300,10},{255,12},{255,43},{285,43},{305,43},{325,43},{345,43},{365,43},{375,73},{290,73},{235,-73},{300,-70},{350,-35},{240,60}}
 for i,xy in ipairs(spots) do local p=part(workspace.Plots,"Plot"..i,Vector3.new(8,0.5,8),Vector3.new(xy[1],0.25,xy[2]),Color3.fromRGB(107,173,139),Enum.Material.SmoothPlastic); p:SetAttribute("Occupied",false) end
 for i=1,24 do local angle=i*math.pi*2/24; local x=300+91*math.cos(angle); local z=75*math.sin(angle); local trunk=part(root,"TreeTrunk",Vector3.new(2,6,2),Vector3.new(x,3,z),Color3.fromRGB(79,67,53),Enum.Material.Wood); local crown=part(root,"TreeCrown",Vector3.new(8,8,8),Vector3.new(x,9,z),Color3.fromRGB(38,83,62),Enum.Material.Grass); crown.Shape=Enum.PartType.Ball end
 Lighting.ClockTime=14; Lighting.Brightness=2; Lighting.Ambient=Color3.fromRGB(110,128,130)
 return {portal=prompt,spin=spin,arenaSpawn=CFrame.new(245,4,0), lobbySpawn=CFrame.new(0,4,20), coords=coords, templates=templates}
end
return MapBuilder
