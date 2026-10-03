-- Isolated art integration probe; separate output avoids other active Studio tests.
local probe = Instance.new("Script")
probe.Name = "ArtIntegrationSmoke"
probe.Source = [====[
local ok, problem = xpcall(function()
    local config = require(game.ReplicatedStorage.Shared.Config)
    local service = require(game.ServerScriptService.Game.GameService):Start()
    local deadline = os.clock() + 40
    local player
    repeat
        task.wait(.1)
        player = game.Players:GetPlayers()[1]
    until (player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and service.Profiles:Get(player)) or os.clock() > deadline
    assert(player and player.Character and service.Profiles:Get(player), "Player did not initialize")
    local path = game:GetService("PathfindingService"):CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})
    local function route(from, to)
        path:ComputeAsync(from, to)
        assert(path.Status == Enum.PathStatus.Success, "Art blocks an interaction route")
        print("BURJ_ART_ROUTE", #path:GetWaypoints())
    end
    local function action(kind, key)
        task.wait(config.ActionCooldown + .2)
        assert(service:HandleAction(player, kind, key), "Interaction failed: " .. kind)
    end
    local function go(key)
        player.Character:PivotTo(CFrame.new(config.Positions[key] + Vector3.new(0, 4, 2)))
        task.wait(.3)
    end
    route(config.Positions.Spawn, config.Positions.Supply)
    route(config.Positions.Supply, config.Positions.Build)
    go("Supply")
    action("Interact", "Supply")
    go("Build")
    action("Interact", "Build")
    assert(service.Construction.Stage == 1, "First floor not built")
    service:Deposit(player, config.TotalCost(), true)
    assert(service.Construction.Complete, "Tower not completed")
    route(config.Positions.Supply, config.Positions.Build)
    route(config.Positions.Build, config.Positions.Lookout)
    go("Lookout")
    action("Interact", "Lookout")
    task.wait(.6)
    assert(player.Character:GetPivot().Position.Y > config.TowerBaseY + config.MaxStages * config.StageHeight, "Avatar fell through rooftop")
    action("Return")
    assert((player.Character:GetPivot().Position - config.Positions.Spawn).Magnitude < 2, "Return destination incorrect")
    service.ResetAt = os.clock() - 1
    task.wait(1.2)
    assert(service.Construction.Stage == 0, "Round did not reset")
    for _, p in service.World.Tower["Floor 48"]:GetDescendants() do
        if p:IsA("BasePart") then assert(p.Transparency == 1 and not p.CanCollide, "Reset leaves phantom tower") end
    end
    print("BURJ_ART_PLAY_PASSED", "pickup, deposit, full tower routes, rooftop, return, reset")
end, debug.traceback)
if not ok then warn("BURJ_ART_PLAY_FAILED", problem) end
game:GetService("StudioTestService"):EndTest({Passed = ok, Error = tostring(problem)})
]====]
probe.Parent = game.ServerScriptService
local result = game:GetService("StudioTestService"):ExecutePlayModeAsync({ArtSmoke = true})
print("BURJ_ART_TEST_RESULT", result and result.Passed, result and result.Error)
assert(result and result.Passed, result and result.Error or "Missing result")
