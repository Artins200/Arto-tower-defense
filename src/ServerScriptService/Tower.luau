--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local Config=require(ReplicatedStorage.Config)
local Tower={}; Tower.__index=Tower
function Tower.new(player,kind,position,template)
 local model=template:Clone(); model.Name=Config.Towers[kind].name
 -- Риг декоративный: сервер управляет башней, а не скрипты или физика шаблона.
 for _,d in model:GetDescendants() do
  if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=true elseif d:IsA("Humanoid") then d.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
 end
 model.Parent=workspace.Towers
 local cf,size=model:GetBoundingBox(); local pivot=model:GetPivot(); local bottom=cf.Position.Y-size.Y/2
 model:PivotTo(pivot + Vector3.new(position.X-cf.Position.X,position.Y-bottom,position.Z-cf.Position.Z))
 model:SetAttribute("UltimateReadyAt",0); model:SetAttribute("Owner",player.UserId); model:SetAttribute("Kind",kind); model:SetAttribute("Level",1); model:SetAttribute("Spent",Config.Towers[kind].cost); model:SetAttribute("PlacementPosition",position)
 CollectionService:AddTag(model,"Tower")
 local highlight=Instance.new("Highlight"); highlight.FillColor=Config.Towers[kind].color; highlight.FillTransparency=.85; highlight.OutlineColor=Config.Towers[kind].color; highlight.DepthMode=Enum.HighlightDepthMode.Occluded; highlight.Parent=model
 local self=setmetatable({owner=player,kind=kind,position=position,model=model,level=1,spent=Config.Towers[kind].cost,lastShot=0,placedAt=workspace:GetServerTimeNow(),readyAt=0,suppressed=false},Tower)
 return self
end
function Tower:update(now,enemies,fire)
 if self.suppressed then return end
 if now-self.lastShot<Config.stats(self.kind,self.level).cooldown then return end
 local stats=Config.stats(self.kind,self.level); local origin=self.position+Vector3.new(0,4,0); local target=nil; local best=-1
 for _,e in ipairs(enemies) do
  if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-origin).Magnitude<=stats.range and e.progress>best then target=e; best=e.progress end
 end
 if target then self.lastShot=now; fire(self,target,origin,stats) end
end
function Tower:upgrade()
 local price=Config.upgradeCost(self.kind,self.level); self.level+=1; self.spent+=price; self.model:SetAttribute("Level",self.level); self.model:SetAttribute("Spent",self.spent)
end
function Tower:destroy() self.model:Destroy() end
return Tower
