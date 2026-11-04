--!strict
-- Клиент и сервер используют одну геометрию, но сервер проверяет запрос заново.
local Placement = {}
Placement.RoadHalfWidth = 7 -- граница видимого бордюра
function Placement.valid(position: Vector3, arena: BasePart, waypoints: {Vector3}, spawn: BasePart, footprint: Vector2?): (boolean, string)
 local x,z=position.X,position.Z
 if x~=x or z~=z or position.Y~=position.Y or math.abs(x)>10000 or math.abs(z)>10000 or math.abs(position.Y)>10000 then return false,"Некорректная позиция" end
 local top=arena.Position.Y+arena.Size.Y/2
 if math.abs(position.Y-top)>2 then return false,"Выберите землю арены" end
 -- Проверяем именно точку установки, без невидимого отступа от края.
 local halfX=footprint and footprint.X or 0; local halfZ=footprint and footprint.Y or 0
 if math.abs(x-arena.Position.X)+halfX>arena.Size.X/2 or math.abs(z-arena.Position.Z)+halfZ>arena.Size.Z/2 then return false,"За пределами арены" end
 if math.abs(x-spawn.Position.X)<=spawn.Size.X/2 and math.abs(z-spawn.Position.Z)<=spawn.Size.Z/2 then return false,"Нельзя ставить на спавне" end
 local point=Vector2.new(x,z)
 for i=1,#waypoints-1 do
  local a=Vector2.new(waypoints[i].X,waypoints[i].Z); local b=Vector2.new(waypoints[i+1].X,waypoints[i+1].Z); local ab=b-a; local length=ab.Magnitude
  if length>0 then
   -- У дороги прямоугольные сегменты с бордюром и квадратными концами.
   local direction=ab/length; local relative=point-a; local along=relative:Dot(direction); local across=math.abs(relative.X*direction.Y-relative.Y*direction.X)
   if along>=-Placement.RoadHalfWidth and along<=length+Placement.RoadHalfWidth and across<=Placement.RoadHalfWidth then return false,"Нельзя ставить на дорожке" end
  end
 end
 return true,""
end
return Placement
