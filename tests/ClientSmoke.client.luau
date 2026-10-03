local Players = game:GetService("Players")
local player = Players.LocalPlayer
local remote = game.ReplicatedStorage:WaitForChild("SmokeReady", 30)
task.spawn(function()
    local effects = workspace:WaitForChild("BurjFloorEffects", 25)
    local crane = workspace:WaitForChild("BurjWorld"):WaitForChild("Dubai Plaza"):WaitForChild("ConstructionCrane")
    local head = crane:WaitForChild("CraneHead")
    local startY = head:GetPivot().Position.Y
    local deadline = os.clock() + 25
    local sawPuff, sawStar, sawLift = false, false, false
    repeat
        task.wait(.03)
        assert((effects:GetAttribute("ActiveParts") or 0) <= 128, "Floor effect part budget exceeded")
        sawLift = sawLift or head:GetPivot().Position.Y > startY + 1
        for _, p in effects:GetDescendants() do
            if not p:IsA("BasePart") then continue end
            assert(not p.CanCollide and not p.CanTouch and not p.CanQuery, "Floor effect changes gameplay physics")
            if p.Name == "SoftDustPuff" and p.Transparency < .9 then
                assert(p.Shape == Enum.PartType.Ball and p.Position.Y > 3, "Dust is not on the constructed floor")
                sawPuff = true
            elseif p.Name == "TwinkleVertical" and p.Transparency < .9 then sawStar = true end
        end
    until (sawPuff and sawStar and sawLift) or os.clock() > deadline
    assert(sawPuff and sawStar and sawLift, "Floor puff, sparkle or crane lift is not visible")
    remote:FireServer("FloorEffects")
    print("BURJ_FLOOR_EFFECTS_CLIENT_PASSED", "soft puffs, twinkles, crane lift")
end)
task.spawn(function()
    local workers = workspace:WaitForChild("BurjWorkers", 25)
    local deadline = os.clock() + 60
    local worker
    repeat
        task.wait(0.03)
        for _, model in workers:GetChildren() do
            if model:GetAttribute("OwnerId") == player.UserId then worker = model; break end
        end
    until worker or os.clock() > deadline
    if not worker then return end
    local origin = worker:GetPivot().Position
    local loaded, moved, unloaded, swung = false, false, false, false
    local joint = worker:FindFirstChild("Left Shoulder", true) or worker:FindFirstChild("LeftShoulder", true)
    local originalJoint = joint and joint.C0
    deadline = os.clock() + 9
    repeat
        task.wait(0.03)
        if not worker.Parent then
            for _, replacement in workers:GetChildren() do
                if replacement:GetAttribute("OwnerId") == player.UserId then
                    worker = replacement
                    joint = worker:FindFirstChild("Left Shoulder", true) or worker:FindFirstChild("LeftShoulder", true)
                    originalJoint = joint and joint.C0
                    break
                end
            end
        end
        loaded = loaded or worker:GetAttribute("VisualCarrying") == true
        moved = moved or (worker:GetPivot().Position - origin).Magnitude > 80
        unloaded = unloaded or (loaded and worker:GetAttribute("VisualState") == "창고로 돌아가는 중" and worker:GetAttribute("VisualCarrying") == false)
        swung = swung or (joint and joint.C0 ~= originalJoint)
    until (loaded and moved and unloaded and swung) or os.clock() > deadline
    print("BURJ_WORKER_VISUAL_PROBE", loaded, moved, unloaded, swung, worker:GetAttribute("AvatarSource"), worker:GetAttribute("VisualState"), #worker:GetDescendants())
    assert(loaded and moved and unloaded and swung, "Worker movement, carry, unload or walk pose missing")
    remote:FireServer("Workers")
    print("BURJ_WORKER_CLIENT_PASSED", "walk, carry, unload, return")
end)
task.spawn(function()
    local effects = workspace:WaitForChild("BurjEffects", 25)
    assert(effects, "Deposit effects did not initialize")
    local deadline = os.clock() + 30
    repeat task.wait(0.03) until (effects:GetAttribute("ActiveBricks") or 0) > 0 or os.clock() > deadline
    assert((effects:GetAttribute("ActiveBricks") or 0) > 0, "No flying material bricks were animated")
    assert((effects:GetAttribute("ActiveParts") or 0) <= 246, "Cosmetic part budget exceeded")
    remote:FireServer("Animation")
    print("BURJ_DEPOSIT_ANIMATION_PASSED", effects:GetAttribute("ActiveBricks"))
end)
local gui = player:WaitForChild("PlayerGui")
local hud = gui:WaitForChild("BurjHUD", 25)
assert(hud, "Game HUD missing")
task.wait(2)
local dashboard = hud.SafeArea.Dashboard
local progress = dashboard.TowerProgress
if workspace.CurrentCamera.ViewportSize.X >= 960 then
    assert(progress.AbsolutePosition.Y <= 20, "Progress HUD is still too far from top")
end
local found = false
for _, item in gui:GetDescendants() do
    if item:IsA("TextLabel") and (string.find(item.Text, "Burj") or string.find(item.Text, "자재") or string.find(item.Text, "828")) then found = true end
end
assert(found, "Game HUD not present")
local snapshot = game.ReplicatedStorage.Remotes.GetState:InvokeServer()
assert(snapshot and snapshot.Capacity >= 8 and snapshot.TotalCost > 0, "Client state missing")
remote:FireServer()
print("BURJ_SMOKE_CLIENT_OK")
remote.OnClientEvent:Connect(function(command, amount)
    if command == "UsePrank" then
        local tool
        for _, item in player.Backpack:GetChildren() do
            if item:IsA("Tool") and item:GetAttribute("PrankKind") == amount then tool = item; break end
        end
        assert(tool, "Purchased tool missing from backpack")
        player.Character.Humanoid:EquipTool(tool)
        task.wait(.2)
        tool:Activate()
    elseif command == "CheckPranks" then
        local effects = workspace.BurjPrankEffects
        assert(effects:GetAttribute("HitsPlayed") >= 3, "Prank hits were not replicated")
        assert(effects:GetAttribute("ActiveParts") == 0 and #effects:GetChildren() == 0, "Spilled materials leaked")
        local shop = dashboard.Shop
        assert(shop.PrankTab and shop.Slap and shop.Bat and shop.Banana, "Prank shop rows missing")
        remote:FireServer("Pranks")
        print("BURJ_PRANKS_CLIENT_PASSED", effects:GetAttribute("HitsPlayed"))
    elseif command == "Collect" then
        game.ReplicatedStorage.Remotes.Action:FireServer("Interact", "Supply")
    elseif command == "Build" then
        game.ReplicatedStorage.Remotes.Action:FireServer("Interact", "Build")
    elseif command == "CheckWorkerTeam" then
        local count, owners = 0, {}
        for _, worker in workspace.BurjWorkers:GetChildren() do
            local ownerId = worker:GetAttribute("OwnerId")
            assert(not owners[ownerId], "More than one carrier per player is visible")
            owners[ownerId] = true
            if worker:GetAttribute("VisualState") and worker:GetAttribute("OwnerId") ~= player.UserId then count += 1 end
        end
        if count > 0 then remote:FireServer("WorkerTeam") end
    elseif command == "CheckFloorClear" then
        local effects = workspace.BurjFloorEffects
        assert((effects:GetAttribute("ActiveParts") or 0) == 0 and #effects:GetChildren() == 0, "Floor effect parts were not released")
        assert((effects:GetAttribute("EffectsPlayed") or 0) > 0, "No floor effects played")
        remote:FireServer("FloorClear")
        print("BURJ_FLOOR_EFFECTS_CLEANUP_PASSED")
    elseif command == "CheckWorkerLoad" then
        local loaded, unloaded = false, false
        local deadline = os.clock() + 9
        repeat
            task.wait(0.03)
            local count = 0
            for _, worker in workspace.BurjWorkers:GetChildren() do
                if worker:GetAttribute("OwnerId") ~= player.UserId then continue end
                count += 1
                local stack = worker:FindFirstChild("WorkerMaterials")
                if not stack or #stack:GetChildren() ~= amount then continue end
                local visible = 0
                for _, brick in stack:GetChildren() do
                    if brick.LocalTransparencyModifier < 0.1 then visible += 1 end
                end
                loaded = loaded or (worker:GetAttribute("VisualCarrying") and visible == amount)
                unloaded = unloaded or (worker:GetAttribute("VisualState") == "창고로 돌아가는 중" and visible == 0)
            end
            assert(count == 1, "Upgrading spawned multiple carriers on client")
        until (loaded and unloaded) or os.clock() > deadline
        assert(loaded and unloaded, "New material bricks have wrong visibility while carrying or returning")
        remote:FireServer("WorkerLoad")
        print("BURJ_SINGLE_CARRIER_LOAD_CLIENT_PASSED", amount)
    elseif command == "CheckComplete" then
        local state = game.ReplicatedStorage.Remotes.GetState:InvokeServer()
        if state and state.Complete and state.Wins == 1 then remote:FireServer("Complete") end
    end
end)
