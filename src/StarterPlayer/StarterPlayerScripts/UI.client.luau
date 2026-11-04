--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local CollectionService=game:GetService("CollectionService")
local player=Players.LocalPlayer
local config=require(ReplicatedStorage:WaitForChild("Config")); local remote=ReplicatedStorage:WaitForChild("TDRequest"); local notice=ReplicatedStorage:WaitForChild("TDNotice"); local state=ReplicatedStorage:WaitForChild("TDState")
local gui=Instance.new("ScreenGui"); gui.Name="TowerDefenseUI"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local connections={}; local selectedKind="Shooter"; local selectedTower=nil
local function corner(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 9); c.Parent=o end
local function frame(name,size,pos,parent)
 local f=Instance.new("Frame"); f.Name=name; f.Size=size; f.Position=pos; f.BackgroundColor3=Color3.fromRGB(25,34,47); f.BackgroundTransparency=.08; f.BorderSizePixel=0; f.Parent=parent or gui; corner(f,12); return f
end
local function text(parent,value,size,pos,fontSize)
 local l=Instance.new("TextLabel"); l.Size=size; l.Position=pos; l.BackgroundTransparency=1; l.Text=value; l.TextColor3=Color3.fromRGB(241,246,246); l.Font=Enum.Font.GothamMedium; l.TextSize=fontSize or 16; l.TextWrapped=true; l.Parent=parent; return l
end
local function button(parent,value,size,pos,color)
 local b=Instance.new("TextButton"); b.Size=size; b.Position=pos; b.Text=value; b.BackgroundColor3=color or Color3.fromRGB(70,103,110); b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=15; b.TextWrapped=true; b.AutoButtonColor=true; b.BorderSizePixel=0; b.Parent=parent; corner(b,8); return b
end
local hud=frame("HUD",UDim2.new(0,530,0,70),UDim2.new(.5,-265,0,16)); local hudText=text(hud,"",UDim2.new(1,-20,1,0),UDim2.fromOffset(10,0),16)
local hint=frame("Hint",UDim2.fromOffset(310,56),UDim2.new(0,16,0,16)); local hintText=text(hint,"ЛОББИ  •  подойди к порталу или призыву",UDim2.new(1,-16,1,-8),UDim2.fromOffset(8,4),14)
local panel=frame("Towers",UDim2.fromOffset(310,246),UDim2.new(0,16,1,-262)); local panelTitle=text(panel,"ВЫБЕРИ ЮНИТА  •  затем нажми на слот",UDim2.new(1,-16,0,34),UDim2.fromOffset(8,4),14)
local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,5); list.Parent=panel
-- UIListLayout управляет только дочерними GuiObject; заголовок и кнопки идут по порядку.
panelTitle.LayoutOrder=0; panelTitle.Size=UDim2.new(1,-16,0,34)
local buttons={}
for i,kind in ipairs({"Shooter","Cannon","Ice","Sniper"}) do
 local c=config.Towers[kind]; local b=button(panel,"",UDim2.new(1,-16,0,44),UDim2.new(),c.color); b.LayoutOrder=i; b.TextColor3=Color3.fromRGB(25,34,47); buttons[kind]=b
 connections[#connections+1]=b.Activated:Connect(function() if player:GetAttribute("Unlocked_"..kind) then selectedKind=kind; selectedTower=nil else hintText.Text="Открой юнита через призыв в лобби" end end)
end
local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.Parent=panel
local menu=frame("SelectedTower",UDim2.fromOffset(260,160),UDim2.new(1,-276,1,-176)); menu.Visible=false
local menuText=text(menu,"",UDim2.new(1,-16,0,73),UDim2.fromOffset(8,4),15)
local upgrade=button(menu,"УЛУЧШИТЬ",UDim2.new(.5,-12,0,48),UDim2.new(0,8,1,-56),Color3.fromRGB(73,149,132))
local sell=button(menu,"ПРОДАТЬ",UDim2.new(.5,-12,0,48),UDim2.new(.5,4,1,-56),Color3.fromRGB(168,95,86))
connections[#connections+1]=upgrade.Activated:Connect(function() if selectedTower then remote:FireServer("Upgrade",selectedTower) end end)
connections[#connections+1]=sell.Activated:Connect(function() if selectedTower then remote:FireServer("Sell",selectedTower); selectedTower=nil end end)
local start=button(gui,"НАЧАТЬ ВОЛНУ",UDim2.fromOffset(180,44),UDim2.new(1,-196,0,16),Color3.fromRGB(224,147,67)); connections[#connections+1]=start.Activated:Connect(function() remote:FireServer("StartWave") end)
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
local message=text(gui,"",UDim2.fromOffset(400,36),UDim2.new(.5,-200,0,95),16); local messageId=0
connections[#connections+1]=notice.OnClientEvent:Connect(function(kind,value)
 if kind=="ChooseDifficulty" then modalMode="difficulty"; modal.Visible=true; modalTitle.Text="ВЫБЕРИ СЛОЖНОСТЬ\nОдин общий матч на сервере"; for i,key in ipairs({"Easy","Normal","Hard","Hardcore"}) do modalButtons[i].Visible=true; modalButtons[i].Text=config.Difficulties[key].name end
 elseif kind=="OpenSummon" then modalMode="summon"; modal.Visible=true; modalTitle.Text="ПРИЗЫВ ЮНИТОВ\nЖетонов: "..tostring(player:GetAttribute("SpinTokens") or 0); for i,b in ipairs(modalButtons) do b.Visible=i==1 end; modalButtons[1].Text="КРУТИТЬ  •  "..config.SpinCost.." ЖЕТОНОВ"
 elseif kind=="Message" then messageId+=1; local id=messageId; message.Text=value; if modalMode=="summon" then modalTitle.Text="ПРИЗЫВ ЮНИТОВ\nЖетонов: "..tostring(player:GetAttribute("SpinTokens") or 0) end; task.delay(3,function() if messageId==id then message.Text="" end end) end
end)
-- Локальный raycast лишь выбирает объект; владение, расстояние и стоимость проверяет сервер.
connections[#connections+1]=UserInputService.InputBegan:Connect(function(input,processed)
 if processed or not player:GetAttribute("InMatch") then return end
 if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
 local camera=workspace.CurrentCamera; if not camera then return end
 local point=Vector2.new(input.Position.X,input.Position.Y); local ray=camera:ViewportPointToRay(point.X,point.Y); local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={player.Character}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params); if not hit then return end
 if hit.Instance.Parent==workspace.Plots then remote:FireServer("Place",{kind=selectedKind,plot=hit.Instance}); selectedTower=nil; return end
 local model=hit.Instance:FindFirstAncestorOfClass("Model"); if model and CollectionService:HasTag(model,"Tower") then selectedTower=model else selectedTower=nil end
end)
local function refresh()
 local inMatch=player:GetAttribute("InMatch")==true; local phase=state:GetAttribute("Phase") or "Lobby"; panel.Visible=inMatch; start.Visible=inMatch and phase=="Intermission"
 hudText.Text=string.format("БАЗА %s/%s     •     ЗОЛОТО %s     •     ВОЛНА %s/%d\n%s  %s",tostring(state:GetAttribute("BaseHP") or 0),tostring(state:GetAttribute("BaseMaxHP") or 0),tostring(player:GetAttribute("Gold") or 0),tostring(state:GetAttribute("Wave") or 0),config.TotalWaves,tostring(state:GetAttribute("Difficulty") or ""),phase=="Intermission" and ("  •  старт через "..tostring(state:GetAttribute("Timer")).."с") or "")
 hintText.Text=inMatch and "Подойди к слоту или своей башне на 35 studs" or "ЛОББИ  •  подойди к порталу или призыву"
 for kind,b in pairs(buttons) do local c=config.Towers[kind]; local open=player:GetAttribute("Unlocked_"..kind); b.Text=(selectedKind==kind and "▶ " or "")..c.name.."  •  "..c.cost.."  |  "..(open and c.description or "закрыт") end
 menu.Visible=inMatch and selectedTower~=nil and selectedTower.Parent==workspace.Towers
 if menu.Visible then local kind=selectedTower:GetAttribute("Kind"); local level=selectedTower:GetAttribute("Level"); local spent=selectedTower:GetAttribute("Spent"); menuText.Text=config.Towers[kind].name.."  •  УРОВЕНЬ "..level.."/3\nУлучшение: "..(level<3 and tostring(config.upgradeCost(kind,level)) or "макс.").."  •  Продажа: "..math.floor(spent*config.SellRatio) end
 endScreen.Visible=inMatch and (phase=="Victory" or phase=="GameOver"); if endScreen.Visible then endText.Text=(phase=="Victory" and "ПОБЕДА!" or "БАЗА ПАЛА").."\nВозвращение в лобби: "..tostring(state:GetAttribute("Timer")).."с" end
end
connections[#connections+1]=state.AttributeChanged:Connect(refresh); connections[#connections+1]=player.AttributeChanged:Connect(refresh)
local RunService=game:GetService("RunService"); local elapsed=0; connections[#connections+1]=RunService.RenderStepped:Connect(function(dt) elapsed+=dt; if elapsed>.2 then elapsed=0; refresh() end end)
refresh()
script.Destroying:Connect(function() for _,c in ipairs(connections) do c:Disconnect() end end)
