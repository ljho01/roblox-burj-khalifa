local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local ready = game.ReplicatedStorage.SmokeReady
local ok, problem = xpcall(function()
    local service = require(game.ServerScriptService.Game.GameService):Start()
    local config = require(game.ReplicatedStorage.Shared.Config)
    local deadline = os.clock() + 40
    local participants
    repeat
        task.wait(0.2)
        participants = Players:GetPlayers()
    until (#participants == 2 and service.Profiles:Get(participants[1]) and service.Profiles:Get(participants[2]) and participants[1]:GetAttribute("SmokeClientReady") and participants[2]:GetAttribute("SmokeClientReady")) or os.clock() > deadline
    assert(#participants == 2, "Two clients did not connect")
    for _, player in participants do
        assert(player:GetAttribute("SmokeClientReady"), "Client HUD not ready")
        player.Character:PivotTo(CFrame.new(config.Positions.Supply + Vector3.new(0, 4, 3)))
    end
    task.wait(0.5)
    for _, player in participants do ready:FireClient(player, "Collect") end
    task.wait(1)
    for _, player in participants do
        assert(service.Profiles:Get(player).Carry == 8, "Remote pickup failed")
        player.Character:PivotTo(CFrame.new(config.Positions.Build + Vector3.new(0, 4, 3)))
    end
    task.wait(0.5)
    for _, player in participants do ready:FireClient(player, "Build") end
    task.wait(1)
    assert(service.Construction.TotalBuilt == 16, "Shared construction contribution mismatch")
    for _, player in participants do assert(player:GetAttribute("SmokeSawFloorEffects"), "Floor effect or crane lift not replicated to both players") end
    require(game.ServerScriptService.PranksSmoke)(service, participants, ready)
    for index, player in participants do
        local profile = service.Profiles:Get(player)
        assert(profile.Carry == 0 and profile.Coins == 24 and profile.Contributed == 8, "Per-player balances mixed")
        -- Different levels must change loads without changing the NPC count.
        for _ = 1, index * 2 + 1 do
            profile.Coins += config.UpgradeCost("Worker", profile.Worker)
            assert(service:Upgrade(player, "Worker"), "Multiplayer worker hire/upgrade failed")
        end
    end
    task.wait(config.WorkerInterval + 1)
    for _, player in participants do
        assert(player:GetAttribute("SmokeSawWorkers"), "Client did not see its working avatar")
        local profile = service.Profiles:Get(player)
        local capacity = config.WorkerCapacity(profile.Worker)
        assert(profile.Contributed == 8 + capacity and profile.Coins == 24 + capacity * 3, "Upgraded worker rewards mixed or duplicated")
        assert(#service.Workers.Owners[player].Records == 1, "Multiplayer upgrade spawned more than one carrier")
        ready:FireClient(player, "CheckWorkerTeam")
        ready:FireClient(player, "CheckWorkerLoad", capacity)
    end
    local workerDeadline = os.clock() + 10
    repeat task.wait(0.1) until (participants[1]:GetAttribute("SmokeWorkerLoad") and participants[2]:GetAttribute("SmokeWorkerLoad")) or os.clock() > workerDeadline
    for _, player in participants do
        assert(player:GetAttribute("SmokeSawWorkerTeam"), "Other player's worker was not visible")
        assert(player:GetAttribute("SmokeWorkerLoad"), "Upgraded carrier load was not visible to its owner")
    end
    assert(#service.Workers.Folder:GetChildren() == 2, "Two players should have exactly two carriers")
    print("BURJ_WORKERS_MULTIPLAYER_PASSED", #participants)
    -- Fixture for completion: both contributors must receive exactly one reward.
    service:Deposit(participants[1], config.TotalCost(), true)
    for _, player in participants do assert(service.Profiles:Get(player).Wins == 1, "Cooperative completion reward missing") end
    task.wait(1)
    for _, player in participants do ready:FireClient(player, "CheckComplete") end
    task.wait(2)
    for _, player in participants do ready:FireClient(player, "CheckFloorClear") end
    task.wait(.5)
    for _, player in participants do assert(player:GetAttribute("SmokeFloorClear"), "Floor effects leaked on a multiplayer client") end
    for _, player in participants do assert(player:GetAttribute("SmokeSawComplete"), "Completion not replicated to both clients") end
    print("BURJ_MULTIPLAYER_PASSED", #participants, service.Construction.TotalBuilt)
end, debug.traceback)
if not ok then warn("BURJ_MULTIPLAYER_FAILED", problem) end
StudioTestService:EndTest({Passed = ok, Error = tostring(problem)})
