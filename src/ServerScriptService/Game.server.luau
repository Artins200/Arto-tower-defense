--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage:WaitForChild("Config"))
local Map=require(script.Parent.MapBuilder).build()
local Enemy=require(script.Parent.Enemy)
local Tower=require(script.Parent.Tower)
Enemy.prepare(Map.templates.Enemies)
local remote=Instance.new("RemoteEvent"); remote.Name="TDRequest"; remote.Parent=ReplicatedStorage
local notice=Instance.new("RemoteEvent"); notice.Name="TDNotice"; notice.Parent=ReplicatedStorage
local state=Instance.new("Folder"); state.Name="TDState"; state.Parent=ReplicatedStorage
local function set(k,v) state:SetAttribute(k,v) end
set("Phase","Lobby"); set("Wave",0); set("Timer",0); set("BaseHP",0); set("BaseMaxHP",0); set("Difficulty","")
local participants={}; local unlocked={}; local towers={}; local enemies={}; local projectiles={}; local lastRequest={}
local owner=nil; local difficulty=nil; local phase="Lobby"; local wave=0; local timer=0; local baseHP=0; local groups=nil; local groupIndex=1; local spawnRemaining=0; local spawnTimer=0
local connections={}; local playerConnections={}
local allowed={ChooseDifficulty=true,Spin=true,StartWave=true,Place=true,Upgrade=true,Sell=true}
local function say(p,text) if p and p.Parent==Players then notice:FireClient(p,"Message",text) end end
local function gold(p,n) p:SetAttribute("Gold",math.max(0,n)) end
local function tele(p,cf) local c=p.Character; if c then c:PivotTo(cf) end end
local function setupPlayer(p)
 gold(p,Config.StartGold); p:SetAttribute("SpinTokens",400); p:SetAttribute("InMatch",false); unlocked[p]={Shooter=true}; p:SetAttribute("Unlocked_Shooter",true)
 for _,kind in {"Cannon","Ice","Sniper"} do p:SetAttribute("Unlocked_"..kind,false) end
 playerConnections[p]=p.CharacterAdded:Connect(function(character) if p:GetAttribute("InMatch") then character:WaitForChild("HumanoidRootPart",10); if p:GetAttribute("InMatch") and character.Parent then character:PivotTo(Map.arenaSpawn) end end end)
end
for _,p in Players:GetPlayers() do setupPlayer(p) end
connections[#connections+1]=Players.PlayerAdded:Connect(setupPlayer)
local function clearMatch()
 for _,t in pairs(towers) do t:destroy() end; table.clear(towers)
 for _,e in ipairs(enemies) do if e.model then e.model:Destroy() end end; table.clear(enemies)
 for _,p in ipairs(projectiles) do p.part:Destroy() end; table.clear(projectiles)
 for p in pairs(participants) do if p.Parent==Players then p:SetAttribute("InMatch",false); tele(p,Map.lobbySpawn) end end
 table.clear(participants); owner=nil; difficulty=nil; wave=0; timer=0; baseHP=0; phase="Lobby"; set("Phase",phase); set("Wave",0); set("Timer",0); set("BaseHP",0); set("BaseMaxHP",0); set("Difficulty","")
end
local function endMatch(result)
 if phase=="GameOver" or phase=="Victory" then return end
 phase=result; set("Phase",phase); timer=12; set("Timer",timer)
 for _,e in ipairs(enemies) do e.alive=false; e.model:Destroy() end; table.clear(enemies)
 for _,p in ipairs(projectiles) do p.part:Destroy() end; table.clear(projectiles)
end
connections[#connections+1]=Players.PlayerRemoving:Connect(function(p)
 participants[p]=nil; unlocked[p]=nil; lastRequest[p]=nil; if playerConnections[p] then playerConnections[p]:Disconnect(); playerConnections[p]=nil end
 for model,t in pairs(towers) do if t.owner==p then t:destroy(); towers[model]=nil end end
 if owner==p then owner=next(participants) end
 if phase~="Lobby" and next(participants)==nil then clearMatch() end
end)
connections[#connections+1]=Map.portal.Triggered:Connect(function(p)
 if phase=="Lobby" then notice:FireClient(p,"ChooseDifficulty")
 elseif phase=="Intermission" or phase=="Wave" then if not participants[p] then gold(p,Config.StartGold) end; participants[p]=true; p:SetAttribute("InMatch",true); tele(p,Map.arenaSpawn); say(p,"Вы присоединились к битве!")
 else say(p,"Дождитесь завершения раунда.") end
end)
connections[#connections+1]=Map.spin.Triggered:Connect(function(p) notice:FireClient(p,"OpenSummon") end)
local function near(p,pos,limit)
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 return root~=nil and (root.Position-pos).Magnitude<=limit
end
local function spawnEnemy(kind)
 local e=Enemy.new(kind,difficulty,Map.coords,Map.templates.Enemies,function(dead)
  -- Награда один раз всем участникам матча, а не данным из клиента.
  for p in pairs(participants) do if p.Parent==Players then gold(p,(p:GetAttribute("Gold") or 0)+Config.Enemies[dead.kind].reward) end end
 end,function(escaped)
  baseHP=math.max(0,baseHP-Config.Enemies[escaped.kind].damage); set("BaseHP",baseHP); if baseHP<=0 then endMatch("GameOver") end
 end)
 enemies[#enemies+1]=e
end
local function beginWave()
 if phase~="Intermission" then return end
 wave+=1; set("Wave",wave); phase="Wave"; set("Phase",phase); timer=0; set("Timer",0)
 groups=Config.Waves[wave]; groupIndex=1; spawnRemaining=groups[1].count; spawnTimer=0
end
local function fire(t,target,origin,stats)
 local ball=Map.templates.Projectiles.Projectile:Clone(); ball.Color=Config.Towers[t.kind].color; ball.Anchored=true; ball.CanCollide=false; ball.CanQuery=false; ball.Position=origin; ball.Parent=workspace.TDMap
 projectiles[#projectiles+1]={part=ball,target=target,stats=stats,expires=os.clock()+5}
end
local function accept(p,action)
 local now=os.clock(); lastRequest[p]=lastRequest[p] or {}; local last=lastRequest[p][action] or 0
 if now-last<0.2 then return false end; lastRequest[p][action]=now; return true
end
connections[#connections+1]=remote.OnServerEvent:Connect(function(p,action,arg)
 if typeof(action)~="string" or not allowed[action] or not accept(p,action) then return end
 if action=="ChooseDifficulty" then
  if phase~="Lobby" or typeof(arg)~="string" or not Config.Difficulties[arg] or not near(p,Map.portal.Parent.Position,25) then return end
  owner=p; difficulty=Config.Difficulties[arg]; gold(p,Config.StartGold); participants[p]=true; p:SetAttribute("InMatch",true); baseHP=difficulty.base; wave=0; timer=Config.Intermission; phase="Intermission"
  set("Difficulty",difficulty.name); set("BaseMaxHP",baseHP); set("BaseHP",baseHP); set("Phase",phase); set("Timer",timer); tele(p,Map.arenaSpawn)
 elseif action=="Spin" then
  if not near(p,Map.spin.Parent.Position,25) then return end
  local tokens=p:GetAttribute("SpinTokens") or 0; if tokens<Config.SpinCost then say(p,"Недостаточно жетонов призыва") return end
  gold(p,p:GetAttribute("Gold") or 0); p:SetAttribute("SpinTokens",tokens-Config.SpinCost)
  local pool={"Cannon","Ice","Sniper"}; local kind=pool[math.random(1,#pool)]; local duplicate=unlocked[p][kind]; unlocked[p][kind]=true; p:SetAttribute("Unlocked_"..kind,true)
  if duplicate then p:SetAttribute("SpinTokens",p:GetAttribute("SpinTokens")+100) end
  say(p,"Призыв: "..Config.Towers[kind].name..(duplicate and " (повтор: +100 жетонов)" or " — открыт!"))
 elseif action=="StartWave" then
  if participants[p] and p==owner and phase=="Intermission" then beginWave() end
 elseif action=="Place" then
  if not participants[p] or (phase~="Wave" and phase~="Intermission") or typeof(arg)~="table" then return end
  local kind,plot=arg.kind,arg.plot
  if typeof(kind)~="string" or not Config.Towers[kind] or not unlocked[p][kind] or typeof(plot)~="Instance" or not plot:IsA("BasePart") or plot.Parent~=workspace.Plots or plot:GetAttribute("Occupied") or not near(p,plot.Position,35) then return end
  local price=Config.Towers[kind].cost; local balance=p:GetAttribute("Gold") or 0; if balance<price then say(p,"Недостаточно золота") return end
  local template=Map.templates.Towers:FindFirstChild("StarterUnit"); if not template then say(p,"Не найдена модель dibil1488777 в Place13") return end
  gold(p,balance-price); local tower=Tower.new(p,kind,plot,template); towers[tower.model]=tower
 elseif action=="Upgrade" or action=="Sell" then
  if not participants[p] or (phase~="Wave" and phase~="Intermission") or typeof(arg)~="Instance" then return end
  local t=towers[arg]; if not t or t.owner~=p or not near(p,t.plot.Position,35) then return end
  if action=="Sell" then gold(p,(p:GetAttribute("Gold") or 0)+math.floor(t.spent*Config.SellRatio)); towers[arg]=nil; t:destroy()
  else if t.level>=3 then say(p,"Максимальный уровень") return end; local cost=Config.upgradeCost(t.kind,t.level); local balance=p:GetAttribute("Gold") or 0; if balance<cost then say(p,"Недостаточно золота") return end; gold(p,balance-cost); t:upgrade() end
 end
end)
connections[#connections+1]=RunService.Heartbeat:Connect(function(delta)
 local dt=math.min(delta,0.15)
 if phase=="Intermission" then timer-=dt; set("Timer",math.max(0,math.ceil(timer))); if timer<=0 then beginWave() end
 elseif phase=="Wave" then
  if groups and groupIndex<=#groups then
   spawnTimer-=dt
   if spawnTimer<=0 then local group=groups[groupIndex]; spawnEnemy(group.kind); spawnRemaining-=1; spawnTimer=group.interval; if spawnRemaining<=0 then groupIndex+=1; if groupIndex<=#groups then spawnRemaining=groups[groupIndex].count end end end
  end
  for i=#enemies,1,-1 do local e=enemies[i]; e:update(dt); if phase~="Wave" then return end; if not e.alive then table.remove(enemies,i) end end
  for _,t in pairs(towers) do t:update(os.clock(),enemies,fire) end
  for i=#projectiles,1,-1 do
   local shot=projectiles[i]; local target=shot.target; local remove=false
   if not target.alive or not target.model.PrimaryPart or os.clock()>shot.expires then remove=true
   else
    local targetPos=target.model.PrimaryPart.Position; local deltaPos=targetPos-shot.part.Position; local distance=deltaPos.Magnitude; local step=55*dt
    if distance<=step then
     local s=shot.stats
     if s.splash then for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-targetPos).Magnitude<=s.splash then e:hit(s.damage,s.slow,s.slowDuration) end end
     else target:hit(s.damage,s.slow,s.slowDuration) end
     remove=true
    elseif distance>0 then shot.part.Position+=deltaPos.Unit*step end
   end
   if remove then shot.part:Destroy(); table.remove(projectiles,i) end
  end
  if groups and groupIndex>#groups and #enemies==0 then
   for p in pairs(participants) do if p.Parent==Players then gold(p,(p:GetAttribute("Gold") or 0)+difficulty.bonus); p:SetAttribute("SpinTokens",(p:GetAttribute("SpinTokens") or 0)+35) end end
   if wave>=Config.TotalWaves then endMatch("Victory") else phase="Intermission"; timer=Config.Intermission; set("Phase",phase); set("Timer",timer) end
  end
 elseif phase=="Victory" or phase=="GameOver" then timer-=dt; set("Timer",math.max(0,math.ceil(timer))); if timer<=0 then clearMatch() end end
end)
-- Соединения отключаются, если серверный скрипт выключен/удалён.
script.Destroying:Connect(function() for _,connection in ipairs(connections) do connection:Disconnect() end; for _,connection in pairs(playerConnections) do connection:Disconnect() end end)
