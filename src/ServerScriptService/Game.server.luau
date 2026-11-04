--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage:WaitForChild("Config"))
local Map=require(script.Parent.MapBuilder).build()
local Enemy=require(script.Parent.Enemy)
local Tower=require(script.Parent.Tower)
local Placement=require(ReplicatedStorage.Placement)
local Rules=require(ReplicatedStorage.CombatRules)
Enemy.prepare(Map.templates.Enemies)
local remote=Instance.new("RemoteEvent"); remote.Name="TDRequest"; remote.Parent=ReplicatedStorage
local notice=Instance.new("RemoteEvent"); notice.Name="TDNotice"; notice.Parent=ReplicatedStorage
local fx=Instance.new("RemoteEvent"); fx.Name="TDFx"; fx.Parent=ReplicatedStorage
local state=Instance.new("Folder"); state.Name="TDState"; state.Parent=ReplicatedStorage
local function set(k,v) state:SetAttribute(k,v) end
local baseHealth=Instance.new("BillboardGui"); baseHealth.Name="BaseHealth"; baseHealth.Size=UDim2.fromOffset(180,44); baseHealth.StudsOffset=Vector3.new(0,10,0); baseHealth.AlwaysOnTop=true; baseHealth.Parent=Map.base
local hpText=Instance.new("TextLabel"); hpText.BackgroundTransparency=1; hpText.Size=UDim2.fromScale(1,1); hpText.TextColor3=Color3.fromRGB(200,255,237); hpText.TextStrokeTransparency=.15; hpText.Font=Enum.Font.GothamBold; hpText.TextScaled=true; hpText.Parent=baseHealth
local function updateBaseLabel() hpText.Text="HP БАЗЫ  "..tostring(state:GetAttribute("BaseHP") or 0).." / "..tostring(state:GetAttribute("BaseMaxHP") or 0) end
local baseHealthConnection=state.AttributeChanged:Connect(updateBaseLabel); updateBaseLabel()
set("Phase","Lobby"); set("Wave",0); set("Timer",0); set("BaseHP",0); set("BaseMaxHP",0); set("Difficulty",""); set("TeamCount",0); set("LeaderUserId",0); set("LeaderName",""); set("AutoSkip",false); set("UltimateActive",false)
local participants={}; local unlocked={}; local towers={}; local enemies={}; local projectiles={}; local lastRequest={}
local joinedThisRound={}
local autoSkip=false; local roundStartedAt=nil; local ultimate=nil; local forceNextWave=false
local owner=nil; local difficulty=nil; local phase="Lobby"; local wave=0; local timer=0; local baseHP=0; local groups=nil; local groupIndex=1; local spawnRemaining=0; local spawnTimer=0
local connections={}; local playerConnections={}
local allowed={ChooseDifficulty=true,Spin=true,StartWave=true,Place=true,Upgrade=true,Sell=true,LeaveMatch=true,AutoSkip=true,Ultimate=true}
local function say(p,text) if p and p.Parent==Players then notice:FireClient(p,"Message",text) end end
local function updateTeam()
 local count=0; for p in pairs(participants) do if p.Parent==Players then count+=1 end end
 set("TeamCount",count); set("LeaderUserId",owner and owner.UserId or 0); set("LeaderName",owner and owner.DisplayName or "")
end
local function teamMessage(message) for p in pairs(participants) do say(p,message) end end
local function teamFx(...) for p in pairs(participants) do if p.Parent==Players then fx:FireClient(p,...) end end end
local function thawPlayer(p)
 if not ultimate or not ultimate.frozenPlayers then return end
 local saved=ultimate.frozenPlayers[p]; if not saved then return end
 if saved.root and saved.root.Parent then saved.root.Anchored=saved.anchored end
 if saved.humanoid and saved.humanoid.Parent then saved.humanoid.WalkSpeed=saved.speed; saved.humanoid.JumpPower=saved.jump; saved.humanoid.AutoRotate=saved.autoRotate end
 ultimate.frozenPlayers[p]=nil
end
local function freezePlayer(p)
 if not ultimate or ultimate.kind~="Sniper" or not ultimate.frozenPlayers or ultimate.frozenPlayers[p] then return end
 local character=p.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid"); local root=character and character:FindFirstChild("HumanoidRootPart")
 if humanoid and root and root:IsA("BasePart") then
  ultimate.frozenPlayers[p]={root=root,anchored=root.Anchored,humanoid=humanoid,speed=humanoid.WalkSpeed,jump=humanoid.JumpPower,autoRotate=humanoid.AutoRotate}
  root.Anchored=true; humanoid.WalkSpeed=0; humanoid.JumpPower=0; humanoid.AutoRotate=false
 end
end
local function endUltimate()
 if not ultimate then return end
 if ultimate.frozenPlayers then local players={}; for p in pairs(ultimate.frozenPlayers) do table.insert(players,p) end; for _,p in ipairs(players) do thawPlayer(p) end end
 if ultimate.tower then ultimate.tower.suppressed=false end
 ultimate=nil; set("UltimateActive",false); teamFx("UltimateEnd")
end
local function gold(p,n) p:SetAttribute("Gold",math.max(0,n)) end
local function tele(p,cf) local c=p.Character; if c then c:PivotTo(cf) end end
local function setupPlayer(p)
 gold(p,Config.StartGold); p:SetAttribute("SpinTokens",400); p:SetAttribute("InMatch",false); unlocked[p]={Shooter=true}; p:SetAttribute("Unlocked_Shooter",true)
 for _,kind in {"Cannon","Ice","Sniper"} do p:SetAttribute("Unlocked_"..kind,false) end
 playerConnections[p]=p.CharacterAdded:Connect(function(character) if p:GetAttribute("InMatch") then character:WaitForChild("HumanoidRootPart",10); if p:GetAttribute("InMatch") and character.Parent then character:PivotTo(Map.arenaSpawn); thawPlayer(p); freezePlayer(p) end end end)
end
for _,p in Players:GetPlayers() do setupPlayer(p) end
connections[#connections+1]=Players.PlayerAdded:Connect(setupPlayer)
local function clearMatch()
 endUltimate(); autoSkip=false; roundStartedAt=nil; forceNextWave=false; set("AutoSkip",false)
 for _,t in pairs(towers) do t:destroy() end; table.clear(towers)
 for _,e in ipairs(enemies) do if e.model then e.model:Destroy() end end; table.clear(enemies)
 table.clear(projectiles)
 for p in pairs(participants) do if p.Parent==Players then p:SetAttribute("InMatch",false); tele(p,Map.lobbySpawn) end end
 table.clear(participants); table.clear(joinedThisRound); owner=nil; updateTeam(); difficulty=nil; wave=0; timer=0; baseHP=0; phase="Lobby"; set("Phase",phase); set("Wave",0); set("Timer",0); set("BaseHP",0); set("BaseMaxHP",0); set("Difficulty","")
end
local function endMatch(result)
 if phase=="GameOver" or phase=="Victory" then return end
 endUltimate(); phase=result; set("Phase",phase); timer=12; set("Timer",timer)
 for _,e in ipairs(enemies) do e.alive=false; e.model:Destroy() end; table.clear(enemies)
 table.clear(projectiles)
end
connections[#connections+1]=Players.PlayerRemoving:Connect(function(p)
 thawPlayer(p); participants[p]=nil; unlocked[p]=nil; lastRequest[p]=nil; if playerConnections[p] then playerConnections[p]:Disconnect(); playerConnections[p]=nil end
 for model,t in pairs(towers) do if t.owner==p then t:destroy(); towers[model]=nil end end
 if owner==p then owner=next(participants) end
 updateTeam(); teamMessage(p.DisplayName.." покинул команду")
 if phase~="Lobby" and next(participants)==nil then clearMatch() end
end)
connections[#connections+1]=Map.portal.Triggered:Connect(function(p)
 if phase=="Lobby" then notice:FireClient(p,"ChooseDifficulty")
 elseif phase=="Gathering" or phase=="Intermission" or phase=="Wave" then
  if ultimate and ultimate.kind=="Sniper" then say(p,"Подождите окончания остановки времени") return end
  if not participants[p] then
   if not joinedThisRound[p.UserId] then gold(p,Config.StartGold); joinedThisRound[p.UserId]=true end
   participants[p]=true; p:SetAttribute("InMatch",true); updateTeam(); teamMessage(p.DisplayName.." присоединился к команде!")
  end
  tele(p,Map.arenaSpawn)
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
 if phase~="Intermission" and phase~="Gathering" then return end
 if not roundStartedAt then
  roundStartedAt=workspace:GetServerTimeNow()
  for _,t in pairs(towers) do t.readyAt=Rules.readyAt(roundStartedAt,t.placedAt,Config.UltimateCooldown); t.model:SetAttribute("UltimateReadyAt",t.readyAt) end
 end
 wave+=1; set("Wave",wave); phase="Wave"; set("Phase",phase); timer=0; set("Timer",0)
 groups=Config.Waves[wave]; groupIndex=1; spawnRemaining=groups[1].count; spawnTimer=0
end
local function fire(t,target,origin,stats)
 -- Визуал клиентский, движение и попадания вычисляются исключительно сервером.
 local targetPos=target.model.PrimaryPart.Position
 fx:FireAllClients("Fire",t.kind,origin,targetPos,t.model,target.model)
 projectiles[#projectiles+1]={position=origin,target=target,stats=stats,kind=t.kind,expires=os.clock()+5}
end
local function accept(p,action)
 local now=os.clock(); lastRequest[p]=lastRequest[p] or {}; local last=lastRequest[p][action] or 0
 if now-last<0.2 then return false end; lastRequest[p][action]=now; return true
end
connections[#connections+1]=remote.OnServerEvent:Connect(function(p,action,arg)
 if typeof(action)~="string" or not allowed[action] or not accept(p,action) then return end
 if action=="ChooseDifficulty" then
  if phase~="Lobby" or typeof(arg)~="string" or not Config.Difficulties[arg] or not near(p,Map.portal.Parent.Position,25) then return end
  owner=p; difficulty=Config.Difficulties[arg]; gold(p,Config.StartGold); participants[p]=true; joinedThisRound[p.UserId]=true; p:SetAttribute("InMatch",true); updateTeam(); baseHP=difficulty.base; wave=0; timer=35; phase="Gathering"
  set("Difficulty",difficulty.name); set("BaseMaxHP",baseHP); set("BaseHP",baseHP); set("Phase",phase); set("Timer",timer); tele(p,Map.arenaSpawn)
 elseif action=="Spin" then
  if not near(p,Map.spin.Parent.Position,25) then return end
  local tokens=p:GetAttribute("SpinTokens") or 0; if tokens<Config.SpinCost then say(p,"Недостаточно жетонов призыва") return end
  gold(p,p:GetAttribute("Gold") or 0); p:SetAttribute("SpinTokens",tokens-Config.SpinCost)
  local roll=math.random(1,100); local kind=roll<=50 and "Cannon" or (roll<=80 and "Ice" or "Sniper"); local duplicate=unlocked[p][kind]; unlocked[p][kind]=true; p:SetAttribute("Unlocked_"..kind,true)
  if duplicate then p:SetAttribute("SpinTokens",p:GetAttribute("SpinTokens")+100) end
  say(p,"Призыв: "..Config.Towers[kind].name..(duplicate and " (повтор: +100 жетонов)" or " — открыт!"))
 elseif action=="StartWave" then
  if participants[p] and p==owner and (phase=="Intermission" or phase=="Gathering") then beginWave() end
 elseif action=="AutoSkip" then
  if participants[p] and p==owner and typeof(arg)=="boolean" then autoSkip=arg; set("AutoSkip",arg); if arg and phase=="Intermission" then timer=0 end end
 elseif action=="LeaveMatch" then
  if not participants[p] then return end
  fx:FireClient(p,"UltimateEnd"); thawPlayer(p)
  participants[p]=nil; p:SetAttribute("InMatch",false)
  for model,t in pairs(towers) do if t.owner==p then t:destroy(); towers[model]=nil end end
  if owner==p then owner=next(participants) end
  updateTeam(); tele(p,Map.lobbySpawn); teamMessage(p.DisplayName.." покинул команду")
  if next(participants)==nil then clearMatch() end
 elseif action=="Place" then
  if not participants[p] or (phase~="Wave" and phase~="Intermission" and phase~="Gathering") or typeof(arg)~="table" then return end
  if ultimate and ultimate.kind=="Sniper" then say(p,"Время остановлено") return end
  local kind,position=arg.kind,arg.position
  if typeof(kind)~="string" or not Config.Towers[kind] or not unlocked[p][kind] or typeof(position)~="Vector3" then return end
  -- Координата не доверяется клиенту: проверяем границы модели, дорогу, спавн и дистанцию.
  if not near(p,Map.arena.Position,300) or not near(p,position,300) then return end
  local template=Map.templates.Towers:FindFirstChild(kind); if not template then say(p,"Не найдена модель юнита "..kind) return end
  local _,size=template:GetBoundingBox(); local valid,reason=Placement.valid(position,Map.arena,Map.coords,Map.spawnZone,Vector2.new(size.X/2,size.Z/2))
  if not valid then say(p,reason); return end
  position=Vector3.new(position.X,Map.arena.Position.Y+Map.arena.Size.Y/2,position.Z)
  local price=Config.Towers[kind].cost; local balance=p:GetAttribute("Gold") or 0; if balance<price then say(p,"Недостаточно золота") return end
  local tower=Tower.new(p,kind,position,template); gold(p,balance-price); towers[tower.model]=tower
  if roundStartedAt then tower.readyAt=Rules.readyAt(roundStartedAt,tower.placedAt,Config.UltimateCooldown); tower.model:SetAttribute("UltimateReadyAt",tower.readyAt) end
 elseif action=="Ultimate" then
  if phase~="Wave" or not participants[p] or ultimate or typeof(arg)~="Instance" then return end
  local t=towers[arg]; if not t or t.owner~=p or not near(p,Map.arena.Position,300) or not near(p,t.position,300) then return end
  local now=workspace:GetServerTimeNow(); if not Rules.canUltimate(phase,ultimate~=nil,now,t.readyAt,1) then say(p,"Ульта ещё заряжается") return end
  local targets={}; for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart then table.insert(targets,e) end end
  if #targets==0 then say(p,"Дождитесь появления врагов") return end
  if t.kind~="Sniper" then local inRange=false; local origin=t.position+Vector3.new(0,4,0); local radius=Config.stats(t.kind,t.level).range; for _,e in ipairs(targets) do if (e.model.PrimaryPart.Position-origin).Magnitude<=radius then inRange=true; break end end; if not inRange then say(p,"В радиусе ульты нет врагов") return end end
  table.sort(targets,function(a,b) return a.progress>b.progress end)
  t.readyAt=now+Config.UltimateCooldown; t.model:SetAttribute("UltimateReadyAt",t.readyAt); t.suppressed=true
  ultimate={kind=t.kind,tower=t,targets=targets,elapsed=0,done={},beamTimer=0,frozenPlayers={}}; set("UltimateActive",true)
  local positions={}; for _,e in ipairs(targets) do table.insert(positions,e.model.PrimaryPart.Position) end
  -- Снайпер останавливает волну; очередь отменяется только после завершения кат-сцены.
  if t.kind=="Sniper" then table.clear(projectiles); for member in pairs(participants) do freezePlayer(member) end end
  teamFx("UltimateStart",t.kind,t.model,positions)
 elseif action=="Upgrade" or action=="Sell" then
  if not participants[p] or (phase~="Wave" and phase~="Intermission" and phase~="Gathering") or typeof(arg)~="Instance" then return end
  local t=towers[arg]; if not t or t.owner~=p or not near(p,Map.arena.Position,300) or not near(p,t.position,300) then return end
  if ultimate and ultimate.kind=="Sniper" then say(p,"Время остановлено") return end
  if ultimate and ultimate.tower==t then say(p,"Дождитесь завершения ульты") return end
  if action=="Sell" then gold(p,(p:GetAttribute("Gold") or 0)+math.floor(t.spent*Config.SellRatio)); towers[arg]=nil; t:destroy()
  else if t.level>=3 then say(p,"Максимальный уровень") return end; local cost=Config.upgradeCost(t.kind,t.level); local balance=p:GetAttribute("Gold") or 0; if balance<cost then say(p,"Недостаточно золота") return end; gold(p,balance-cost); t:upgrade() end
 end
end)
local function updateUltimate(dt)
 local u=ultimate; if not u then return false end
 if not towers[u.tower.model] or not u.tower.model.Parent then endUltimate(); return false end
 u.elapsed+=dt
 -- Во время вступления все башни, враги и очередь волны остановлены.
 if u.elapsed<Config.UltimateIntro then return true end
 local origin=u.tower.position+Vector3.new(0,4,0); local stats=Config.stats(u.kind,u.tower.level)
 if u.kind=="Sniper" then
  local n=#u.targets; local split=Rules.sniperSplit(n)
  if u.elapsed>=5 and not u.done.laser then
   u.done.laser=true
   for i=1,split do local e=u.targets[i]; if e.alive then local pos=e.model.PrimaryPart.Position; teamFx("UltimateStrike","Sniper",origin,pos); e:hit(e.hp) end end
  end
  if u.elapsed>=8 and not u.done.teleport then
   u.done.teleport=true
   for i=split+1,n-1 do local e=u.targets[i]; if e.alive then local pos=e.model.PrimaryPart.Position; local destination=pos+Vector3.new(0,25,-300); teamFx("UltimateBanish",pos,destination); e:banish(destination) end end
  end
  if u.elapsed>=11 and not u.done.ban then
   u.done.ban=true; local e=u.targets[n]; if e and e.alive then teamFx("UltimateStrike","Sniper",origin,e.model.PrimaryPart.Position); e:hit(e.hp) end
  end
  if u.elapsed>=Config.SniperUltimateEnd then groupIndex=#groups+1; spawnRemaining=0; forceNextWave=true; endUltimate() end
  return true
 elseif u.kind=="Ice" and not u.done.cast then
  u.done.cast=true; teamFx("UltimateStrike","Ice",origin,origin)
  for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-origin).Magnitude<=stats.range then teamFx("UltimateBeam","Ice",origin,e.model.PrimaryPart.Position); e:hit(stats.damage*3); e:freeze(8) end end
  endUltimate()
 elseif u.kind=="Cannon" and not u.done.cast then
  u.done.cast=true; local target=nil; for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-origin).Magnitude<=stats.range and (not target or e.progress>target.progress) then target=e end end
  if target then local pos=target.model.PrimaryPart.Position; teamFx("UltimateStrike","Cannon",origin,pos)
   for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-pos).Magnitude<=28 then e:hit(stats.damage*12) end end
  else teamMessage("В зоне ядерного удара нет целей") end
  endUltimate()
 elseif u.kind=="Shooter" then
  u.beamTimer-=dt
  if u.beamTimer<=0 then
   u.beamTimer=.15; local target=nil
   for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-origin).Magnitude<=stats.range and (not target or e.progress>target.progress) then target=e end end
   if target then teamFx("UltimateBeam","Shooter",origin,target.model.PrimaryPart.Position); target:hit(math.max(1,math.floor(stats.damage*.6))) end
  end
  if u.elapsed>=Config.UltimateIntro+6 then endUltimate() end
 end
 return false
end
connections[#connections+1]=RunService.Heartbeat:Connect(function(delta)
 local dt=math.min(delta,0.15)
 if phase=="Intermission" or phase=="Gathering" then timer-=dt; set("Timer",math.max(0,math.ceil(timer))); if timer<=0 then beginWave() end
 elseif phase=="Wave" then
  if updateUltimate(dt) then return end
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
    local targetPos=target.model.PrimaryPart.Position; local deltaPos=targetPos-shot.position; local distance=deltaPos.Magnitude; local step=55*dt
    if distance<=step then
     fx:FireAllClients("Impact",shot.kind,targetPos,shot.stats.splash or 0)
     local s=shot.stats
     if s.splash then for _,e in ipairs(enemies) do if e.alive and e.model.PrimaryPart and (e.model.PrimaryPart.Position-targetPos).Magnitude<=s.splash then e:hit(s.damage,s.slow,s.slowDuration) end end
     else target:hit(s.damage,s.slow,s.slowDuration) end
     remove=true
    elseif distance>0 then shot.position+=deltaPos.Unit*step end
   end
   if remove then table.remove(projectiles,i) end
  end
  if not ultimate and groups and groupIndex>#groups and #enemies==0 then
   for p in pairs(participants) do if p.Parent==Players then gold(p,(p:GetAttribute("Gold") or 0)+difficulty.bonus); p:SetAttribute("SpinTokens",(p:GetAttribute("SpinTokens") or 0)+35) end end
   if wave>=Config.TotalWaves then endMatch("Victory") else phase="Intermission"; timer=Rules.intermission(autoSkip,forceNextWave,Config.Intermission); forceNextWave=false; set("Phase",phase); set("Timer",timer) end
  end
 elseif phase=="Victory" or phase=="GameOver" then timer-=dt; set("Timer",math.max(0,math.ceil(timer))); if timer<=0 then clearMatch() end end
end)
-- Соединения отключаются, если серверный скрипт выключен/удалён.
script.Destroying:Connect(function() endUltimate(); baseHealthConnection:Disconnect(); for _,connection in ipairs(connections) do connection:Disconnect() end; for _,connection in pairs(playerConnections) do connection:Disconnect() end end)
