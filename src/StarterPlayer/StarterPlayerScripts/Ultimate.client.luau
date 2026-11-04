--!strict
-- Кат-сцена и эффекты воспроизводятся локально. Никакой урон и телепорт врагов здесь не рассчитываются.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local fx=ReplicatedStorage:WaitForChild("TDFx")
local config=require(ReplicatedStorage:WaitForChild("Config"))
local Rules=require(ReplicatedStorage:WaitForChild("CombatRules"))
local previews=ReplicatedStorage:WaitForChild("UnitPreviews")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui"); gui.Name="UltimateCinematic"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=100; gui.Enabled=false; gui.Parent=player:WaitForChild("PlayerGui")
local shade=Instance.new("Frame"); shade.Size=UDim2.fromScale(1,1); shade.BackgroundColor3=Color3.fromRGB(5,8,17); shade.BackgroundTransparency=.22; shade.BorderSizePixel=0; shade.Parent=gui
local viewport=Instance.new("ViewportFrame"); viewport.Size=UDim2.fromScale(.45,.62); viewport.Position=UDim2.fromScale(.275,.08); viewport.BackgroundTransparency=1; viewport.Ambient=Color3.fromRGB(210,210,230); viewport.LightColor=Color3.new(1,1,1); viewport.Parent=gui
local caption=Instance.new("TextLabel"); caption.Size=UDim2.new(.8,0,0,76); caption.Position=UDim2.new(.1,0,.73,0); caption.BackgroundTransparency=1; caption.TextColor3=Color3.new(1,1,1); caption.TextStrokeTransparency=.15; caption.TextScaled=true; caption.TextWrapped=true; caption.Font=Enum.Font.GothamBold; caption.Parent=gui
local title=Instance.new("TextLabel"); title.Size=UDim2.new(.8,0,0,35); title.Position=UDim2.new(.1,0,.07,0); title.BackgroundTransparency=1; title.TextColor3=Color3.fromRGB(255,220,135); title.TextScaled=true; title.Font=Enum.Font.GothamBlack; title.Text="ULTIMATE"; title.Parent=gui
local console=Instance.new("TextLabel"); console.Size=UDim2.fromOffset(380,56); console.Position=UDim2.new(.5,-190,.8,0); console.BackgroundColor3=Color3.fromRGB(15,18,28); console.BackgroundTransparency=.1; console.TextColor3=Color3.fromRGB(180,250,190); console.Font=Enum.Font.Code; console.TextScaled=true; console.Text=""; console.Visible=false; console.Parent=gui
local effects=Instance.new("Folder"); effects.Name="LocalUltimateFX"; effects.Parent=workspace
local colors={Shooter=Color3.fromRGB(255,207,84),Ice=Color3.fromRGB(142,235,255),Cannon=Color3.fromRGB(255,137,73),Sniper=Color3.fromRGB(195,128,255)}
local dialogue={Shooter="Смотри внимательно — сейчас будет жарко!",Ice="Замри! Ледяной луч не оставит шансов!",Cannon="Ядерка готова. Всем укрыться!",Sniper="Стой... я же разработчик. Я могу снести здесь всех!"}
local scene=nil; local connections={}
local function part(name,size,color)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.CastShadow=false; p.Material=Enum.Material.Neon; p.Color=color; p.Parent=effects; return p
end
local function line(a,b,color,width,duration)
 local length=(b-a).Magnitude; if length<.01 then return end
 local p=part("UltimateBeam",Vector3.new(width,width,length),color); p.CFrame=CFrame.lookAt((a+b)/2,b)
 TweenService:Create(p,TweenInfo.new(duration),{Transparency=1}):Play(); Debris:AddItem(p,duration+.1)
end
local function ring(pos,color,radius,duration)
 local p=part("UltimateRing",Vector3.new(.2,1,1),color); p.Shape=Enum.PartType.Cylinder; p.CFrame=CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2)
 TweenService:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(.2,radius*2,radius*2),Transparency=1}):Play(); Debris:AddItem(p,duration+.1)
end
local function resetScene()
 local old=scene; if not old then return end; scene=nil
 gui.Enabled=false; shade.Visible=true; viewport.Visible=true; console.Visible=false; caption.Text=""
 viewport:ClearAllChildren()
 if old.actor then old.actor:Destroy() end
 if old.hidden then for p,transparency in pairs(old.hidden) do if p.Parent then p.LocalTransparencyModifier=transparency end end end
 if old.grayscale then old.grayscale:Destroy() end
 if old.camera and workspace.CurrentCamera==old.camera then old.camera.CameraType=old.cameraType; if old.subject and old.subject.Parent then old.camera.CameraSubject=old.subject end end
end
local function poseData(model)
 local base=model:GetPivot(); local limbs={}
 for _,name in {"Left Arm","Right Arm","Left Leg","Right Leg"} do
  local p=model:FindFirstChild(name); if p and p:IsA("BasePart") then limbs[name]={part=p,offset=base:ToObjectSpace(p.CFrame)} end
 end
 return limbs
end
local function pose(model,limbs,pivot,time,walking)
 model:PivotTo(pivot)
 for name,limb in pairs(limbs) do if limb.part.Parent then
  local isArm=string.find(name,"Arm")~=nil; local left=string.find(name,"Left")~=nil
  local swing=walking and math.sin(time*9+(left and 0 or math.pi))*.5 or 0
  local angle=isArm and (-.8+math.sin(time*9+(left and 0 or 1))*.28+swing) or swing
  local half=limb.part.Size.Y/2
  limb.part.CFrame=pivot*limb.offset*CFrame.new(0,half,0)*CFrame.Angles(angle,0,(left and -.15 or .15))*CFrame.new(0,-half,0)
 end end
end
local function startScene(kind,tower,targets)
 resetScene(); if not colors[kind] or not tower or not tower:IsA("Model") or not tower.Parent then return end
 local template=previews:FindFirstChild(kind); if not template then return end
 local portrait=template:Clone(); portrait.Parent=viewport
 local cf,size=portrait:GetBoundingBox(); local camera=Instance.new("Camera"); camera.FieldOfView=32; camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(1,.5,-1.8)*math.max(size.X,size.Y,size.Z)*1.5,cf.Position); camera.Parent=viewport; viewport.CurrentCamera=camera
 local targetPositions={}; if typeof(targets)=="table" then for _,model in ipairs(targets) do if typeof(model)=="Vector3" then table.insert(targetPositions,model) end end end
 local cameraWorld=workspace.CurrentCamera
 scene={kind=kind,tower=tower,started=os.clock(),portrait=portrait,portraitPivot=portrait:GetPivot(),portraitLimbs=poseData(portrait),positions=targetPositions,camera=cameraWorld,cameraType=cameraWorld and cameraWorld.CameraType,subject=cameraWorld and cameraWorld.CameraSubject,hidden={}}
 caption.Text=dialogue[kind]; caption.TextColor3=colors[kind]; gui.Enabled=true; shade.Visible=true; viewport.Visible=true; title.Visible=true; console.Visible=false
end
local function startSniperWorld(s)
 if s.worldStarted or not s.tower.Parent then return end; s.worldStarted=true
 local grayscale=Instance.new("ColorCorrectionEffect"); grayscale.Name="FrozenTime"; grayscale.Saturation=-1; grayscale.Contrast=.2; grayscale.Parent=Lighting; s.grayscale=grayscale
 s.actor=s.tower:Clone(); s.actor.Name="UltimateActor"; s.actor.Parent=effects
 for _,p in s.actor:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false end end
 s.actorLimbs=poseData(s.actor); s.actorOrigin=s.actor:GetPivot().Position
 for _,p in s.tower:GetDescendants() do if p:IsA("BasePart") then s.hidden[p]=p.LocalTransparencyModifier; p.LocalTransparencyModifier=1 end end
 if s.camera then s.camera.CameraType=Enum.CameraType.Scriptable end
end
local function strike(kind,a,b)
 local color=colors[kind]; if not color then return end
 if kind=="Cannon" then
  line(a,b,color,1,.35); ring(b,color,28,1); ring(b,Color3.fromRGB(255,230,149),18,.65)
  local column=part("NuclearColumn",Vector3.new(3,3,3),color); column.Shape=Enum.PartType.Cylinder; column.CFrame=CFrame.new(b+Vector3.new(0,15,0))*CFrame.Angles(0,0,math.pi/2); column.Transparency=.2
  TweenService:Create(column,TweenInfo.new(1),{Size=Vector3.new(30,16,16),Transparency=1}):Play(); Debris:AddItem(column,1.2)
 elseif kind=="Ice" then ring(a,color,24,.7)
 elseif kind=="Sniper" then
  local origin=a; if scene and scene.actor and scene.actor.Parent then local arm=scene.actor:FindFirstChild("Right Arm"); if arm and arm:IsA("BasePart") then origin=arm.Position end end
  line(origin,b,color,1.2,.65); line(origin,b,Color3.new(1,1,1),.3,.5); ring(b,color,5,.7)
 end
end
connections[#connections+1]=fx.OnClientEvent:Connect(function(action,a,b,c)
 if action=="UltimateStart" then startScene(a,b,c)
 elseif action=="UltimateEnd" then resetScene()
 elseif action=="UltimateBeam" and colors[a] and typeof(b)=="Vector3" and typeof(c)=="Vector3" then line(b,c,colors[a],a=="Shooter" and 1.1 or .75,.22)
 elseif action=="UltimateStrike" and colors[a] and typeof(b)=="Vector3" and typeof(c)=="Vector3" then strike(a,b,c)
 elseif action=="UltimateBanish" and typeof(a)=="Vector3" and typeof(b)=="Vector3" then ring(a,colors.Sniper,5,.8); ring(b,colors.Sniper,6,.8); line(a,b,colors.Sniper,.2,.5) end
end)
connections[#connections+1]=RunService.RenderStepped:Connect(function()
 local s=scene; if not s then return end
 if not player:GetAttribute("InMatch") or not s.tower.Parent then resetScene(); return end
 local t=os.clock()-s.started
 if t<config.UltimateIntro then
  if s.portrait.Parent then pose(s.portrait,s.portraitLimbs,s.portraitPivot*CFrame.Angles(0,math.sin(t*3)*.16,0),t,false) end
  return
 end
 if s.kind~="Sniper" then resetScene(); return end
 startSniperWorld(s); if not s.actor or not s.actor.Parent then resetScene(); return end
 shade.Visible=false; viewport.Visible=false; title.Visible=false
 local positions=s.positions; local n=#positions; local split=Rules.sniperSplit(n); local at=s.actorOrigin; local target=positions[1] or at+Vector3.new(0,0,-10)
 if t<5 then
  local index=math.clamp(math.floor((t-3)*math.max(split,1)/2)+1,1,math.max(split,1)); target=positions[index] or target
  at=s.actorOrigin:Lerp(target+Vector3.new(4,0,3),math.clamp((t-3)*1.5,0,1)); caption.Text="Время, остановись. Проверим этих NPC..."
 elseif t<8 then
  local index=math.clamp(split+1+math.floor((t-5)*math.max(n-split-1,1)/3),1,math.max(n-1,1)); target=positions[index] or target; at=target+Vector3.new(4,0,3)
  caption.Text="Оу, я вас, похоже, пропустил?"
 elseif t<11 then target=positions[n] or target; at=target+Vector3.new(4,0,3); caption.Text="А вы отправляетесь за карту!"
 else target=positions[n] or target; at=target+Vector3.new(4,0,3); caption.Text="Да, забыл про вас..."; console.Visible=true; console.Text="> /ban NPC  •  ДОСТУП РАЗРАБОТЧИКА" end
 local facing=CFrame.lookAt(at,Vector3.new(target.X,at.Y,target.Z)); pose(s.actor,s.actorLimbs,facing,t,t<11)
 if s.camera and workspace.CurrentCamera==s.camera then
  local focus=(at+target)/2
  if t>=8 and t<9 and n-split>1 then focus=(positions[split+1] or target)+Vector3.new(0,25,-300) end
  local desired=CFrame.lookAt(focus+Vector3.new(12,8,15),focus); s.camera.CFrame=s.camera.CFrame:Lerp(desired,.16)
 end
end)
connections[#connections+1]=player:GetAttributeChangedSignal("InMatch"):Connect(function() if not player:GetAttribute("InMatch") then resetScene() end end)
script.Destroying:Connect(function() resetScene(); for _,c in ipairs(connections) do c:Disconnect() end; gui:Destroy(); effects:Destroy() end)
