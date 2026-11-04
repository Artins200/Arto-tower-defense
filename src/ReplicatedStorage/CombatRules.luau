--!strict
-- Чистые правила времени: их можно тестировать вне Roblox Studio.
local Rules = {}
function Rules.readyAt(roundStartedAt: number?, placedAt: number, cooldown: number): number
 if not roundStartedAt then return 0 end
 return math.max(roundStartedAt, placedAt) + cooldown
end
function Rules.canUltimate(phase: string, active: boolean, now: number, readyAt: number, targets: number): boolean
 return phase=="Wave" and not active and readyAt>0 and now>=readyAt and targets>0
end
function Rules.intermission(autoSkip: boolean, forceNext: boolean, duration: number): number
 return (autoSkip or forceNext) and 0 or duration
end
function Rules.sniperSplit(count: number): number
 return math.max(0,math.floor((count-1)/2))
end
return Rules
