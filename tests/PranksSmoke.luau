return function(service, participants, ready)
    local attacker, victim = participants[1], participants[2]
    local pranks = service.Pranks
    local victimProfile = service.Profiles:Get(victim)
    local built, coins, contribution = service.Construction.TotalBuilt, victimProfile.Coins, victimProfile.Contributed
    local function untilTrue(predicate, message)
        local deadline = os.clock() + 8
        repeat task.wait(.05) until predicate() or os.clock() > deadline
        assert(predicate(), message)
    end
    untilTrue(function() return pranks.Ready[attacker] and pranks.Ready[victim] end, "Purchase inventories did not load")
    pranks.Products[987654321] = "Slap" -- Test-only product; never in the build.
    local receipt = {PlayerId = attacker.UserId, ProductId = 987654321, PurchaseId = "test-slap-receipt"}
    assert(pranks:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
    assert(pranks:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
    assert(pranks.Inventory:Counts(attacker.UserId).Slap == 1, "Repeated receipt gave multiple uses")
    assert(pranks:ProcessReceipt({PlayerId = attacker.UserId, ProductId = -99, PurchaseId = "unknown"}) == Enum.ProductPurchaseDecision.NotProcessedYet, "Unknown product acknowledged")
    local function prepare(amount)
        for _, p in participants do
            local root = p.Character.HumanoidRootPart
            root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
        end
        attacker.Character:PivotTo(CFrame.lookAt(Vector3.new(-34, 6, 100), Vector3.new(-34, 6, 94)))
        victim.Character:PivotTo(CFrame.new(-34, 6, 95))
        victimProfile.Carry = amount
        service:CarryVisual(victim); service:Sync(victim)
        pranks.LastUse[attacker] = nil
        task.wait(.45)
    end
    prepare(8)
    assert(not pranks:CanHit(attacker, attacker, "Slap"), "Self hit allowed")
    victim.Character:PivotTo(CFrame.new(-34, 6, 70))
    assert(not pranks:CanHit(attacker, victim, "Bat"), "Distant target allowed")
    prepare(8)
    local wall = Instance.new("Part")
    wall.Anchored, wall.Size, wall.Position = true, Vector3.new(8, 12, 1), Vector3.new(-34, 6, 97.5)
    wall.Parent = workspace
    assert(not pranks:CanHit(attacker, victim, "Slap"), "Hit passed through wall")
    wall:Destroy()
    ready:FireClient(attacker, "UsePrank", "Slap")
    untilTrue(function() return victimProfile.Carry == 0 end, "Client slap did not spill all materials")
    assert(not victim.Character:FindFirstChild("CarriedMaterials") and victim:GetAttribute("PrankStunned"), "Stack remained or stun missing")
    assert(not service:HandleAction(victim, "Interact", "Supply"), "Stunned player could collect")
    assert(pranks.Inventory:Counts(attacker.UserId).Slap == 0, "Slap was not consumed")
    assert(pranks:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted and pranks.Inventory:Counts(attacker.UserId).Slap == 0, "Receipt replay revived used slap")
    task.wait(1.5)
    assert(not victim:GetAttribute("PrankStunned") and not victim.Character.Humanoid.PlatformStand, "Stun did not recover")
    assert(pranks.Inventory:Grant(attacker.UserId, "test-bat", "Bat")); pranks:Refresh(attacker)
    victimProfile.Strength = 20
    prepare(128)
    ready:FireClient(attacker, "UsePrank", "Bat")
    untilTrue(function() return victimProfile.Carry == 0 end, "Bat did not drop all 128 materials")
    task.wait(1.5)
    assert(pranks.Inventory:Grant(attacker.UserId, "test-banana", "Banana")); pranks:Refresh(attacker)
    victimProfile.Strength = 0
    prepare(8)
    victim.Character:PivotTo(CFrame.new(-50, 6, 105))
    ready:FireClient(attacker, "UsePrank", "Banana")
    untilTrue(function() return #pranks.Traps == 1 end, "Banana did not place through client tool")
    local trap = pranks.Traps[1]
    attacker.Character:PivotTo(CFrame.new(trap.Position + Vector3.new(0, 3, 0)))
    task.wait(.8)
    assert(#pranks.Traps == 1 and not attacker:GetAttribute("PrankStunned"), "Owner tripped on own banana")
    attacker.Character:PivotTo(CFrame.new(-40, 6, 108))
    victim.Character:PivotTo(CFrame.new(trap.Position + Vector3.new(0, 3, 0)))
    untilTrue(function() return victimProfile.Carry == 0 and #pranks.Traps == 0 end, "Banana did not slip victim or clean up")
    assert(pranks.Inventory:Counts(attacker.UserId).Banana == 0, "Banana was not consumed")
    assert(victimProfile.Coins == coins and victimProfile.Contributed == contribution and service.Construction.TotalBuilt == built, "Spilled materials awarded progress or coins")
    task.wait(3)
    for _, player in participants do ready:FireClient(player, "CheckPranks") end
    untilTrue(function() return attacker:GetAttribute("SmokePranks") and victim:GetAttribute("SmokePranks") end, "Hit effects were not seen and cleaned on both clients")
    pranks:PlaceBanana(attacker, Vector3.new(-35, 3, 100))
    pranks.Traps[1].Expires = 0; pranks:Step()
    assert(#pranks.Traps == 0 and #pranks.Folder:GetChildren() == 0, "Expired trap leaked")
    print("BURJ_PRANKS_MULTIPLAYER_PASSED", "slap, bat 128 bricks, banana, receipt replay, both client effects, recovery, expiry")
end
