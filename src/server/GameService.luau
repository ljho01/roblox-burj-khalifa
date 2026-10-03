local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Config = require(ReplicatedStorage.Shared.Config)
local CarryGeometry = require(ReplicatedStorage.Shared.CarryGeometry)
local Construction = require(script.Parent.Construction)
local Profiles = require(script.Parent.Profiles)
local World = require(script.Parent.World)
local Workers = require(script.Parent.Workers)
local Pranks = require(script.Parent.Pranks)
local Sabotage = require(script.Parent.Sabotage)
local Service = {Started = false}
local DEPOSIT_DURATION = Config.DepositDuration

function Service:Toast(player, message, kind)
    if player.Parent == Players then self.StateRemote:FireClient(player, "Toast", {Text = message, Kind = kind or "info"}) end
end

function Service:Snapshot(player)
    local profile = self.Profiles:Get(player)
    if not profile then return nil end
    local state = self.Construction
    return {
        Coins = profile.Coins, Carry = profile.Carry, Capacity = Config.Capacity(profile.Strength),
        Strength = profile.Strength, Speed = profile.Speed, Worker = profile.Worker,
        Wins = profile.Wins, Contributed = profile.Contributed, Saved = profile.Saved,
        Pranks = self.Pranks and self.Pranks:Snapshot(player),
        Stolen = profile.StolenRound ~= nil,
        Stealable = math.max(0, state.TotalBuilt - state.Reserved),
        Stage = state.Stage, StageProgress = state.StageProgress,
        StageCost = state.Complete and 0 or Config.StageCost(state.Stage + 1),
        TotalBuilt = state.TotalBuilt, TotalCost = Config.TotalCost(), Round = state.Round,
        Complete = state.Complete, ResetIn = state.Complete and math.max(0, math.ceil((self.ResetAt or 0) - os.clock())) or 0,
    }
end

function Service:Sync(player)
    local data = self:Snapshot(player)
    if not data or player.Parent ~= Players then return end
    local stats = player:FindFirstChild("leaderstats")
    if stats then
        stats.Coins.Value = data.Coins
        stats.Built.Value = data.Contributed
        stats.Wins.Value = data.Wins
    end
    player:SetAttribute("Carry", data.Carry)
    player:SetAttribute("Capacity", data.Capacity)
    player:SetAttribute("StolenMaterials", data.Stolen)
    self.StateRemote:FireClient(player, "Snapshot", data)
end

function Service:Broadcast()
    for _, player in Players:GetPlayers() do self:Sync(player) end
end

function Service:CarryVisual(player)
    local character = player.Character
    if not character then return end
    local old = character:FindFirstChild("CarriedMaterials")
    if old then old:Destroy() end
    local profile = self.Profiles:Get(player)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not profile or profile.Carry == 0 then return end
    local stack = Instance.new("Model")
    stack.Name = "CarriedMaterials"
    stack:SetAttribute("MaterialCount", profile.Carry)
    stack:SetAttribute("LayerCount", CarryGeometry.LayerCount(profile.Carry))
    stack:SetAttribute("Stolen", profile.StolenRound ~= nil)
    stack.Parent = character
    local function attach(block, offset)
        block.Massless, block.CanCollide, block.CanTouch, block.CanQuery = true, false, false, false
        block.CFrame = root.CFrame * offset
        block.Parent = stack
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = root, block, block
    end
    local pack = Instance.new("Part")
    pack.Name = "LittleBackpack"
    pack.Size = Vector3.new(2.25, 1.65, 0.3)
    pack.Color = Color3.fromRGB(169, 199, 238)
    pack.Material = Enum.Material.SmoothPlastic
    attach(pack, CFrame.new(0, -0.45, 0.98))
    local tray = Instance.new("Part")
    tray.Name = "CarryTray"
    tray.Size = Vector3.new(4.6, 0.18, 3.8)
    tray.Color = Color3.fromRGB(117, 141, 182)
    tray.Material = Enum.Material.SmoothPlastic
    attach(tray, CFrame.new(0, -0.58, 2.49))
    for index = 1, profile.Carry do
        local shape = CarryGeometry.Brick(index, profile.Strength, profile.StolenRound ~= nil)
        local block = Instance.new("Part")
        block.Name = "MaterialBrick"
        block:SetAttribute("MaterialIndex", index)
        block.Size, block.Color = shape.Size, shape.Color
        block.Material = Enum.Material.SmoothPlastic
        attach(block, shape.Offset)
    end
end

function Service:AnimateDeposit(player, amount, target, effectKind)
    local profile = self.Profiles:Get(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not profile or not root then return end
    local blocks = {}
    -- Remove the top bricks first. Remaining materials stay attached if the
    -- completed tower accepted only part of the player's load.
    for index = profile.Carry, math.max(1, profile.Carry - amount + 1), -1 do
        local shape = CarryGeometry.Brick(index, profile.Strength, profile.StolenRound ~= nil)
        table.insert(blocks, {CFrame = root.CFrame * shape.Offset, Size = shape.Size, Color = shape.Color})
    end
    self.Depositing[player] = os.clock() + DEPOSIT_DURATION
    player:SetAttribute("Depositing", true)
    player:SetAttribute("DepositEffectKind", effectKind or "DepositEffect")
    task.delay(DEPOSIT_DURATION, function()
        if player.Parent == Players and os.clock() >= (self.Depositing[player] or 0) then
            player:SetAttribute("Depositing", false)
        end
    end)
    self.StateRemote:FireAllClients(effectKind or "DepositEffect", {
        UserId = player.UserId, Blocks = blocks, Amount = amount,
        Target = target or Config.Positions.Build + Vector3.new(0, -0.8, -2),
        Duration = DEPOSIT_DURATION, Stage = self.Construction.Stage,
    })
end

function Service:IsNear(player, key)
    local station = self.World.Stations[key]
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return station ~= nil and root ~= nil and humanoid ~= nil and humanoid.Health > 0
        and (root.Position - station.Position).Magnitude <= Config.InteractionDistance
end

function Service:Celebrate()
    self.Sabotage:Reset()
    self.ResetAt = os.clock() + Config.CelebrationSeconds
    self.Workers:SetWorking(false)
    if self.World.SetCelebrating then self.World:SetCelebrating(true) end
    for _, player in Players:GetPlayers() do
        local profile = self.Profiles:Get(player)
        if profile and (self.Construction.Contributions[player.UserId] or 0) > 0 then
            local reward = 500 + math.min(2000, self.Construction.Contributions[player.UserId])
            profile.Coins += reward
            profile.Wins += 1
            self.StateRemote:FireClient(player, "Complete", {Reward = reward, Round = self.Construction.Round})
        end
    end
    print("BURJ_TOWER_COMPLETE", self.Construction.Round)
end

function Service:Deposit(player, amount, automatic)
    local profile = self.Profiles:Get(player)
    if not profile or self.Construction.Complete then return 0 end
    if not automatic and profile.StolenRound then return 0 end
    local accepted, stages = Construction.Deposit(self.Construction, amount, player.UserId)
    if accepted == 0 then return 0 end
    profile.Coins += accepted * 3
    profile.Contributed += accepted
    if not automatic then
        self:AnimateDeposit(player, accepted)
        profile.Carry -= accepted
        self:CarryVisual(player)
    end
    if stages > 0 then
        self.World:SetStage(self.Construction.Stage, true)
        self.StateRemote:FireAllClients("FloorsBuilt", {
            FromStage = self.Construction.Stage - stages + 1, ToStage = self.Construction.Stage,
            Round = self.Construction.Round,
        })
    end
    if not automatic then self:Toast(player, string.format("자재 %d개 전달! +%d 코인", accepted, accepted * 3), "success") end
    if self.Construction.Complete then self:Celebrate()
    elseif stages > 0 then
        for _, other in Players:GetPlayers() do
            self:Toast(other, string.format("건설 %d / %d단계 · 함께 높이 올라가요!", self.Construction.Stage, Config.MaxStages), "success")
        end
    end
    self:Broadcast()
    return accepted
end

function Service:Upgrade(player, kind)
    local profile = self.Profiles:Get(player)
    if not Config.UpgradeNames[kind] then return false end
    local level = profile[kind]
    if level >= Config.MaxUpgradeLevel then self:Toast(player, "최고 레벨에 도달했어요!", "info"); return false end
    local cost = Config.UpgradeCost(kind, level)
    if profile.Coins < cost then self:Toast(player, string.format("코인이 %d개 더 필요해요. 자재를 운반해 보세요!", cost - profile.Coins), "error"); return false end
    profile.Coins -= cost
    profile[kind] += 1
    if kind == "Speed" then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = Config.WalkSpeed(profile.Speed) end
    elseif kind == "Worker" then
        self.Workers:Ensure(player, profile.Worker)
    end
    self:Toast(player, Config.UpgradeNames[kind] .. " 레벨 " .. profile[kind] .. "!", "success")
    self:Sync(player)
    return true
end

function Service:HandleAction(player, action, value)
    if type(action) ~= "string" or #action > 24 or (value ~= nil and (type(value) ~= "string" or #value > 24)) then return false end
    if self.Leaving[player] or not self.Profiles:Get(player) then return false end
    if action == "EndSteal" then return self.Sabotage:EndHold(player) end
    if player:GetAttribute("PrankStunned") then return false end
    if action == "FinishSteal" then return self.Sabotage:Finish(player) end
    local now = os.clock()
    if (action == "Interact" or action == "BeginSteal") and now < (self.Depositing[player] or 0) then return false end
    if self.Sabotage.Pending[player] then return false end
    if now - (self.LastAction[player] or -math.huge) < Config.ActionCooldown then return false end
    self.LastAction[player] = now
    local profile = self.Profiles:Get(player)
    if action == "BeginSteal" then
        return self.Sabotage:Start(player)
    elseif action == "TryPrank" then
        return self.Pranks:TryInStudio(player, value)
    elseif action == "LoadPranks" then
        if not self.Pranks.Ready[player] then task.spawn(function() self.Pranks:Load(player) end) end
        return true
    elseif action == "Upgrade" then
        return self:Upgrade(player, value)
    elseif action == "Return" then
        if profile.StolenRound then self.Sabotage:Cancel(player, "현장으로 돌아와 빼돌리기를 취소했어요.") end
        if player.Character then player.Character:PivotTo(CFrame.new(Config.Positions.Spawn)); return true end
    elseif action == "Interact" then
        if not self:IsNear(player, value) then self:Toast(player, "작업 지점 가까이 이동해 주세요.", "error"); return false end
        if profile.StolenRound and (value == "Supply" or value == "Build" or value == "Lookout") then
            self:Toast(player, "빼돌린 자재는 분홍 쓰레기통에 가져가세요.")
            return false
        end
        if value == "Supply" then
            if self.Construction.Complete then self:Toast(player, "완공 축하 중이에요! 잠시 뒤 새 공사가 시작돼요."); return false end
            local capacity = Config.Capacity(profile.Strength)
            if profile.Carry >= capacity then self:Toast(player, "가방이 가득 찼어요. 노란 건설 구역에 전달하세요."); return false end
            profile.Carry = capacity
            self:CarryVisual(player)
            self:Toast(player, "자재를 챙겼어요! 노란 건설 구역으로 이동하세요.", "success")
            self:Sync(player)
            return true
        elseif value == "Build" then
            if profile.Carry <= 0 then self:Toast(player, "초록색 자재 구역에서 먼저 자재를 챙겨 주세요."); return false end
            return self:Deposit(player, profile.Carry, false) > 0
        elseif value == "Steal" then
            return false -- Stealing requires a complete press-and-hold interaction.
        elseif value == "Trash" then
            return self.Sabotage:Discard(player)
        elseif value == "Lookout" then
            if self.Construction.Stage < 1 then self:Toast(player, "첫 단계를 완성하면 전망대가 열려요."); return false end
            player.Character:PivotTo(self.World:GetLookoutCFrame())
            self:Toast(player, "직접 지은 타워에 올라왔어요! 아래의 현장 복귀 버튼으로 돌아가세요.")
            return true
        elseif Config.UpgradeNames[value] then
            self.StateRemote:FireClient(player, "OpenShop", {Kind = value})
            return true
        end
    end
    return false
end

function Service:PlayerAdded(player)
    local profile, problem = self.Profiles:Load(player)
    if not profile then
        warn("BURJ_PROFILE_LOAD_FAILED", player.UserId, problem)
        player:Kick("진행 상황을 안전하게 불러오지 못했어요. 잠시 후 다시 접속해 주세요.")
        return
    end
    if player.Parent ~= Players then self.Profiles:Close(player); return end
    local stats = Instance.new("Folder")
    stats.Name, stats.Parent = "leaderstats", player
    for _, name in {"Coins", "Built", "Wins"} do
        local stat = Instance.new("IntValue")
        stat.Name, stat.Parent = name, stats
    end
    local function characterAdded(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        humanoid.WalkSpeed = Config.WalkSpeed(profile.Speed)
        humanoid.Died:Connect(function() self.Sabotage:Cancel(player) end)
        self:CarryVisual(player)
        if self.Pranks.Ready[player] then self.Pranks:Refresh(player) end
        self:Sync(player)
    end
    player.CharacterAdded:Connect(characterAdded)
    player.CharacterRemoving:Connect(function() self.Sabotage:Cancel(player) end)
    if player.Character then task.spawn(characterAdded, player.Character) end
    self.Workers:Ensure(player, profile.Worker)
    task.spawn(function() self.Pranks:Load(player) end)
    self:Sync(player)
    print("BURJ_PLAYER_READY", player.UserId)
end

function Service:Start()
    if self.Started then return self end
    self.Started = true
    self.Leaving, self.LastAction, self.LastSnapshot, self.Depositing = {}, {}, {}, {}
    self.Profiles = Profiles.new(Config)
    self.Construction = Construction.new()
    self.World = World.Create(Config)
    self.World:SetStage(0)
    local remotes = Instance.new("Folder")
    remotes.Name, remotes.Parent = "Remotes", ReplicatedStorage
    local action = Instance.new("RemoteEvent")
    action.Name, action.Parent = "Action", remotes
    self.StateRemote = Instance.new("RemoteEvent")
    self.StateRemote.Name, self.StateRemote.Parent = "State", remotes
    self.Workers = Workers.new(self)
    self.Pranks = Pranks.new(self)
    self.Sabotage = Sabotage.new(self)
    local getState = Instance.new("RemoteFunction")
    getState.Name, getState.Parent = "GetState", remotes
    getState.OnServerInvoke = function(player)
        local now = os.clock()
        if now - (self.LastSnapshot[player] or -math.huge) < 0.25 then return nil end
        self.LastSnapshot[player] = now
        return self:Snapshot(player)
    end
    action.OnServerEvent:Connect(function(player, kind, value) self:HandleAction(player, kind, value) end)
    local stealPrompt = self.World.Stations.Steal:FindFirstChildOfClass("ProximityPrompt")
    ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
        if prompt == stealPrompt and not self:HandleAction(player, "BeginSteal") then
            self.StateRemote:FireClient(player, "TheftDenied", {})
            self:Sync(player)
        end
    end)
    ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
        if prompt == stealPrompt then self:HandleAction(player, "EndSteal") end
    end)
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if prompt == stealPrompt then self:HandleAction(player, "FinishSteal"); return end
        local key = prompt:GetAttribute("Action") or (prompt.Parent and prompt.Parent:GetAttribute("Action"))
        if key == "Return" and prompt:IsDescendantOf(self.World.Root) then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and prompt.Parent:IsA("BasePart") and (root.Position - prompt.Parent.Position).Magnitude <= Config.InteractionDistance then
                self:HandleAction(player, "Return")
            end
            return
        end
        if type(key) == "string" and self.World.Stations[key] == prompt.Parent then self:HandleAction(player, "Interact", key) end
    end)
    Players.PlayerAdded:Connect(function(player) task.spawn(function() self:PlayerAdded(player) end) end)
    Players.PlayerRemoving:Connect(function(player)
        self.Leaving[player] = true
        self.Workers:Remove(player)
        self.Pranks:Remove(player)
        self.Sabotage:Cancel(player)
        self.Profiles:Close(player)
        self.LastAction[player], self.LastSnapshot[player], self.Leaving[player] = nil, nil, nil
        self.Depositing[player] = nil
    end)
    for _, player in Players:GetPlayers() do task.spawn(function() self:PlayerAdded(player) end) end
    task.spawn(function()
        while self.Started do
            task.wait(0.1)
            if self.Started then self.Workers:Step(workspace:GetServerTimeNow()); self.Pranks:Step(); self.Sabotage:Step() end
        end
    end)
    task.spawn(function()
        while self.Started do
            task.wait(1)
            if self.Construction.Complete then
                if os.clock() >= self.ResetAt then
                    for _, player in Players:GetPlayers() do
                        if player.Character then player.Character:PivotTo(CFrame.new(Config.Positions.Spawn)) end
                    end
                    Construction.Reset(self.Construction)
                    self.Sabotage:Reset()
                    if self.World.SetCelebrating then self.World:SetCelebrating(false) end
                    self.World:SetStage(0)
                    self.Workers:SetWorking(true)
                end
                self:Broadcast()
            end
        end
    end)
    task.spawn(function()
        while self.Started do
            task.wait(40)
            for _, player in Players:GetPlayers() do
                if not self.Leaving[player] then task.spawn(function()
                    local ok, err = self.Profiles:Save(player)
                    if not ok then
                        warn("BURJ_SAVE_FAILED", player.UserId, err)
                        if not self.Leaving[player] and player.Parent == Players and not self.Profiles:Get(player) then
                            player:Kick("저장 세션이 변경되었어요. 진행 상황을 보호하기 위해 다시 접속해 주세요.")
                        else
                            self:Toast(player, "저장이 지연되고 있어요. 연결 상태를 확인해 주세요.", "error")
                        end
                    end
                    self:Sync(player)
                end) end
            end
        end
    end)
    game:BindToClose(function() self.Started = false; self.Workers:Destroy(); self.Pranks:Destroy(); self.Profiles:Shutdown() end)
    print("BURJ_SERVER_READY", Config.MaxStages, Config.TotalCost())
    return self
end
return Service
