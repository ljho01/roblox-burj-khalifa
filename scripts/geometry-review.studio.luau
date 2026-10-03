-- Edit-mode geometry regression checks; no production progression is modified.
local config = require(game.ReplicatedStorage.Shared.Config)
local started = os.clock()
local world = require(game.ServerScriptService.Game.World).Create(config)
local parts, structural, cosmetic = 0, 0, 0
for _, p in world.Root:GetDescendants() do
    if p:IsA("BasePart") then parts += 1 end
end
assert(parts < 12000, "Procedural detail budget exceeded")
for _, stage in ipairs({0, 1, 24, 48, 12, 0, 48}) do
    world:SetStage(stage)
    for i = 1, config.MaxStages do
        local floor = world.Tower:FindFirstChild(string.format("Floor %02d", i))
        assert(floor, "Missing construction stage")
        for _, p in floor:GetDescendants() do
            if p:IsA("BasePart") then
                assert((p.Transparency < 1) == (i <= stage), "Floor visibility mismatch")
                if i > stage then assert(not p.CanCollide and not p.CanQuery, "Hidden geometry still blocks players") end
                if p.Name:find("fin") or p.Name:find("edge") or p.Name:find("Spandrel") then
                    assert(not p.CanCollide and not p.CanQuery, "Facade ornament blocks players")
                end
            end
        end
    end
    local beacon = world.Tower["828m Crown"]["Crown beacon"]
    assert((beacon.Transparency == 0) == (stage == config.MaxStages), "Spire visibility mismatch")
    local deck = world.Root["Roof observation deck"]["Observation floor"]
    assert(math.abs(deck.Position.Y - (config.TowerBaseY + stage * config.StageHeight + .4)) < .01, "Lookout height mismatch")
end
for _, p in world.Tower:GetDescendants() do
    if p:IsA("BasePart") then
        if p.CanCollide then structural += 1 else cosmetic += 1 end
    end
end
local beacon = world.Tower["828m Crown"]["Crown beacon"]
assert(math.abs(beacon.Position.Y - config.TowerBaseY - 568) < .01, "Tower scale regressed")
print("BURJ_GEOMETRY_PASSED", "parts", parts, "towerStructural", structural, "towerCosmetic", cosmetic, "seconds", os.clock() - started)
workspace.CurrentCamera.FieldOfView = 48
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(640, 360, 790), Vector3.new(0, 267, 0))
workspace.CurrentCamera.Focus = CFrame.new(0, 267, 0)
