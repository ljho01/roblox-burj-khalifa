local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Catalog = require(game.ReplicatedStorage.Shared.PrankCatalog)
local Hotbar = {}
Hotbar.__index = Hotbar
Hotbar.Keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
Hotbar.Kinds = {"Materials", "Slap", "Bat", "Banana"}

function Hotbar:FindTool(kind)
    for _, container in {self.Player.Character, self.Player:FindFirstChildOfClass("Backpack")} do
        if container then
            for _, tool in container:GetChildren() do
                if tool:IsA("Tool") and tool:GetAttribute("PrankKind") == kind then return tool end
            end
        end
    end
end

function Hotbar:Refresh()
    local selected = 1
    for index = 2, 4 do
        local tool = self:FindTool(Hotbar.Kinds[index])
        if tool and tool.Parent == self.Player.Character then selected = index end
    end
    self.Frame:SetAttribute("SelectedSlot", selected)
    for index, button in ipairs(self.Buttons) do
        local kind = Hotbar.Kinds[index]
        local tool = index > 1 and self:FindTool(kind)
        local count = index == 1 and (self.Player:GetAttribute("Carry") or 0)
            or (tool and tool:GetAttribute("Uses") or 0)
        local name = index == 1 and "자재" or Catalog.Items[kind].Name
        button.Text = string.format("%d  %s\n%s", index, name, index == 1 and (count .. "개")
            or (count > 0 and count .. "회" or Catalog.Items[kind].Price .. " R$ · 구매"))
        button.BackgroundColor3 = index == selected and self.Colors.Yellow or self.Colors.Panel
        button.TextColor3 = (index == 1 or count > 0) and self.Colors.Navy or self.Colors.Steel
        -- Empty weapon slots remain visible and open their matching product prompt.
        button:SetAttribute("Selected", index == selected)
        button:SetAttribute("Count", count)
    end
end

function Hotbar:Select(index)
    local kind = Hotbar.Kinds[index]
    local character = self.Player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if not kind or not human or human.Health <= 0 or self.Player:GetAttribute("PrankStunned") then return false end
    local tool = index > 1 and self:FindTool(kind)
    if index > 1 and not tool then
        self.Frame:SetAttribute("PurchaseRequestedKind", kind)
        if self.OnMissing then self.OnMissing(kind) end
        return false
    end
    if index > 1 then
        self.StealHold:Release()
        if self.Player:GetAttribute("StealingUntil") then game.ReplicatedStorage.Remotes.Action:FireServer("EndSteal") end
        human:EquipTool(tool)
    else
        human:UnequipTools() -- Cargo stays on the back; switching never grants or drops it.
    end
    self:Refresh()
    return true
end

function Hotbar:HandleInput(_, state, input)
    if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
    local index = table.find(Hotbar.Keys, input.KeyCode)
    if not index then return Enum.ContextActionResult.Pass end
    if state == Enum.UserInputState.Begin then self:Select(index) end
    return Enum.ContextActionResult.Sink
end

function Hotbar.new(player, frame, buttons, colors, stealHold, onMissing)
    local self = setmetatable({Player = player, Frame = frame, Buttons = buttons, Colors = colors,
        StealHold = stealHold, OnMissing = onMissing}, Hotbar)
    Hotbar.Current = self
    for index, button in ipairs(buttons) do button.Activated:Connect(function() self:Select(index) end) end
    ContextActionService:BindActionAtPriority("BurjHotbar", function(...) return self:HandleInput(...) end,
        false, Enum.ContextActionPriority.High.Value, table.unpack(Hotbar.Keys))
    task.spawn(function()
        for _ = 1, 8 do
            if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end) then break end
            task.wait(.5)
        end
    end)
    local characterConnections = {}
    local function watchCharacter(character)
        for _, connection in characterConnections do connection:Disconnect() end
        table.clear(characterConnections)
        local function refresh() task.defer(function() self:Refresh() end) end
        table.insert(characterConnections, character.ChildAdded:Connect(refresh))
        table.insert(characterConnections, character.ChildRemoved:Connect(refresh))
        refresh()
    end
    player.CharacterAdded:Connect(watchCharacter)
    if player.Character then watchCharacter(player.Character) end
    task.spawn(function()
        local backpack = player:WaitForChild("Backpack")
        backpack.ChildAdded:Connect(function() task.defer(function() self:Refresh() end) end)
        backpack.ChildRemoved:Connect(function() task.defer(function() self:Refresh() end) end)
        self:Refresh()
    end)
    player:GetAttributeChangedSignal("Carry"):Connect(function() self:Refresh() end)
    self:Refresh()
    return self
end
return Hotbar
