--!strict
-- Одна геометрия для красного/зелёного предпросмотра и повторной проверки сервером.
local Placement = {}
Placement.RoadHalfWidth = 7
Placement.UnitRadius = 3
Placement.UnitSpacing = 7
function Placement.valid(position: Vector3, arena: BasePart, waypoints: {Vector3}, towers: {Vector3}): (boolean, string)
 local x, z = position.X, position.Z
 if x ~= x or z ~= z or position.Y ~= position.Y or math.abs(x)>10000 or math.abs(z)>10000 or math.abs(position.Y)>10000 then return false, "Некорректная позиция" end
 local top=arena.Position.Y+arena.Size.Y/2
 if math.abs(position.Y-top)>2 then return false, "Выберите землю арены" end
 if math.abs(x-arena.Position.X)>arena.Size.X/2-Placement.UnitRadius or math.abs(z-arena.Position.Z)>arena.Size.Z/2-Placement.UnitRadius then return false, "За пределами арены" end
 local point=Vector2.new(x,z)
 for i=1,#waypoints-1 do
  local a=Vector2.new(waypoints[i].X,waypoints[i].Z); local b=Vector2.new(waypoints[i+1].X,waypoints[i+1].Z); local ab=b-a
  local t=math.clamp((point-a):Dot(ab)/ab:Dot(ab),0,1)
  if (point-(a+ab*t)).Magnitude < Placement.RoadHalfWidth+Placement.UnitRadius then return false, "Нельзя ставить на дорожке" end
 end
 for _,other in ipairs(towers) do if (point-Vector2.new(other.X,other.Z)).Magnitude<Placement.UnitSpacing then return false, "Слишком близко к другому юниту" end end
 return true, ""
end
return Placement
