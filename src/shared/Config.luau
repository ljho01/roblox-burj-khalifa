local Config = {}
Config.Title = "Build the Burj"
Config.MaxStages = 48
Config.HeightMeters = 828
Config.TowerBaseY = 3
Config.StageHeight = 10
Config.SpireHeight = 88
Config.TowerWidthScale = 1.65
Config.StartCoins = 0
Config.BaseCapacity = 8
Config.MaxUpgradeLevel = 20
Config.InteractionDistance = 19
Config.ActionCooldown = 0.45
Config.WorkerInterval = 8
Config.CelebrationSeconds = 35
Config.DepositDuration = 1.1
function Config.StealDuration(amount)
    if amount <= 0 then return 0 end
    return Config.DepositDuration * 2 * math.log(1 + amount) / math.log(1 + Config.BaseCapacity)
end
Config.Positions = {
    Supply = Vector3.new(-104, 3, 100),
    Build = Vector3.new(0, 3, 52),
    Steal = Vector3.new(32, 3, 60),
    Trash = Vector3.new(112, 3, 112),
    Strength = Vector3.new(65, 3, 97),
    Speed = Vector3.new(112, 3, 34),
    Worker = Vector3.new(-112, 3, 34),
    Lookout = Vector3.new(42, 3, -52),
    Spawn = Vector3.new(-72, 5, 126),
}
Config.UpgradeNames = {Strength = "운반력", Speed = "이동 속도", Worker = "자동 작업자"}
function Config.StageCost(stage) return 8 + (stage - 1) * 2 end
function Config.TotalCost()
    local total = 0
    for stage = 1, Config.MaxStages do total += Config.StageCost(stage) end
    return total
end
function Config.Capacity(level) return Config.BaseCapacity + level * 6 end
function Config.WorkerCapacity(level) return math.clamp(math.floor(level), 0, Config.MaxUpgradeLevel) * 2 end
function Config.WalkSpeed(level) return 18 + level * 1.2 end
function Config.UpgradeCost(kind, level)
    local base = ({Strength = 35, Speed = 45, Worker = 100})[kind]
    if not base then return nil end
    return math.floor(base * 1.45 ^ level)
end
return Config
