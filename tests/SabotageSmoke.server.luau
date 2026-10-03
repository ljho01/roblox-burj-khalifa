local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local ready = game.ReplicatedStorage.SmokeReady
local ok, problem = xpcall(function()
    local service = require(game.ServerScriptService.Game.GameService):Start()
    local config = require(game.ReplicatedStorage.Shared.Config)
    local rules = require(game.ServerScriptService.Game.Construction)
    local function untilTrue(predicate, message, seconds)
        local deadline = os.clock() + (seconds or 5)
        repeat task.wait(.05) until predicate() or os.clock() >= deadline
        assert(predicate(), message)
    end
    -- Conservation across interleaved reservations, returns, disposal and deposits.
    local state, expected = rules.new(), 0
    local random = Random.new(9026)
    for _ = 1, 1000 do
        local id, operation = random:NextInteger(1, 8), random:NextInteger(1, 4)
        if operation == 1 then expected += rules.Deposit(state, random:NextInteger(1, 12), id)
        elseif operation == 2 then rules.Reserve(state, random:NextInteger(1, 128), id)
        elseif operation == 3 then expected -= rules.Discard(state, id, state.Round)
        else rules.Release(state, id) end
        local reserved, built = 0, state.StageProgress
        for _, reservation in state.Reservations do reserved += reservation.Amount end
        for stage = 1, state.Stage do built += config.StageCost(stage) end
        assert(state.TotalBuilt == expected and built == expected, "Construction total diverged")
        assert(state.Reserved == reserved and reserved <= expected and reserved >= 0, "Materials reserved twice")
    end
    state = rules.new()
    rules.Deposit(state, 18, 1)
    assert(rules.Reserve(state, 14, 1) == 14 and rules.Reserve(state, 14, 2) == 4, "Concurrent capacity clamp failed")
    assert(rules.Reserve(state, 14, 1) == 0 and rules.Reserve(state, 14, 3) == 0, "Duplicate reservation allowed")
    assert(rules.Discard(state, 1, state.Round - 1) == 0 and state.TotalBuilt == 18, "Stale disposal changed tower")
    assert(rules.Discard(state, 1, state.Round) == 14 and rules.Discard(state, 1, state.Round) == 0, "Disposal applied twice")
    assert(state.TotalBuilt == 4 and state.Stage == 0 and state.StageProgress == 4, "Multi-floor rollback failed")
    rules.Reset(state)
    assert(state.Reserved == 0 and not next(state.Reservations), "Round reset left reservations")
    assert(rules.Reserve(state, math.huge, 1) == 0 and rules.Reserve(state, 0/0, 1) == 0, "Invalid quantities accepted")
    print("BURJ_SABOTAGE_ACCOUNTING_PASSED", 1000)
    local participants
    untilTrue(function()
        participants = Players:GetPlayers()
        if #participants ~= 2 then return false end
        for _, player in participants do
            if not service.Profiles:Get(player) or not player:GetAttribute("SmokeClientReady") then return false end
        end
        return true
    end, "Two clients not ready", 45)
    local first, second = participants[1], participants[2]
    local a, b = service.Profiles:Get(first), service.Profiles:Get(second)
    b.Strength = 1
    local function go(player, key, offset)
        player.Character.HumanoidRootPart.Anchored = true
        player.Character:PivotTo(CFrame.new(config.Positions[key] + (offset or Vector3.new(0, 2, 4))))
        service.LastAction[player] = nil
    end
    local function action(player, key)
        service.LastAction[player] = nil
        if key == "Steal" then return service:HandleAction(player, "BeginSteal") end
        return service:HandleAction(player, "Interact", key)
    end
    local function extract(player)
        go(player, "Steal")
        assert(action(player, "Steal"), "Extraction did not start")
        local pending = service.Sabotage.Pending[player]
        assert(not service:HandleAction(player, "FinishSteal"), "Instant finish bypassed server timer")
        task.wait(pending.Duration + .05)
        assert(service.Profiles:Get(player).Carry == 0, "Beginning a hold granted materials automatically")
        assert(service:HandleAction(player, "FinishSteal"), "A completed hold did not grant immediately")
        assert(service.Profiles:Get(player).StolenRound ~= nil and not service.Sabotage.Pending[player], "Finish started another wait phase")
    end
    assert(math.abs(config.StealDuration(8) - 2.2) < .001, "Base hold duration changed")
    local lastDuration, lastIncrease = config.StealDuration(1), math.huge
    for count = 2, 128 do
        local duration = config.StealDuration(count)
        local increase = duration - lastDuration
        assert(increase > 0 and increase < lastIncrease, "Hold duration is not logarithmic")
        lastDuration, lastIncrease = duration, increase
    end
    assert(config.StealDuration(0) == 0 and config.StealDuration(128) < 5, "Hold duration endpoints wrong")
    assert((config.Positions.Steal - config.Positions.Trash).Magnitude > 80, "Disposal does not require a trip")
    assert(service.World.Root["Dubai Plaza"]:FindFirstChild("MaterialTrashBin"), "Trash bin missing")
    local path = game:GetService("PathfindingService"):CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})
    path:ComputeAsync(config.Positions.Steal + Vector3.new(0, 1, 4), config.Positions.Trash + Vector3.new(0, 1, 4))
    assert(path.Status == Enum.PathStatus.Success, "Bin is not reachable on foot")
    service:Deposit(first, 30, true)
    go(first, "Steal")
    assert(not service:HandleAction(first, "Interact", "Steal"), "Legacy click still starts auto extraction")
    assert(not service:HandleAction(first, "FinishSteal"), "Finish without a begin was accepted")
    go(first, "Steal", Vector3.new(-3, 2, 4))
    go(second, "Steal", Vector3.new(3, 2, 4))
    service:Sync(second)
    task.wait(.5)
    ready:FireClient(first, "Steal"); ready:FireClient(second, "Steal")
    untilTrue(function() return service.Construction.Reserved == 22 end, "Remote concurrent extraction failed")
    local firstEnd = service.Sabotage.Pending[first].EndsAt
    task.wait(config.DepositDuration)
    assert(a.Carry == 0 and b.Carry == 0 and service.Construction.TotalBuilt == 30, "Materials granted or deducted too early")
    untilTrue(function() return a.Carry == 8 and b.Carry == 14 end, "Bag capacities wrong")
    assert(workspace:GetServerTimeNow() >= firstEnd and service.Construction.TotalBuilt == 30, "Timing or deferred deduction failed")
    for _, player in participants do ready:FireClient(player, "CheckBag") end
    untilTrue(function() return first:GetAttribute("SmokeStolenBag") and second:GetAttribute("SmokeStolenBag") end, "Stolen bag UI missing")
    untilTrue(function() return first:GetAttribute("SmokeHoldImmediate") and second:GetAttribute("SmokeHoldImmediate") end, "Native hold did not grant immediately on both clients")
    for _, player in participants do
        assert(player:GetAttribute("SmokeTheftFX") and player:GetAttribute("SmokeTheftUI"), "Extraction animation/UI missing")
    end
    assert(not action(first, "Trash") and service.Construction.TotalBuilt == 30, "Remote trash shortcut accepted")
    go(first, "Build")
    assert(not action(first, "Build") and service:Deposit(first, 8, false) == 0, "Stolen materials earned coins")
    go(first, "Supply")
    assert(not action(first, "Supply") and a.Carry == 8, "Supply replaced stolen cargo")
    local coins, contributions = a.Coins, a.Contributed
    local crane = service.World.Crane
    local height = crane.Height.Value
    go(first, "Trash")
    task.wait(.2)
    ready:FireClient(first, "Trash")
    untilTrue(function() return service.Construction.TotalBuilt == 22 end, "Client disposal failed")
    task.wait(.2)
    assert(crane.Height.Value < height and crane.Height.Value > crane:HeightForStage(2), "Crane did not animate down")
    assert(service.Construction.Stage == 2 and service.Construction.StageProgress == 4 and service.Construction.Reserved == 14, "Discard damaged another player's reservation")
    assert(a.Carry == 0 and not a.StolenRound and a.Coins == coins and a.Contributed == contributions, "Discard changed personal reward")
    assert(not action(first, "Trash") and service.Construction.TotalBuilt == 22, "Duplicate trash action deducted twice")
    go(second, "Trash")
    ready:FireClient(second, "Trash")
    untilTrue(function() return service.Construction.TotalBuilt == 8 end, "Second disposal failed")
    assert(service.Construction.Stage == 1 and service.Construction.StageProgress == 0 and service.Construction.Reserved == 0, "Two bags did not conserve construction")
    task.wait(1.5)
    for _, player in participants do
        assert(player:GetAttribute("SmokeTrashFX"), "Trash animation not visible to both clients")
        ready:FireClient(player, "BeforeRebuild")
    end
    task.wait(.3)
    service:Deposit(first, 22, true)
    task.wait(.5)
    for _, player in participants do ready:FireClient(player, "AfterRebuild") end
    untilTrue(function() return first:GetAttribute("SmokeRebuiltFX") and second:GetAttribute("SmokeRebuiltFX") end, "Rebuild effects not replayed")
    -- Moving cancels extraction and releases the reservation.
    go(first, "Steal")
    assert(action(first, "Steal"))
    task.wait(.3)
    first.Character:PivotTo(first.Character:GetPivot() + Vector3.new(6, 0, 0))
    untilTrue(function() return not service.Sabotage.Pending[first] end, "Moving did not cancel extraction")
    assert(service.Construction.Reserved == 0 and a.Carry == 0 and service.Construction.TotalBuilt == 30, "Cancelled extraction lost materials")
    -- Actual native E/touch hold must cancel on release, without accumulating time.
    go(first, "Steal")
    task.wait(.3)
    ready:FireClient(first, "Steal")
    untilTrue(function() return service.Sabotage.Pending[first] ~= nil end, "Native cancellation hold did not begin")
    task.wait(.45)
    ready:FireClient(first, "ReleaseSteal")
    untilTrue(function() return service.Sabotage.Pending[first] == nil end, "Releasing native hold did not cancel")
    task.wait(config.StealDuration(8) + .2)
    assert(a.Carry == 0 and service.Construction.Reserved == 0, "Released hold later granted a bag")
    -- Per-player native prompts must retime to the reserved amount, including
    -- stale client estimates during a simultaneous multiplayer pickup.
    go(first, "Steal", Vector3.new(-3, 2, 4))
    go(second, "Steal", Vector3.new(3, 2, 4))
    b.Strength = config.MaxUpgradeLevel
    service:Sync(second)
    assert(action(first, "Steal")) -- Reserve 8 of the remaining 30 materials.
    task.wait(.3)
    ready:FireClient(second, "StealRace") -- Initially shows 30; only 22 remain.
    untilTrue(function() return service.Sabotage.Pending[second] ~= nil end, "Concurrent partial hold did not start")
    local partial = service.Sabotage.Pending[second]
    assert(partial.Amount == 22 and math.abs(partial.Duration - config.StealDuration(22)) < .001, "Partial bag duration used capacity instead of materials")
    untilTrue(function() return b.Carry == 22 end, "Native prompt did not finish the partial bag", partial.Duration + 1)
    local lag = workspace:GetServerTimeNow() - partial.EndsAt
    assert(lag < .3, "Native hold kept waiting for the old larger material count")
    assert(not b.StolenRound or service.Construction.TotalBuilt == 30, "Partial pickup deducted tower early")
    print("BURJ_LOG_HOLD_RACE_PASSED", 22, partial.Duration, lag)
    task.wait(.5) -- Allow both clients to observe the grant before clearing the fixture bag.
    service.Sabotage:Cancel(first)
    service.Sabotage:Cancel(second)
    b.Strength = 1
    service:Sync(second)
    -- Fixed number slots use the same client callback as keyboard input.
    untilTrue(function() return service.Pranks.Ready[second] end, "Defender inventory missing")
    local function key(slot, attack)
        second:SetAttribute("SmokeHotbar" .. slot, nil)
        ready:FireClient(second, attack and "HotbarAttack" or "HotbarKey", slot)
        untilTrue(function() return second:GetAttribute("SmokeHotbar" .. slot) or second:GetAttribute("SmokeHotbarFailure") end, "Client hotbar did not respond")
        assert(not second:GetAttribute("SmokeHotbarFailure"), "Client hotbar validation failed")
    end
    second:SetAttribute("SmokeHotbarPurchase", nil)
    ready:FireClient(second, "HotbarPurchase", 2)
    untilTrue(function() return second:GetAttribute("SmokeHotbarPurchase") end, "Empty numbered slot did not open its product flow")
    untilTrue(function() return service.Pranks.Inventory:Counts(second.UserId).Slap == 1 end, "Studio product substitute did not grant the requested slot")
    assert(not second.Character:FindFirstChildOfClass("Tool"), "Product request equipped before explicit selection")
    for _, kind in {"Bat", "Banana"} do
        assert(service.Pranks.Inventory:Grant(second.UserId, "hotbar-" .. kind, kind))
    end
    service.Pranks:Refresh(second)
    b.Carry = 14; service:CarryVisual(second); service:Sync(second)
    task.wait(.4)
    for _, slot in {2, 1, 3, 1, 4, 1, 2, 3, 1} do
        key(slot)
        local equipped = second.Character:FindFirstChildOfClass("Tool")
        assert(slot == 1 and equipped == nil or slot > 1 and equipped and equipped:GetAttribute("PrankKind") == ({"Materials", "Slap", "Bat", "Banana"})[slot], "Server observed wrong equipped item")
        assert(b.Carry == 14 and second.Character.CarriedMaterials:GetAttribute("MaterialCount") == 14, "Switch lost carried materials")
    end
    for _, kind in {"Slap", "Bat", "Banana"} do assert(service.Pranks.Inventory:Counts(second.UserId)[kind] == 1, "Switch consumed a paid use") end
    b.Carry = 0; service:CarryVisual(second); service:Sync(second)
    print("BURJ_HOTBAR_PASSED", "fixed 1/2/3/4, empty slot product flow, cargo preserved, no selection consumption, client and server equip")
    -- Real defender tool attacks cancel a native hold and a collected stolen bag.
    local function faceThief()
        go(second, "Steal", Vector3.new(0, 2, 9))
        second.Character:PivotTo(CFrame.lookAt(second.Character:GetPivot().Position, first.Character:GetPivot().Position))
        service.Pranks.LastUse[second] = nil
    end
    go(first, "Steal")
    faceThief()
    task.wait(.35)
    ready:FireClient(first, "Steal")
    untilTrue(function() return service.Sabotage.Pending[first] ~= nil end, "Native theft did not start before defense")
    local stolenDeadline = service.Sabotage.Pending[first].EndsAt
    key(2, true)
    untilTrue(function() return first:GetAttribute("PrankStunned") end, "Equipped slap did not hit thief")
    assert(not service.Sabotage.Pending[first] and service.Construction.Reserved == 0 and a.Carry == 0, "Hit during extraction retained reservation")
    task.wait(math.max(0, stolenDeadline - workspace:GetServerTimeNow()) + .3)
    assert(a.Carry == 0 and service.Construction.TotalBuilt == 30, "Interrupted native hold granted late cargo or removed construction")
    assert(not service:HandleAction(first, "FinishSteal"), "Interrupted hold can be resumed")
    extract(first)
    faceThief()
    task.wait(.35)
    key(3, true)
    untilTrue(function() return first:GetAttribute("PrankStunned") end, "Equipped bat did not hit stolen bag")
    assert(a.Carry == 0 and not a.StolenRound and service.Construction.Reserved == 0 and service.Construction.TotalBuilt == 30, "Spilled stolen bag reduced tower")
    assert(service.Pranks.Inventory:Counts(second.UserId).Slap == 0 and service.Pranks.Inventory:Counts(second.UserId).Bat == 0, "Defense did not consume exactly one paid use")
    task.wait(1.3)
    key(1)
    print("BURJ_THEFT_DEFENSE_PASSED", "native hold interrupted by equipped slap; stolen cargo stopped by equipped bat; no delayed grant or tower loss")
    -- Largest upgraded bag and partial availability.
    a.Strength = config.MaxUpgradeLevel
    service:Deposit(first, 150, true)
    extract(first)
    assert(a.Carry == 128 and #first.Character.CarriedMaterials:GetChildren() == 130, "Largest bag was truncated")
    service.LastAction[first] = nil
    assert(service:HandleAction(first, "Return"), "Return failed")
    assert(not a.StolenRound and a.Carry == 0 and service.Construction.TotalBuilt == 180, "Return failed to release stolen bag")
    -- Death releases the held reservation without subtracting progress.
    extract(second)
    second.Character.Humanoid.Health = 0
    untilTrue(function() return b.StolenRound == nil end, "Death did not cancel stolen cargo")
    assert(service.Construction.Reserved == 0 and service.Construction.TotalBuilt == 180, "Death changed tower")
    -- Completing a tower cancels all outstanding sabotage before awarding wins.
    extract(first)
    service:Deposit(first, config.TotalCost(), true)
    local wins = a.Wins
    assert(service.Construction.Complete and service.Construction.Reserved == 0 and a.Carry == 0 and not a.StolenRound, "Completion left a pending rollback")
    go(first, "Trash")
    assert(not action(first, "Trash") and a.Wins == wins, "Disposal rolled back a completed tower")
    task.wait(2.5)
    for _, player in participants do ready:FireClient(player, "CheckClear") end
    untilTrue(function() return first:GetAttribute("SmokeSabotageClear") and second:GetAttribute("SmokeSabotageClear") end, "Client effects did not clean up")
    for _, player in participants do assert(not player:GetAttribute("SmokeHoldFailure"), "Client hold completion check failed") end
    service.ResetAt = os.clock() - 1
    untilTrue(function() return service.Construction.Round == 2 end, "Next round did not start")
    assert(service.Construction.TotalBuilt == 0 and service.Construction.Reserved == 0 and not next(service.Sabotage.Pending), "Round reset retained sabotage")
    print("BURJ_SABOTAGE_MULTIPLAYER_PASSED", "2 clients; logarithmic native holds; immediate grants; release cancellation; 8/14/128 bricks; deferred disposal; floor/crane rollback")
    print("BURJ_MULTIPLAYER_PASSED", 2, "sabotage")
end, debug.traceback)
if not ok then warn("BURJ_MULTIPLAYER_FAILED", problem) end
StudioTestService:EndTest({Passed = ok, Error = tostring(problem)})
