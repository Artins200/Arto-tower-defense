--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local Config=require(ReplicatedStorage.Config)
local Tower={}; Tower.__index=Tower
function Tower.new(player,kind,plot,template)
 local model=template:Clone(); model.Name=Config.Towers[kind].name
 -- Риг декоративный: сервер сам управляет башней; никакие скрипты или физика шаблона не выполняются.
 for _,d in model:GetDescendants() do
  if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=true end
 end
 model.Parent=workspace.Towers
 local cf,size=model:GetBoundingBox(); local pivot=model:GetPivot(); local bottom=cf.Position.Y-size.Y/2
 model:PivotTo(pivot + Vector3.new(plot.Position.X-cf.Position.X,plot.Position.Y+plot.Size.Y/2-bottom,plot.Position.Z-cf.Position.Z))
 model:SetAttribute("Owner",player.UserId); model:SetAttribute("Kind",kind); model:SetAttribute("Level",1); model:SetAttribute("Spent",Config.Towers[kind].cost)
 CollectionService:AddTag(model,"Tower"); plot:SetAttribute("Occupied",true); plot.Color=Color3.fromRGB(64,83,79)
 local highlight=Instance.new("Highlight"); highlight.FillColor=Config.Towers[kind].color; highlight.FillTransparency=.8; highlight.OutlineColor=Config.Towers[kind].color; highlight.DepthMode=Enum.HighlightDepthMode.Occluded; highlight.Parent=model
 local self=setmetatable({owner=player,kind=kind,plot=plot,model=model,level=1,spent=Config.Towers[kind].cost,lastShot=0},Tower)
 return self
end
function Tower:update(now,enemies,fire)
 if now-self.lastShot<Config.stats(self.kind,self.level).cooldown then return end
 local stats=Config.stats(self.kind,self.level); local origin=self.plot.Position+Vector3.new(0,4,0); local target=nil; local best=-1
 for _,e in ipairs(enemies) do
  if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-origin).Magnitude<=stats.range and e.progress>best then target=e; best=e.progress end
 end
 if target then self.lastShot=now; fire(self,target,origin,stats) end
end
function Tower:upgrade()
 local price=Config.upgradeCost(self.kind,self.level); self.level+=1; self.spent+=price; self.model:SetAttribute("Level",self.level); self.model:SetAttribute("Spent",self.spent)
end
function Tower:destroy()
 self.plot:SetAttribute("Occupied",false); self.plot.Color=Color3.fromRGB(107,173,139); self.model:Destroy()
end
return Tower
