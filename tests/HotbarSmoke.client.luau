local player = game.Players.LocalPlayer
local ready = game.ReplicatedStorage:WaitForChild("SmokeReady")
local module = require(player.PlayerScripts:WaitForChild("GameClient"):WaitForChild("Hotbar"))
ready.OnClientEvent:Connect(function(command, slot)
    if command ~= "HotbarKey" and command ~= "HotbarAttack" and command ~= "HotbarPurchase" then return end
    local ok, problem = xpcall(function()
        local bar = module.Current
        assert(bar, "Hotbar controller missing")
        local binding = game:GetService("ContextActionService"):GetBoundActionInfo("BurjHotbar")
        assert(#binding.inputTypes == 4 and binding.inputTypes[slot] == module.Keys[slot], "Number key bindings differ from fixed slots")
        local before = player:GetAttribute("Carry")
        bar.Frame:SetAttribute("PurchaseRequestedKind", nil)
        assert(bar:HandleInput("BurjHotbar", Enum.UserInputState.Begin, {KeyCode = module.Keys[slot]}) == Enum.ContextActionResult.Sink)
        task.wait(.25)
        bar:Refresh()
        local tool = slot > 1 and bar:FindTool(module.Kinds[slot])
        if command == "HotbarPurchase" then
            assert(bar.Frame:GetAttribute("PurchaseRequestedKind") == module.Kinds[slot], "Empty slot did not request its matching product")
            assert(not player.Character:FindFirstChildOfClass("Tool"), "Purchase request equipped a tool before a server grant")
            ready:FireServer("HotbarPurchase")
            return
        end
        local expected = (slot == 1 or not tool) and 1 or slot
        assert(bar.Frame:GetAttribute("SelectedSlot") == expected, "Wrong highlighted slot")
        if tool then assert(tool.Parent == player.Character, "Number-key selection did not equip tool")
        else assert(not player.Character:FindFirstChildOfClass("Tool"), "Materials did not unequip weapon") end
        assert(player:GetAttribute("Carry") == before, "Switching changed cargo")
        assert(not game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack), "Default hotbar competes with fixed slots")
        local objective = bar.Frame.Parent.CurrentTask
        assert(bar.Frame.AbsolutePosition.Y >= objective.AbsolutePosition.Y + objective.AbsoluteSize.Y, "Hotbar overlaps interaction panel")
        if command == "HotbarAttack" then assert(tool); tool:Activate() end
        ready:FireServer("Hotbar" .. slot)
    end, debug.traceback)
    if not ok then ready:FireServer("HotbarFailure"); error(problem) end
end)
