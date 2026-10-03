-- Keyboard E, gamepad X and the HUD button use the same native hold prompt.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local StealHold = {}
StealHold.__index = StealHold

function StealHold:Update(snapshot)
    self.Snapshot = snapshot
    local prompt = self.Prompt
    if not prompt or not snapshot then return end
    local amount = self.Holding and self.Player:GetAttribute("StealingAmount")
        or math.min(snapshot.Capacity or 0, snapshot.Stealable or 0)
    -- A reservation can be smaller than the bag when another player takes some.
    local duration = self.Holding and self.Player:GetAttribute("StealingDuration") or nil
    if self.Holding and not duration then return end -- Keep the initial hold until the server confirms its amount.
    duration = duration or Config.StealDuration(amount)
    prompt.HoldDuration = math.max(.1, duration)
    prompt.ActionText = string.format("%d개 빼돌리기 · 꾹 누르기", amount)
    prompt.ObjectText = string.format("%.1f초 누르면 바로 가방으로!", duration)
    prompt.Enabled = not snapshot.Complete and not self.Player:GetAttribute("PrankStunned")
        and not self.Player:GetAttribute("Depositing") and (self.Holding or ((snapshot.Carry or 0) == 0 and amount > 0))
end

function StealHold:Release()
    self.ButtonInput = nil
    if self.Prompt then self.Prompt:InputHoldEnd() end
end

function StealHold:Begin(input)
    if self.Holding or self.ButtonInput or not self.Prompt or not self.Prompt.Enabled or not self.Button.Active
        or self.Button:GetAttribute("Action") ~= "Steal" then return end
    self.ButtonInput = input
    self.Prompt:InputHoldBegin()
end

function StealHold.new(player, button)
    local self = setmetatable({Player = player, Button = button, Holding = false}, StealHold)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then self:Begin(input) end
    end)
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.ButtonA and GuiService.SelectedObject == button then self:Begin(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == self.ButtonInput then self:Release() end
    end)
    button.MouseLeave:Connect(function()
        if self.ButtonInput and self.ButtonInput.UserInputType == Enum.UserInputType.MouseButton1 then self:Release() end
    end)
    UserInputService.WindowFocusReleased:Connect(function() self:Release() end)
    GuiService.MenuOpened:Connect(function() self:Release() end)
    for _, attribute in {"StealingDuration", "StealingAmount", "PrankStunned", "Depositing"} do
        player:GetAttributeChangedSignal(attribute):Connect(function() self:Update(self.Snapshot) end)
    end
    task.spawn(function()
        local station = workspace:WaitForChild("BurjWorld"):WaitForChild("Dubai Plaza"):WaitForChild("Steal Interaction")
        local prompt = station:WaitForChild("Interact")
        self.Prompt = prompt
        prompt.PromptButtonHoldBegan:Connect(function(who)
            if who and who ~= player then return end
            self.Holding = true
        end)
        prompt.PromptButtonHoldEnded:Connect(function(who)
            if who and who ~= player then return end
            self.Holding, self.ButtonInput = false, nil
            self:Update(self.Snapshot)
        end)
        prompt.PromptHidden:Connect(function() self:Release() end)
        game.ReplicatedStorage.Remotes.State.OnClientEvent:Connect(function(kind, payload)
            if kind == "TheftDenied" or (kind == "TheftEnd" and payload.UserId == player.UserId) then
                self.Holding = false
                self:Release()
                self:Update(self.Snapshot)
            end
        end)
        self:Update(self.Snapshot)
    end)
    return self
end
return StealHold
