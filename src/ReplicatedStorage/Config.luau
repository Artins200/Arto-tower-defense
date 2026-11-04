--!strict
-- Все цены и характеристики используются сервером; клиент читает их только для отображения.
local Config = {}
Config.StartGold = 450
Config.SpinCost = 200
Config.SellRatio = 0.7
Config.Intermission = 18
Config.TotalWaves = 10
Config.Towers = require(script.Parent.Towers)
Config.Enemies = require(script.Parent.Enemies)
Config.Difficulties = {
 Easy = {name="Легко", hp=0.8, speed=0.9, base=120, bonus=100},
 Normal = {name="Нормально", hp=1, speed=1, base=100, bonus=85},
 Hard = {name="Сложно", hp=1.35, speed=1.1, base=85, bonus=75},
 Hardcore = {name="Хардкорно", hp=1.8, speed=1.2, base=65, bonus=65},
}
-- Очередь состоит из групп: тип, количество и интервал появления.
Config.Waves = require(script.Parent.Waves)
function Config.stats(kind: string, level: number)
 local base = Config.Towers[kind]
 local multiplier = 1 + (level - 1) * 0.55
 return {damage=math.floor(base.damage * multiplier), range=base.range + (level-1)*3, cooldown=base.cooldown * (0.85 ^ (level-1)), splash=base.splash, slow=base.slow, slowDuration=base.slowDuration}
end
function Config.upgradeCost(kind: string, level: number): number
 return math.floor(Config.Towers[kind].cost * (0.8 + (level-1)*0.6))
end
return Config
