local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local ready = game.ReplicatedStorage:WaitForChild("SmokeReady", 30)
local remotes = game.ReplicatedStorage:WaitForChild("Remotes", 30)
local hud = player:WaitForChild("PlayerGui"):WaitForChild("BurjHUD", 30)
local theft = workspace:WaitForChild("BurjTheftEffects", 30)
local deposits = workspace:WaitForChild("BurjEffects", 30)
local floor = workspace:WaitForChild("BurjFloorEffects", 30)
local prompt = workspace.BurjWorld["Dubai Plaza"]["Steal Interaction"].Interact
local config = require(game.ReplicatedStorage.Shared.Config)
local sent, original = {}, nil
local function report(kind)
    if sent[kind] then return end
    sent[kind] = true
    ready:FireServer(kind)
end
prompt.Triggered:Connect(function()
    task.delay(.3, function()
        if (player:GetAttribute("Carry") or 0) <= 0 then
            ready:FireServer("HoldFailure")
            error("Completed native hold started another wait instead of granting materials")
        end
        report("HoldImmediate")
    end)
end)
RunService.Heartbeat:Connect(function()
    assert((theft:GetAttribute("ActiveParts") or 0) <= 96, "Extraction parts exceeded budget")
    for _, brick in theft:GetDescendants() do
        if brick:IsA("BasePart") then
            assert(not brick.CanCollide and not brick.CanTouch and not brick.CanQuery, "Extraction changes physics")
            if original and original.Part == brick and (original.Position - brick.Position).Magnitude > .1 then report("TheftFX") end
            original = original or {Part = brick, Position = brick.Position}
        end
    end
    local progress = hud:FindFirstChild("StealProgress", true)
    if progress and progress.Visible and progress.AbsoluteSize.X > 10 then report("TheftUI") end
end)
remotes.State.OnClientEvent:Connect(function(kind)
    if kind == "TrashEffect" then
        task.delay(.3, function()
            assert(deposits:GetAttribute("ActiveBricks") > 0, "Discard has no animated bricks")
            report("TrashFX")
        end)
    end
end)
ready.OnClientEvent:Connect(function(command)
    if command == "Steal" then
        local state = remotes.GetState:InvokeServer()
        assert(state and math.abs(prompt.HoldDuration - config.StealDuration(math.min(state.Capacity, state.Stealable))) < .01, "Native hold does not use this player's actual material count")
        prompt:InputHoldBegin()
    elseif command == "ReleaseSteal" then
        prompt:InputHoldEnd()
    elseif command == "StealRace" then
        -- Deliberately start from an old availability estimate, then let the
        -- reservation acknowledgement retime the real native prompt mid-hold.
        prompt.HoldDuration = config.StealDuration(30)
        prompt:InputHoldBegin()
    elseif command == "Trash" then
        remotes.Action:FireServer("Interact", "Trash")
    elseif command == "CheckBag" then
        local snapshot = remotes.GetState:InvokeServer()
        assert(snapshot and snapshot.Stolen and snapshot.Carry == snapshot.Capacity, "Stolen bag snapshot wrong")
        local stack = player.Character:FindFirstChild("CarriedMaterials")
        assert(stack and stack:GetAttribute("Stolen") and stack:GetAttribute("MaterialCount") == snapshot.Capacity, "Stolen stack not replicated")
        local count = 0
        for _, brick in stack:GetChildren() do
            if brick.Name == "MaterialBrick" then
                count += 1
                assert(brick.Color.R > .9 and brick.Color.B > .7, "Stolen materials are not pink")
            end
        end
        assert(count == snapshot.Capacity, "Stolen stack must show one brick per material")
        local found = false
        for _, item in hud:GetDescendants() do
            if item:IsA("TextLabel") and item.Text == "빼돌린 자재" then found = true end
        end
        assert(found, "Carry HUD did not identify stolen materials")
        report("StolenBag")
    elseif command == "BeforeRebuild" then
        sent.BeforeRebuild = floor:GetAttribute("EffectsPlayed")
    elseif command == "AfterRebuild" then
        assert(floor:GetAttribute("EffectsPlayed") > sent.BeforeRebuild, "Rebuilt floors did not replay effects")
        report("RebuiltFX")
    elseif command == "CheckClear" then
        assert(#theft:GetChildren() == 0 and (theft:GetAttribute("ActiveParts") or 0) == 0, "Extraction effects leaked")
        assert(#deposits:GetChildren() == 0 and deposits:GetAttribute("ActiveParts") == 0, "Discard effects leaked")
        assert(not hud:FindFirstChild("StealProgress", true).Visible, "Extraction bar stuck")
        report("SabotageClear")
        print("BURJ_SABOTAGE_CLIENT_PASSED", player.UserId)
    end
end)
task.wait(2)
ready:FireServer()
