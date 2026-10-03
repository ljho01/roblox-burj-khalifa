local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Construction = require(script.Parent.Construction)
local Sabotage = {}
Sabotage.__index = Sabotage

function Sabotage.new(service)
    return setmetatable({Service = service, Pending = {}, NextId = 0}, Sabotage)
end

function Sabotage:Cancel(player, message)
    local service = self.Service
    local pending = self.Pending[player]
    self.Pending[player] = nil
    local released = Construction.Release(service.Construction, player.UserId)
    local profile = service.Profiles:Get(player)
    if profile and profile.StolenRound then
        profile.Carry, profile.StolenRound = 0, nil
        service:CarryVisual(player)
    end
    player:SetAttribute("StealingUntil", nil)
    player:SetAttribute("StealingAmount", nil)
    player:SetAttribute("StealingDuration", nil)
    if pending then service.StateRemote:FireAllClients("TheftEnd", {Id = pending.Id, UserId = player.UserId}) end
    if released > 0 then service:Broadcast() else service:Sync(player) end
    if message and player.Parent == Players then service:Toast(player, message) end
end

function Sabotage:Reset()
    for _, player in Players:GetPlayers() do self:Cancel(player) end
end

function Sabotage:Start(player)
    local service = self.Service
    local profile = service.Profiles:Get(player)
    if not profile or service.Construction.Complete or self.Pending[player] or player:GetAttribute("PrankStunned")
        or not service:IsNear(player, "Steal") then return false end
    if profile.Carry > 0 then service:Toast(player, "가방을 비운 뒤 자재를 빼돌릴 수 있어요."); return false end
    local amount = Construction.Reserve(service.Construction, Config.Capacity(profile.Strength), player.UserId)
    if amount == 0 then service:Toast(player, "지금 빼돌릴 수 있는 자재가 없어요."); return false end
    self.NextId += 1
    local duration = Config.StealDuration(amount)
    local pending = {Id = self.NextId, Amount = amount, Round = service.Construction.Round,
        Character = player.Character, Origin = player.Character:GetPivot().Position,
        Duration = duration, EndsAt = workspace:GetServerTimeNow() + duration}
    self.Pending[player] = pending
    player:SetAttribute("StealingAmount", amount)
    player:SetAttribute("StealingDuration", duration)
    player:SetAttribute("StealingUntil", pending.EndsAt)
    service.StateRemote:FireAllClients("TheftStart", {Id = pending.Id, UserId = player.UserId,
        Amount = amount, Duration = duration, EndsAt = pending.EndsAt, Origin = Config.Positions.Steal})
    service:Broadcast()
    return true
end

function Sabotage:IsValid(player, pending)
    local service = self.Service
    local profile = service.Profiles:Get(player)
    local character = player.Character
    return profile ~= nil and player.Parent == Players and character ~= nil and character == pending.Character
        and not service.Construction.Complete and service.Construction.Round == pending.Round
        and not player:GetAttribute("PrankStunned") and service:IsNear(player, "Steal")
        and (character:GetPivot().Position - pending.Origin).Magnitude <= 4 and profile.Carry == 0
end

function Sabotage:Finish(player)
    local pending = self.Pending[player]
    if not pending then return false end
    if not self:IsValid(player, pending) then self:Cancel(player); return false end
    -- Hold events originate on the client: validate elapsed time on the server.
    -- Allow only a small network scheduling tolerance, never a second wait phase.
    if (pending.ReleasedAt or workspace:GetServerTimeNow()) + 0.1 < pending.EndsAt then return false end
    local service = self.Service
    local profile = service.Profiles:Get(player)
    self.Pending[player] = nil
    profile.Carry, profile.StolenRound = pending.Amount, pending.Round
    player:SetAttribute("StealingUntil", nil)
    player:SetAttribute("StealingAmount", nil)
    player:SetAttribute("StealingDuration", nil)
    service.StateRemote:FireAllClients("TheftEnd", {Id = pending.Id, UserId = player.UserId})
    service:CarryVisual(player)
    service:Sync(player)
    service:Toast(player, string.format("자재 %d개를 챙겼어요! 분홍 쓰레기통에 버려야 성공해요.", pending.Amount))
    return true
end

function Sabotage:EndHold(player)
    -- A late release must never cancel an already collected bag.
    local pending = self.Pending[player]
    if not pending then return false end
    pending.ReleasedAt = pending.ReleasedAt or workspace:GetServerTimeNow()
    -- Roblox sends HoldEnded just before Triggered even for a completed hold.
    -- Let that completion event commit immediately; release alone never grants.
    task.delay(.15, function()
        if self.Pending[player] == pending then self:Cancel(player) end
    end)
    return false
end

function Sabotage:Step()
    for player, pending in pairs(self.Pending) do
        if not self:IsValid(player, pending) or workspace:GetServerTimeNow() > pending.EndsAt + 2 then
            self:Cancel(player, "빼돌리기가 중단됐어요. 자재는 공사장에 그대로 있어요.")
        end
    end
end

function Sabotage:Discard(player)
    local service = self.Service
    local profile = service.Profiles:Get(player)
    if not profile or not profile.StolenRound or profile.Carry <= 0 or self.Pending[player]
        or player:GetAttribute("PrankStunned") or not service:IsNear(player, "Trash") then
        service:Toast(player, "빼돌린 자재를 가져와 쓰레기통에 버려 주세요.")
        return false
    end
    local oldStage = service.Construction.Stage
    local removed, floors = Construction.Discard(service.Construction, player.UserId, profile.StolenRound)
    if removed == 0 then self:Cancel(player, "이번 공사의 빼돌리기가 종료됐어요."); return false end
    service:AnimateDeposit(player, removed, service.World.TrashTarget, "TrashEffect")
    profile.Carry, profile.StolenRound = 0, nil
    service:CarryVisual(player)
    if floors > 0 then
        service.World:SetStage(service.Construction.Stage, true)
        service.StateRemote:FireAllClients("FloorsRemoved", {FromStage = oldStage, ToStage = service.Construction.Stage, Round = service.Construction.Round})
        -- Keep visitors standing on the moving observation deck safely above it.
        local roof = Config.TowerBaseY + service.Construction.Stage * Config.StageHeight
        for _, visitor in Players:GetPlayers() do
            local root = visitor.Character and visitor.Character:FindFirstChild("HumanoidRootPart")
            if root and math.abs(root.Position.X) < 8 and root.Position.Z < -2 and root.Position.Z > -14 and root.Position.Y > roof + 2 then
                visitor.Character:PivotTo(service.World:GetLookoutCFrame())
            end
        end
    end
    service:Toast(player, string.format("쏙! 자재 %d개를 버려서 빼돌리기 성공!", removed), "success")
    service:Broadcast()
    return true
end
return Sabotage
