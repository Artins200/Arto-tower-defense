--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local CollectionService=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local config=require(ReplicatedStorage:WaitForChild("Config")); local placement=require(ReplicatedStorage:WaitForChild("Placement"))
local remote=ReplicatedStorage:WaitForChild("TDRequest"); local notice=ReplicatedStorage:WaitForChild("TDNotice"); local state=ReplicatedStorage:WaitForChild("TDState")
local previews=ReplicatedStorage:WaitForChild("UnitPreviews"); local arena=workspace:WaitForChild("TDMap"):WaitForChild("Arena"); local waypointFolder=workspace:WaitForChild("Waypoints"); local towerFolder=workspace:WaitForChild("Towers")
local gui=Instance.new("ScreenGui"); gui.Name="TowerDefenseUI"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local connections={}; local selectedKind=nil; local selectedTower=nil; local ghost=nil; local ghostBase=nil; local ghostBounds=nil; local rangeCircle=nil; local candidate=nil; local candidateValid=false; local touchPoint=nil
local kinds={"Shooter","Cannon","Ice","Sniper"}; local lastTouch=UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local function corner(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 9); c.Parent=o end
local function frame(name,size,pos,parent)
 local f=Instance.new("Frame"); f.Name=name; f.Size=size; f.Position=pos; f.BackgroundColor3=Color3.fromRGB(23,32,42); f.BackgroundTransparency=.06; f.BorderSizePixel=0; f.Parent=parent or gui; corner(f,12); return f
end
local function text(parent,value,size,pos,fontSize)
 local l=Instance.new("TextLabel"); l.Size=size; l.Position=pos; l.BackgroundTransparency=1; l.Text=value; l.TextColor3=Color3.fromRGB(241,246,246); l.Font=Enum.Font.GothamMedium; l.TextSize=fontSize or 16; l.TextWrapped=true; l.Parent=parent; return l
end
local function button(parent,value,size,pos,color)
 local b=Instance.new("TextButton"); b.Size=size; b.Position=pos; b.Text=value; b.BackgroundColor3=color or Color3.fromRGB(70,103,110); b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=15; b.TextWrapped=true; b.AutoButtonColor=true; b.BorderSizePixel=0; b.Parent=parent; corner(b,8); return b
end
local hud=frame("HUD",UDim2.fromOffset(450,90),UDim2.new(.5,-225,0,12)); local hudText=text(hud,"",UDim2.new(1,-16,0,45),UDim2.fromOffset(8,0),15)
local hpBack=frame("BaseHPBar",UDim2.new(1,-22,0,24),UDim2.fromOffset(11,55),hud); hpBack.BackgroundColor3=Color3.fromRGB(59,67,73); hpBack.BackgroundTransparency=0
local hpFill=Instance.new("Frame"); hpFill.Name="Fill"; hpFill.Size=UDim2.fromScale(1,1); hpFill.BorderSizePixel=0; hpFill.BackgroundColor3=Color3.fromRGB(87,211,166); hpFill.Parent=hpBack; corner(hpFill,8)
local hpLabel=text(hpBack,"HP БАЗЫ",UDim2.fromScale(1,1),UDim2.fromOffset(0,0),14); hpLabel.Font=Enum.Font.GothamBold
local hint=frame("Hint",UDim2.fromOffset(240,50),UDim2.new(0,12,0,12)); local hintText=text(hint,"ЛОББИ  •  портал и призыв",UDim2.new(1,-16,1,-8),UDim2.fromOffset(8,4),13)
-- Искусственный инвентарь: карточки с трёхмерными иконками, не Roblox Backpack.
local hotbar=frame("UnitHotbar",UDim2.fromOffset(440,136),UDim2.new(.5,-220,1,-150)); hotbar.Visible=false
local hotbarScale=Instance.new("UIScale"); hotbarScale.Parent=hotbar
local buttons={}; local borders={}; local priceLabels={}
local function makeIcon(parent,kind)
 local viewport=Instance.new("ViewportFrame"); viewport.BackgroundTransparency=1; viewport.Size=UDim2.new(1,-4,0,62); viewport.Position=UDim2.fromOffset(2,9); viewport.Ambient=Color3.fromRGB(200,200,200); viewport.LightColor=Color3.new(1,1,1); viewport.Parent=parent
 local template=previews:WaitForChild(kind,10); if not template then return end
 local model=template:Clone(); model.Parent=viewport; local cf,size=model:GetBoundingBox(); local camera=Instance.new("Camera"); camera.FieldOfView=35; camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(1,.65,-1.6)*math.max(size.X,size.Y,size.Z)*1.5,cf.Position); camera.Parent=viewport; viewport.CurrentCamera=camera
end
for i,kind in ipairs(kinds) do
 local c=config.Towers[kind]; local b=button(hotbar,"",UDim2.fromOffset(98,120),UDim2.fromOffset(8+(i-1)*108,8),Color3.fromRGB(41,56,65)); b.Text=""; buttons[kind]=b
 local stroke=Instance.new("UIStroke"); stroke.Thickness=2; stroke.Color=Color3.fromRGB(76,96,103); stroke.Parent=b; borders[kind]=stroke
 makeIcon(b,kind)
 local number=text(b,tostring(i),UDim2.fromOffset(18,18),UDim2.fromOffset(4,3),12); number.TextColor3=Color3.fromRGB(187,210,208)
 local name=text(b,c.name,UDim2.new(1,-4,0,20),UDim2.fromOffset(2,72),12); name.Font=Enum.Font.GothamBold
 local price=text(b,"",UDim2.new(1,-4,0,20),UDim2.fromOffset(2,96),12); price.TextColor3=c.color; priceLabels[kind]=price
end
local placementHint=text(gui,"",UDim2.fromOffset(480,34),UDim2.new(.5,-240,1,-190),14); placementHint.Visible=false
local mobilePlace=button(gui,"ПОСТАВИТЬ",UDim2.fromOffset(130,42),UDim2.new(.5,-140,1,-242),Color3.fromRGB(58,159,126)); mobilePlace.Visible=false
local cancel=button(gui,"ОТМЕНА",UDim2.fromOffset(130,42),UDim2.new(.5,10,1,-242),Color3.fromRGB(106,90,93)); cancel.Visible=false
local leave=button(gui,"В ЛОББИ",UDim2.fromOffset(130,38),UDim2.new(0,12,0,72),Color3.fromRGB(98,77,84)); leave.Visible=false
connections[#connections+1]=leave.Activated:Connect(function() remote:FireServer("LeaveMatch") end)
local menu=frame("SelectedTower",UDim2.fromOffset(240,150),UDim2.new(1,-252,1,-165)); menu.Visible=false
local menuText=text(menu,"",UDim2.new(1,-16,0,73),UDim2.fromOffset(8,4),14)
local upgrade=button(menu,"УЛУЧШИТЬ",UDim2.new(.5,-12,0,44),UDim2.new(0,8,1,-52),Color3.fromRGB(73,149,132))
local sell=button(menu,"ПРОДАТЬ",UDim2.new(.5,-12,0,44),UDim2.new(.5,4,1,-52),Color3.fromRGB(168,95,86))
connections[#connections+1]=upgrade.Activated:Connect(function() if selectedTower then remote:FireServer("Upgrade",selectedTower) end end)
connections[#connections+1]=sell.Activated:Connect(function() if selectedTower then remote:FireServer("Sell",selectedTower); selectedTower=nil end end)
local start=button(gui,"НАЧАТЬ ВОЛНУ",UDim2.fromOffset(165,42),UDim2.new(1,-177,0,12),Color3.fromRGB(203,137,62)); connections[#connections+1]=start.Activated:Connect(function() remote:FireServer("StartWave") end)
local modal=frame("Modal",UDim2.fromOffset(400,340),UDim2.new(.5,-200,.5,-170)); modal.Visible=false
local modalTitle=text(modal,"",UDim2.new(1,-20,0,68),UDim2.fromOffset(10,8),20); local modalButtons={}
for i=1,4 do modalButtons[i]=button(modal,"",UDim2.new(1,-40,0,44),UDim2.fromOffset(20,74+(i-1)*52)) end
local close=button(modal,"ЗАКРЫТЬ",UDim2.new(1,-40,0,32),UDim2.new(0,20,1,-40),Color3.fromRGB(69,77,87)); connections[#connections+1]=close.Activated:Connect(function() modal.Visible=false end)
local modalMode=""
for i,b in ipairs(modalButtons) do connections[#connections+1]=b.Activated:Connect(function()
 if modalMode=="difficulty" then local keys={"Easy","Normal","Hard","Hardcore"}; remote:FireServer("ChooseDifficulty",keys[i]); modal.Visible=false
 elseif modalMode=="summon" and i==1 then remote:FireServer("Spin") end
end) end
local endScreen=frame("End",UDim2.fromOffset(380,160),UDim2.new(.5,-190,.5,-80)); endScreen.Visible=false; local endText=text(endScreen,"",UDim2.new(1,-20,1,-20),UDim2.fromOffset(10,10),26)
local message=text(gui,"",UDim2.fromOffset(400,36),UDim2.new(.5,-200,0,108),16); local messageId=0
connections[#connections+1]=notice.OnClientEvent:Connect(function(kind,value)
 if kind=="ChooseDifficulty" then modalMode="difficulty"; modal.Visible=true; modalTitle.Text="ВЫБЕРИ СЛОЖНОСТЬ\nОдин общий матч на сервере"; for i,key in ipairs({"Easy","Normal","Hard","Hardcore"}) do modalButtons[i].Visible=true; modalButtons[i].Text=config.Difficulties[key].name end
 elseif kind=="OpenSummon" then modalMode="summon"; modal.Visible=true; modalTitle.Text="ПРИЗЫВ ЮНИТОВ\nЖетонов: "..tostring(player:GetAttribute("SpinTokens") or 0); for i,b in ipairs(modalButtons) do b.Visible=i==1 end; modalButtons[1].Text="КРУТИТЬ  •  "..config.SpinCost.." ЖЕТОНОВ"
 elseif kind=="Message" then messageId+=1; local id=messageId; message.Text=value; if modalMode=="summon" then modalTitle.Text="ПРИЗЫВ ЮНИТОВ\nЖетонов: "..tostring(player:GetAttribute("SpinTokens") or 0) end; task.delay(3,function() if messageId==id then message.Text="" end end) end
end)
local function clearGhost()
 if ghost then ghost:Destroy(); ghost=nil end
 if rangeCircle then rangeCircle:Destroy(); rangeCircle=nil end
 candidate=nil; candidateValid=false; touchPoint=nil
end
local function choose(kind)
 local previous=selectedKind; clearGhost(); selectedTower=nil; selectedKind=nil
 if previous==kind then return end
 if not player:GetAttribute("Unlocked_"..kind) then message.Text="Открой этого юнита через призыв в лобби"; return end
 local template=previews:FindFirstChild(kind); if not template then message.Text="Модель юнита не найдена"; return end
 selectedKind=kind; ghost=template:Clone(); ghost.Name="PlacementPreview"; ghost.Parent=workspace
 for _,d in ghost:GetDescendants() do if d:IsA("BasePart") then d.CanQuery=false; d.CanTouch=false; d.CanCollide=false; d.Anchored=true; if d.Transparency<1 then d.Transparency=.5 end end end
 local cf,size=ghost:GetBoundingBox(); ghostBounds={center=cf.Position,bottom=cf.Position.Y-size.Y/2}; ghostBase=ghost:GetPivot()
 local highlight=Instance.new("Highlight"); highlight.Name="Validity"; highlight.FillTransparency=.75; highlight.OutlineTransparency=0; highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent=ghost
 rangeCircle=Instance.new("Part"); rangeCircle.Name="AttackRange"; rangeCircle.Shape=Enum.PartType.Cylinder; rangeCircle.Anchored=true; rangeCircle.CanCollide=false; rangeCircle.CanQuery=false; rangeCircle.CanTouch=false; rangeCircle.Material=Enum.Material.Neon; rangeCircle.Transparency=.8; rangeCircle.Parent=workspace
end
for kind,b in pairs(buttons) do connections[#connections+1]=b.Activated:Connect(function() choose(kind) end) end
connections[#connections+1]=cancel.Activated:Connect(function() selectedKind=nil; clearGhost() end)
connections[#connections+1]=mobilePlace.Activated:Connect(function() if selectedKind and candidate and candidateValid then remote:FireServer("Place",{kind=selectedKind,position=candidate}) end end)
local function getPoint(screenPoint)
 local camera=workspace.CurrentCamera; if not camera then return nil end
 local ray=camera:ScreenPointToRay(screenPoint.X,screenPoint.Y); local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={arena}; local result=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 return result and result.Position or nil
end
local function updateGhost(point)
 if not ghost or not rangeCircle or not selectedKind then return end
 local position=point and getPoint(point) or nil; candidate=position; candidateValid=false
 if not position then
  for _,d in ghost:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier=1 end end; rangeCircle.Transparency=1; placementHint.Text="Наведите на землю арены"; return
 end
 for _,d in ghost:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier=0 end end
 local waypoints={}; local markers=waypointFolder:GetChildren(); table.sort(markers,function(a,b) return a.Name<b.Name end); for _,p in ipairs(markers) do if p:IsA("BasePart") then table.insert(waypoints,p.Position) end end
 local occupied={}; for _,tower in towerFolder:GetChildren() do local p=tower:GetAttribute("PlacementPosition"); if typeof(p)=="Vector3" then table.insert(occupied,p) end end
 local valid,reason=placement.valid(position,arena,waypoints,occupied)
 if #waypoints<2 then valid=false; reason="Загрузка дорожки..." end
 if (player:GetAttribute("Gold") or 0)<config.Towers[selectedKind].cost then valid=false; reason="Недостаточно золота" end
 candidateValid=valid; local color=valid and Color3.fromRGB(91,245,166) or Color3.fromRGB(255,90,90)
 local highlight=ghost:FindFirstChild("Validity"); highlight.FillColor=color; highlight.OutlineColor=color
 ghost:PivotTo(ghostBase+Vector3.new(position.X-ghostBounds.center.X,position.Y-ghostBounds.bottom,position.Z-ghostBounds.center.Z))
 local radius=config.stats(selectedKind,1).range; rangeCircle.Size=Vector3.new(.12,radius*2,radius*2); rangeCircle.CFrame=CFrame.new(position+Vector3.new(0,.38,0))*CFrame.Angles(0,0,math.pi/2); rangeCircle.Color=color; rangeCircle.Transparency=.82
 placementHint.Text=valid and (lastTouch and "Коснись земли, затем нажми ПОСТАВИТЬ" or "ЛКМ — поставить  •  Esc / ПКМ — отмена") or reason
end
connections[#connections+1]=UserInputService.InputBegan:Connect(function(input,processed)
 if processed or modal.Visible or not player:GetAttribute("InMatch") then return end
 if input.UserInputType==Enum.UserInputType.Touch then lastTouch=true elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 then lastTouch=false end
 if input.KeyCode==Enum.KeyCode.Escape or input.UserInputType==Enum.UserInputType.MouseButton2 then selectedKind=nil; clearGhost(); return end
 for i,key in ipairs({Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,Enum.KeyCode.Four}) do if input.KeyCode==key then choose(kinds[i]); return end end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 local point=Vector2.new(input.Position.X,input.Position.Y)
 if selectedKind then
  if input.UserInputType==Enum.UserInputType.Touch then touchPoint=point; updateGhost(point)
  else updateGhost(point); if candidate and candidateValid then remote:FireServer("Place",{kind=selectedKind,position=candidate}) end end
  return
 end
 local camera=workspace.CurrentCamera; if not camera then return end
 local ray=camera:ScreenPointToRay(point.X,point.Y); local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={player.Character}; local hit=workspace:Raycast(ray.Origin,ray.Direction*1000,params)
 if hit then local model=hit.Instance:FindFirstAncestorOfClass("Model"); if model and CollectionService:HasTag(model,"Tower") then selectedTower=model else selectedTower=nil end else selectedTower=nil end
end)
local function refresh()
 local inMatch=player:GetAttribute("InMatch")==true; local phase=state:GetAttribute("Phase") or "Lobby"; local buildPhase=phase=="Wave" or phase=="Intermission" or phase=="Gathering"
 if (not inMatch or not buildPhase) and selectedKind then selectedKind=nil; clearGhost() end
 hotbar.Visible=inMatch and buildPhase; start.Visible=inMatch and (phase=="Intermission" or phase=="Gathering") and state:GetAttribute("LeaderUserId")==player.UserId; leave.Visible=inMatch; placementHint.Visible=inMatch and selectedKind~=nil; cancel.Visible=placementHint.Visible and lastTouch; mobilePlace.Visible=cancel.Visible
 local hp=state:GetAttribute("BaseHP") or 0; local maxHP=state:GetAttribute("BaseMaxHP") or 0; local fraction=maxHP>0 and math.clamp(hp/maxHP,0,1) or 0
 hpFill.Size=UDim2.fromScale(fraction,1); hpFill.BackgroundColor3=fraction<.3 and Color3.fromRGB(241,91,91) or Color3.fromRGB(87,211,166); hpLabel.Text="HP БАЗЫ  "..hp.." / "..maxHP
 local phaseLabel=phase=="Gathering" and ("СБОР КОМАНДЫ  •  "..tostring(state:GetAttribute("Timer")).."с") or (phase=="Intermission" and ("ДО ВОЛНЫ  "..tostring(state:GetAttribute("Timer")).."с") or tostring(state:GetAttribute("Difficulty") or ""))
 hudText.Text=string.format("ЗОЛОТО %s     •     ВОЛНА %s/%d\n%s",tostring(player:GetAttribute("Gold") or 0),tostring(state:GetAttribute("Wave") or 0),config.TotalWaves,phaseLabel)
 hintText.Text=inMatch and ("КОМАНДА: "..tostring(state:GetAttribute("TeamCount") or 0).."  •  ЛИДЕР: "..tostring(state:GetAttribute("LeaderName") or "")) or "ЛОББИ  •  портал и призыв"
 for kind,b in pairs(buttons) do local c=config.Towers[kind]; local open=player:GetAttribute("Unlocked_"..kind); priceLabels[kind].Text=open and ("◆ "..c.cost) or "ЗАКРЫТО"; b.BackgroundColor3=open and Color3.fromRGB(41,56,65) or Color3.fromRGB(42,43,48); borders[kind].Color=selectedKind==kind and c.color or Color3.fromRGB(76,96,103) end
 menu.Visible=inMatch and selectedTower~=nil and selectedTower.Parent==towerFolder
 if menu.Visible then local kind=selectedTower:GetAttribute("Kind"); local level=selectedTower:GetAttribute("Level"); local spent=selectedTower:GetAttribute("Spent"); if kind and level and spent then menuText.Text=config.Towers[kind].name.."  •  УРОВЕНЬ "..level.."/3\nУлучшение: "..(level<3 and tostring(config.upgradeCost(kind,level)) or "макс.").."  •  Продажа: "..math.floor(spent*config.SellRatio) end end
 endScreen.Visible=inMatch and (phase=="Victory" or phase=="GameOver"); if endScreen.Visible then endText.Text=(phase=="Victory" and "ПОБЕДА!" or "БАЗА ПАЛА").."\nВозвращение в лобби: "..tostring(state:GetAttribute("Timer")).."с" end
 local camera=workspace.CurrentCamera; if camera then hotbarScale.Scale=math.min(1,math.max(.6,(camera.ViewportSize.X-16)/440)); hotbar.Position=UDim2.new(.5,-220*hotbarScale.Scale,1,-150*hotbarScale.Scale) end
end
connections[#connections+1]=state.AttributeChanged:Connect(refresh); connections[#connections+1]=player.AttributeChanged:Connect(refresh)
local elapsed=0; connections[#connections+1]=RunService.RenderStepped:Connect(function(dt)
 if selectedKind and ghost then local point=(lastTouch and touchPoint or (not lastTouch and UserInputService:GetMouseLocation())); updateGhost(point) end
 elapsed+=dt; if elapsed>.2 then elapsed=0; refresh() end
end)
refresh()
script.Destroying:Connect(function() clearGhost(); for _,c in ipairs(connections) do c:Disconnect() end end)
