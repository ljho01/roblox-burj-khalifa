local Players = game:GetService("Players")
local TestService = game:GetService("StudioTestService")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local ok, problem = xpcall(function()
    local service = require(game.ServerScriptService.Game.GameService):Start()
    local Config = require(game.ReplicatedStorage.Shared.Config)
    local deadline = os.clock() + 35
    local player
    repeat
        task.wait(0.1)
        player = Players:GetPlayers()[1]
    until (player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and service.Profiles:Get(player)) or os.clock() > deadline
    assert(player and player.Character and service.Profiles:Get(player), "Player did not initialize")
    local profile = service.Profiles:Get(player)
    local crane = service.World.Crane
    local foundationPosition = crane.Model["Crane foundation"].Position
    assert(crane.Height.Value == crane:HeightForStage(0), "Crane did not start near the foundation")
    require(game.ServerScriptService.WorkersSmoke)()
    local function countBricks()
        local stack = player.Character:FindFirstChild("CarriedMaterials")
        local count = 0
        if stack then
            for _, child in stack:GetChildren() do
                if child.Name == "MaterialBrick" then
                    assert(not child.CanCollide and child.Massless, "Carry blocks affect avatar physics")
                    count += 1
                end
            end
        end
        return count
    end
    local function action(kind, value)
        task.wait(Config.ActionCooldown + 0.1)
        return service:HandleAction(player, kind, value)
    end
    local function go(station)
        player.Character:PivotTo(CFrame.new(service.World.Stations[station].Position + Vector3.new(0, 4, 4)))
        task.wait(0.2)
    end
    assert(profile.Saved == false, "Studio must not access production persistence")
    assert((Config.Positions.Supply - Config.Positions.Build).Magnitude > 110, "Supply and build are not separated")
    local plaza = service.World.Root:FindFirstChild("Plaza", true)
    assert(plaza and plaza.Size.X >= 340 and plaza.Size.Z >= 340, "Construction site was not doubled")
    local path = game:GetService("PathfindingService"):CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})
    path:ComputeAsync(Config.Positions.Supply, Config.Positions.Build)
    assert(path.Status == Enum.PathStatus.Success, "Expanded delivery route is not traversable")
    print("BURJ_DELIVERY_ROUTE_PASSED", (Config.Positions.Supply - Config.Positions.Build).Magnitude, #path:GetWaypoints())
    player.Character:PivotTo(CFrame.new(0, 5, 100))
    assert(not action("Interact", "Supply"), "Out-of-range pickup accepted")
    assert(not action("Upgrade", "Bogus"), "Invalid upgrade accepted")
    assert(not service:HandleAction(player, {}, {}), "Invalid payload accepted")
    go("Supply")
    assert(action("Interact", "Supply"), "Pickup failed")
    assert(profile.Carry == 8, "Wrong starting capacity")
    assert(countBricks() == 8, "Starting carried stack does not show each material")
    assert(not service:IsNear(player, "Build"), "Supply zone overlaps deposit zone")
    assert(not service:HandleAction(player, "Interact", "Supply"), "Cooldown bypass")
    go("Build")
    assert(action("Interact", "Build"), "Deposit failed")
    assert(service.Construction.Stage == 1 and profile.Carry == 0 and profile.Coins == 24, "First construction reward mismatch")
    assert(player:GetAttribute("Depositing") and countBricks() == 0, "Deposit did not release stack into animation")
    local craneStart, craneTarget = crane:HeightForStage(0), crane:HeightForStage(1)
    assert(crane.Model:GetAttribute("TargetHeight") == craneTarget, "Construction did not raise the crane target")
    task.wait(.25)
    assert(crane.Height.Value > craneStart and crane.Height.Value < craneTarget, "Crane skipped its smooth lift")
    task.wait(.6)
    assert(math.abs(crane.Head:GetPivot().Position.Y - craneTarget) < .01, "Crane cabin and jib did not reach the floor")
    assert(not action("Interact", "Build"), "Empty deposit accepted")
    go("Supply"); assert(action("Interact", "Supply"))
    go("Build"); assert(action("Interact", "Build"))
    assert(action("Upgrade", "Strength"), "Strength upgrade failed")
    assert(profile.Strength == 1 and profile.Coins == 13, "Upgrade balance mismatch")
    go("Supply"); assert(action("Interact", "Supply"))
    assert(profile.Carry == 14, "Upgraded capacity mismatch")
    assert(countBricks() == 14, "Upgraded carried stack did not grow")
    assert(player.Character.CarriedMaterials:GetAttribute("LayerCount") == 4, "Stack height did not grow with capacity")
    go("Build"); assert(action("Interact", "Build"))
    assert(action("Upgrade", "Speed"), "Speed upgrade failed")
    assert(math.abs(player.Character.Humanoid.WalkSpeed - Config.WalkSpeed(1)) < 0.001, "Speed did not apply")
    go("Lookout"); assert(action("Interact", "Lookout"), "Lookout teleport failed")
    assert(player.Character:GetPivot().Position.Y > 10, "Lookout height invalid")
    assert(action("Return"), "Return failed")
    assert((player.Character:GetPivot().Position - Config.Positions.Spawn).Magnitude < 2, "Return position mismatch")
    profile.Coins += 100 -- Fixture to exercise worker without repetitive grinding.
    assert(action("Upgrade", "Worker"), "Worker hire failed")
    assert(#service.Workers.Owners[player].Records == 1, "Hiring did not spawn a visible worker")
    local before = profile.Contributed
    task.wait(Config.WorkerInterval + 1)
    print("BURJ_WORKER_ROSTER", player:GetAttribute("WorkerRosterStatus"), #service.Workers.Owners[player].Friends, service.Workers.Owners[player].Records[1].Model:GetAttribute("AvatarSource"))
    assert(profile.Contributed > before, "Worker did not contribute automatically")
    assert(player:GetAttribute("SmokeSawWorkers"), "Worker did not visibly carry and unload materials on client")
    local carrier = service.Workers.Owners[player].Records[1]
    local sameAvatar = carrier.Model
    for _ = 1, 2 do
        profile.Coins += Config.UpgradeCost("Worker", profile.Worker)
        assert(action("Upgrade", "Worker"), "Carrier load upgrade failed")
    end
    assert(#service.Workers.Owners[player].Records == 1 and carrier.Model == sameAvatar, "Upgrading replaced or multiplied the carrier")
    game.ReplicatedStorage.SmokeReady:FireClient(player, "CheckWorkerLoad", 6)
    local loadDeadline = os.clock() + 10
    repeat task.wait(0.1) until player:GetAttribute("SmokeWorkerLoad") or os.clock() > loadDeadline
    assert(player:GetAttribute("SmokeWorkerLoad"), "Upgraded load was not visible and hidden during the correct phases")
    print("BURJ_SINGLE_CARRIER_UPGRADE_PASSED", profile.Worker, carrier.Model:GetAttribute("Capacity"))
    print("BURJ_SMOKE_GAMEPLAY_OK", profile.Contributed)
    local wins = profile.Wins
    service:Deposit(player, Config.TotalCost(), true)
    assert(service.Construction.Complete and service.Construction.Stage == Config.MaxStages, "Tower completion failed")
    assert(profile.Wins == wins + 1, "Completion reward missing")
    assert(service:Deposit(player, 5, true) == 0 and profile.Wins == wins + 1, "Duplicate completion reward")
    assert(service:Snapshot(player).ResetIn > 0, "Reset countdown missing")
    task.wait(2.7)
    assert(math.abs(crane.Height.Value - crane:HeightForStage(Config.MaxStages)) < .01, "Crane did not rise above the completed spire")
    assert(crane.Model["Crane foundation"].Position == foundationPosition, "Crane foundation floated away")
    game.ReplicatedStorage.SmokeReady:FireClient(player, "CheckFloorClear")
    local effectsDeadline = os.clock() + 3
    repeat task.wait(.05) until player:GetAttribute("SmokeFloorClear") or os.clock() > effectsDeadline
    assert(player:GetAttribute("SmokeFloorClear"), "Completed floor effects did not clean up")
    service.ResetAt = os.clock() - 1
    task.wait(1.2)
    assert(not service.Construction.Complete and service.Construction.Stage == 0 and service.Construction.Round == 2, "Round reset failed")
    assert(crane.Height.Value == craneStart and crane.Head:GetPivot().Position.Y == craneStart, "Crane did not reset for the new round")
    crane:SetStage(30, true)
    task.wait(.1)
    crane:SetStage(0, false)
    task.wait(.15)
    assert(crane.Height.Value == craneStart, "Cancelled lift continued after reset")
    print("BURJ_CRANE_PROGRESS_PASSED", "smooth first floor, full spire, fixed foundation, reset, cancellation")
    assert(profile.Strength == 1 and profile.Speed == 1 and profile.Worker == 3 and profile.Wins == wins + 1, "Reset erased progression")
    print("BURJ_SMOKE_COMPLETION_RESET_OK")
    local previousStrength, previousCarry = profile.Strength, profile.Carry
    profile.Strength, profile.Carry = Config.MaxUpgradeLevel, Config.Capacity(Config.MaxUpgradeLevel)
    service:CarryVisual(player)
    assert(countBricks() == 128, "High level stack is still visually capped")
    assert(player.Character.CarriedMaterials:GetAttribute("LayerCount") == 32, "High level stack height mismatch")
    profile.Strength, profile.Carry = previousStrength, previousCarry
    service:CarryVisual(player)
    print("BURJ_STACK_VISUALS_PASSED", 8, 14, 128)
    -- The client probe reports whether the actual production LocalScript initialized.
    local clientDeadline = os.clock() + 10
    repeat task.wait(0.1) until player:GetAttribute("SmokeClientReady") or os.clock() > clientDeadline
    assert(player:GetAttribute("SmokeClientReady"), "Production client UI did not initialize")
    assert(player:GetAttribute("SmokeSawAnimation"), "Deposit animation did not run on the client")
    assert(player:GetAttribute("SmokeSawFloorEffects"), "Floor dust and crane movement did not reach the client")
    print("BURJ_SMOKE_ALL_PASSED")
end, debug.traceback)
if not ok then warn("BURJ_SMOKE_FAILED", problem) end
TestService:EndTest({Passed = ok, Error = tostring(problem)})
