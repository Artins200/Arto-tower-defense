--!strict
-- Только визуал: сервер сам выбирает цель и рассчитывает попадание / урон.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local fx=ReplicatedStorage:WaitForChild("TDFx")
local colors={Shooter=Color3.fromRGB(255,204,97),Cannon=Color3.fromRGB(255,117,74),Ice=Color3.fromRGB(137,235,255),Sniper=Color3.fromRGB(206,135,255)}
local folder=Instance.new("Folder"); folder.Name="LocalCombatFX"; folder.Parent=workspace
local animations={}; local flights={}; local connections={}
local function visualPart(name,size,color,material)
 local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Size=size; p.Color=color; p.Material=material or Enum.Material.Neon; p.Parent=folder; return p
end
local function fade(part,duration)
 TweenService:Create(part,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transparency=1}):Play(); Debris:AddItem(part,duration+.1)
end
local function line(a,b,color,width,duration)
 local distance=(b-a).Magnitude; if distance<.01 then return end
 local p=visualPart("EnergyTrail",Vector3.new(width,width,distance),color); p.CFrame=CFrame.lookAt((a+b)/2,b); fade(p,duration)
end
local function ring(pos,color,radius,duration)
 local p=visualPart("ImpactRing",Vector3.new(.12,1,1),color); p.Shape=Enum.PartType.Cylinder; p.CFrame=CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2); p.Transparency=.25
 TweenService:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(.12,radius*2,radius*2),Transparency=1}):Play(); Debris:AddItem(p,duration+.1)
end
local function sparkBurst(pos,color,count,length)
 for i=1,count do
  local angle=(i/count)*math.pi*2; local direction=Vector3.new(math.cos(angle),.4+(i%3)*.2,math.sin(angle)).Unit
  line(pos,pos+direction*length,color,.16,.3)
 end
end
local function animate(model,target,kind)
 if not model or not model:IsA("Model") or not model.Parent then return end
 local anim=animations[model]
 if not anim then
  local pivot=model:GetPivot(); local arms={}
  for _,name in {"Right Arm","Left Arm"} do local arm=model:FindFirstChild(name); if arm and arm:IsA("BasePart") then arms[name]={part=arm,offset=pivot:ToObjectSpace(arm.CFrame)} end end
  anim={pivot=pivot,arms=arms}; animations[model]=anim
 end
 anim.started=os.clock(); anim.target=target; anim.kind=kind; anim.duration=kind=="Sniper" and .65 or (kind=="Cannon" and .55 or .38)
end
local function startFlight(kind,origin,target,targetModel)
 local color=colors[kind]; local distance=(target-origin).Magnitude
 if kind=="Shooter" then line(origin,target,color,.22,.16); sparkBurst(origin,color,4,1.4)
 elseif kind=="Sniper" then
  line(origin,target,color,.65,.25); line(origin,target,Color3.new(1,1,1),.18,.18); ring(origin,color,3,.3); sparkBurst(origin,color,8,2.5)
 else
  local shell=visualPart(kind=="Ice" and "FrostSpear" or "CannonShell",kind=="Ice" and Vector3.new(.45,.45,2.3) or Vector3.new(1.1,1.1,1.6),color)
  shell.CFrame=CFrame.lookAt(origin,target)
  local a0=Instance.new("Attachment"); a0.Position=Vector3.new(0,.2,.5); a0.Parent=shell
  local a1=Instance.new("Attachment"); a1.Position=Vector3.new(0,-.2,.5); a1.Parent=shell
  local trail=Instance.new("Trail"); trail.Attachment0=a0; trail.Attachment1=a1; trail.Color=ColorSequence.new(color); trail.Lifetime=.22; trail.FaceCamera=true; trail.Parent=shell
  flights[#flights+1]={part=shell,start=origin,target=target,targetModel=targetModel,created=os.clock(),duration=math.max(.12,distance/55),arc=kind=="Cannon" and 6 or 0}
  sparkBurst(origin,color,5,1.8)
 end
end
local function impact(kind,pos,radius)
 local color=colors[kind]; if not color then return end
 if kind=="Cannon" then ring(pos,color,math.max(radius,5),.55); ring(pos,Color3.fromRGB(255,214,124),math.max(radius*.6,3),.35); sparkBurst(pos,color,14,5)
 elseif kind=="Ice" then
  ring(pos,color,5,.45); sparkBurst(pos,color,10,3)
  for i=1,6 do local angle=i*math.pi/3; local p=visualPart("IceShard",Vector3.new(.35,2,.35),color); p.CFrame=CFrame.new(pos+Vector3.new(math.cos(angle)*2,0,math.sin(angle)*2))*CFrame.Angles(0,angle,.4); fade(p,.45) end
 elseif kind=="Sniper" then ring(pos,color,5,.45); line(pos+Vector3.new(0,-2,0),pos+Vector3.new(0,5,0),color,.45,.4); sparkBurst(pos,color,12,4)
 else sparkBurst(pos,color,6,2); ring(pos,color,2,.2) end
end
connections[#connections+1]=fx.OnClientEvent:Connect(function(action,kind,a,b,c,d)
 if action=="Fire" and colors[kind] and typeof(a)=="Vector3" and typeof(b)=="Vector3" then animate(c,b,kind); startFlight(kind,a,b,d)
 elseif action=="Impact" and colors[kind] and typeof(a)=="Vector3" then impact(kind,a,typeof(b)=="number" and b or 0) end
end)
connections[#connections+1]=RunService.RenderStepped:Connect(function()
 local now=os.clock()
 for model,anim in pairs(animations) do
  if not model.Parent then animations[model]=nil
  else
   local progress=math.clamp((now-anim.started)/anim.duration,0,1)
   if progress>=1 then
    model:PivotTo(anim.pivot); for _,arm in pairs(anim.arms) do if arm.part.Parent then arm.part.CFrame=anim.pivot*arm.offset end end; animations[model]=nil
   else
    local strength=math.sin(progress*math.pi); local at=anim.pivot.Position; local aim=Vector3.new(anim.target.X,at.Y,anim.target.Z)
    local facing=(aim-at).Magnitude>.01 and CFrame.lookAt(at,aim) or anim.pivot
    local lean=anim.kind=="Cannon" and -.16 or (anim.kind=="Sniper" and -.12 or .07)
    local pivot=facing*CFrame.new(0,strength*.12,0)*CFrame.Angles(lean*strength,0,0); model:PivotTo(pivot)
    for name,arm in pairs(anim.arms) do
     if arm.part.Parent then
      local left=name=="Left Arm"; local amount=(anim.kind=="Ice" and left or anim.kind=="Cannon" or not left) and -1.15 or -.28
      local rotate=CFrame.new(0,arm.part.Size.Y/2,0)*CFrame.Angles(amount*strength,0,(left and -.12 or .12)*strength)*CFrame.new(0,-arm.part.Size.Y/2,0)
      arm.part.CFrame=pivot*arm.offset*rotate
     end
    end
   end
  end
 end
 for i=#flights,1,-1 do
  local flight=flights[i]; if flight.targetModel and flight.targetModel.Parent and flight.targetModel.PrimaryPart then flight.target=flight.targetModel.PrimaryPart.Position end; local progress=math.clamp((now-flight.created)/flight.duration,0,1)
  if progress>=1 then flight.part:Destroy(); table.remove(flights,i)
  else
   local position=flight.start:Lerp(flight.target,progress)+Vector3.new(0,math.sin(progress*math.pi)*flight.arc,0)
   local look=flight.target-position; if look.Magnitude>.01 then flight.part.CFrame=CFrame.lookAt(position,flight.target)*CFrame.Angles(0,0,progress*math.pi*4) end
  end
 end
end)
script.Destroying:Connect(function()
 for model,anim in pairs(animations) do if model.Parent then model:PivotTo(anim.pivot); for _,arm in pairs(anim.arms) do if arm.part.Parent then arm.part.CFrame=anim.pivot*arm.offset end end end end
 for _,c in ipairs(connections) do c:Disconnect() end
 folder:Destroy()
end)
