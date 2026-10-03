local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Motion = require(ReplicatedStorage.Shared.WorkerMotion)
local CarryGeometry = require(ReplicatedStorage.Shared.CarryGeometry)
local Workers = {}
Workers.__index = Workers

local function part(model, name, size, color, position)
    local object = Instance.new("Part")
    object.Name, object.Size, object.Color = name, size, color
    object.Material = Enum.Material.SmoothPlastic
    object.CFrame, object.Parent = CFrame.new(position), model
    return object
end

local function joint(parent, name, a, b, offset)
    local motor = Instance.new("Motor6D")
    motor.Name, motor.Part0, motor.Part1, motor.C0 = name, a, b, offset
    motor.Parent = parent
end

-- An entirely local rig keeps hiring responsive when avatar APIs are unavailable.
function Workers.Fallback()
    local model = Instance.new("Model")
    local skin, mint = Color3.fromRGB(255, 220, 175), Color3.fromRGB(132, 211, 185)
    local navy = Color3.fromRGB(102, 118, 160)
    local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), mint, Vector3.zero)
    root.Transparency = 1
    local torso = part(model, "Torso", Vector3.new(2, 2, 1), mint, Vector3.zero)
    local head = part(model, "Head", Vector3.new(2, 1, 1), skin, Vector3.new(0, 1.5, 0))
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType, mesh.Scale, mesh.Parent = Enum.MeshType.Head, Vector3.new(1.25, 1.25, 1.25), head
    local face = Instance.new("Decal")
    face.Texture, face.Face, face.Parent = "rbxasset://textures/face.png", Enum.NormalId.Front, head
    joint(root, "RootJoint", root, torso, CFrame.identity)
    joint(torso, "Neck", torso, head, CFrame.new(0, 1.5, 0))
    for _, side in {"Left", "Right"} do
        local sign = side == "Left" and -1 or 1
        local arm = part(model, side .. " Arm", Vector3.new(1, 2, 1), skin, Vector3.new(sign * 1.5, 0, 0))
        local leg = part(model, side .. " Leg", Vector3.new(1, 2, 1), navy, Vector3.new(sign * 0.5, -2, 0))
        joint(torso, side .. " Shoulder", torso, arm, CFrame.new(sign * 1.5, 0, 0))
        joint(torso, side .. " Hip", torso, leg, CFrame.new(sign * 0.5, -2, 0))
    end
    local helmet = part(model, "HardHat", Vector3.new(2.2, 0.65, 1.3), Color3.fromRGB(255, 206, 96), Vector3.new(0, 2.15, 0))
    helmet.Shape = Enum.PartType.Ball
    local weld = Instance.new("WeldConstraint")
    weld.Part0, weld.Part1, weld.Parent = head, helmet, helmet
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = model
    model.PrimaryPart = root
    return model
end

function Workers.new(service, dependencies)
    local self = setmetatable({}, Workers)
    self.Service, self.Owners, self.Working = service, {}, true
    self.Random = Random.new()
    dependencies = dependencies or {}
    self.GetFriends = dependencies.GetFriends or function(userId) return Players:GetFriendsAsync(userId) end
    self.CreateAvatar = dependencies.CreateAvatar or function(userId) return Players:CreateHumanoidModelFromUserIdAsync(userId) end
    self.Folder = Instance.new("Folder")
    self.Folder.Name, self.Folder.Parent = "BurjWorkers", workspace
    return self
end

function Workers:IsActive(owner)
    return self.Owners[owner.Player] == owner and owner.Player.Parent == Players
end

function Workers:UpdateLoad(model, level)
    local root = model.PrimaryPart
    local capacity = Config.WorkerCapacity(level)
    local stack = model:FindFirstChild("WorkerMaterials")
    if not stack then
        stack = Instance.new("Model")
        stack.Name, stack.Parent = "WorkerMaterials", model
    end
    local previous = stack:GetAttribute("MaterialCount") or 0
    for _, block in stack:GetChildren() do
        local index = block:GetAttribute("MaterialIndex")
        if index and index > capacity then block:Destroy()
        elseif index then block.Color = CarryGeometry.Brick(index, level).Color end
    end
    for index = previous + 1, capacity do
        local shape = CarryGeometry.Brick(index, level)
        local block = part(nil, "MaterialBrick", shape.Size, shape.Color, Vector3.zero)
        block:SetAttribute("MaterialIndex", index)
        block.CFrame = root.CFrame * shape.Offset
        block.CanCollide, block.CanTouch, block.CanQuery, block.Massless = false, false, false, true
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = root, block, block
        block.Parent = stack
    end
    stack:SetAttribute("MaterialCount", capacity)
    stack:SetAttribute("LayerCount", CarryGeometry.LayerCount(capacity))
    model:SetAttribute("WorkerLevel", level)
    model:SetAttribute("Capacity", capacity)
end

function Workers:Prepare(model, owner, record, friend)
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    assert(root and humanoid, "Worker avatar is missing its rig")
    for _, object in model:GetDescendants() do
        if object:IsA("BaseScript") then object:Destroy()
        elseif object:IsA("BasePart") then
            object.Anchored = object == root
            object.CanCollide, object.CanTouch, object.CanQuery, object.Massless = false, false, false, true
        end
    end
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.AutoRotate, humanoid.BreakJointsOnDeath = false, false
    local height = 1 + root.Size.Y / 2 + humanoid.HipHeight
    local leg = model:FindFirstChild("Left Leg")
    if leg then height += leg.Size.Y end
    model.PrimaryPart, model.Name = root, "Worker_" .. owner.Player.UserId .. "_" .. record.Slot
    model:SetAttribute("OwnerId", owner.Player.UserId)
    model:SetAttribute("Slot", record.Slot)
    model:SetAttribute("StartedAt", record.StartedAt)
    model:SetAttribute("RootHeight", height)
    model:SetAttribute("Working", self.Working)
    model:SetAttribute("FriendId", friend and friend.Id or 0)
    model:SetAttribute("AvatarSource", friend and "Friend" or "Fallback")
    local initial = Motion.Sample(workspace:GetServerTimeNow(), record.StartedAt, record.Slot, height, self.Working)
    model:PivotTo(initial)

    self:UpdateLoad(model, record.Level)
    return model
end

function Workers:LoadRoster(owner)
    local friends, seen = {}, {}
    local ok = pcall(function()
        if owner.Player.UserId <= 0 then return end
        local pages = self.GetFriends(owner.Player.UserId)
        while self:IsActive(owner) do
            for _, friend in pages:GetCurrentPage() do
                if type(friend.Id) == "number" and friend.Id > 0 and not seen[friend.Id] then
                    seen[friend.Id] = true
                    table.insert(friends, friend)
                end
            end
            if pages.IsFinished then break end
            pages:AdvanceToNextPageAsync()
        end
    end)
    -- Keep any successfully loaded pages if a later page request fails.
    for index = #friends, 2, -1 do
        local other = self.Random:NextInteger(1, index)
        friends[index], friends[other] = friends[other], friends[index]
    end
    owner.Friends, owner.RosterReady, owner.RosterStatus = friends, true, ok and (#friends > 0 and "Ready" or "Empty") or "Unavailable"
    if self:IsActive(owner) then owner.Player:SetAttribute("WorkerRosterStatus", owner.RosterStatus) end
end

function Workers:LoadAvatars(owner)
    if owner.Loading then return end
    owner.Loading = true
    task.spawn(function()
        if not owner.RosterReady then self:LoadRoster(owner) end
        while self:IsActive(owner) do
            local record
            for _, candidate in owner.Records do
                if not candidate.AvatarAttempted then record = candidate; break end
            end
            if not record then break end
            record.AvatarAttempted = true
            local friends = owner.Friends
            if #friends > 0 then
                local friend = friends[(record.Slot - 1) % #friends + 1]
                local ok, avatar = pcall(self.CreateAvatar, friend.Id)
                if ok and typeof(avatar) == "Instance" and avatar:IsA("Model") then
                    if not self:IsActive(owner) or owner.Records[record.Slot] ~= record then avatar:Destroy(); break end
                    local prepared = pcall(function() self:Prepare(avatar, owner, record, friend) end)
                    if prepared then
                        record.Model:Destroy()
                        record.Model, avatar.Parent = avatar, self.Folder
                    else
                        avatar:Destroy()
                    end
                end
            end
        end
        owner.Loading = false
    end)
end

function Workers:Ensure(player, level)
    level = math.clamp(math.floor(level), 0, Config.MaxUpgradeLevel)
    if level == 0 then self:Remove(player); return end
    local owner = self.Owners[player]
    if not owner then
        owner = {Player = player, Records = {}, Friends = {}, RosterReady = false}
        self.Owners[player] = owner
    end
    -- Saved Worker levels now strengthen one carrier, rather than hiring a crowd.
    for index = #owner.Records, 2, -1 do
        owner.Records[index].Model:Destroy()
        owner.Records[index] = nil
    end
    local record = owner.Records[1]
    if record then
        if record.Level ~= level then
            record.Level = level
            self:UpdateLoad(record.Model, level)
        end
    else
        local startedAt = workspace:GetServerTimeNow()
        record = {Slot = 1, Level = level, StartedAt = startedAt, NextDelivery = startedAt + Config.WorkerInterval * Motion.DeliveryFraction}
        record.Model = self:Prepare(Workers.Fallback(), owner, record)
        record.Model.Parent = self.Folder
        owner.Records[1] = record
    end
    self:LoadAvatars(owner)
end

function Workers:SetWorking(working)
    if self.Working == working then return end
    self.Working = working
    for _, owner in self.Owners do
        for _, record in owner.Records do
            if working then
                record.StartedAt = workspace:GetServerTimeNow() + (record.Slot - 1) * 0.23
                record.NextDelivery = record.StartedAt + Config.WorkerInterval * Motion.DeliveryFraction
                record.Model:SetAttribute("StartedAt", record.StartedAt)
            end
            record.Model:SetAttribute("Working", working)
        end
    end
end

function Workers:Step(now)
    if not self.Working then return end
    for player, owner in self.Owners do
        if not self.Service.Leaving[player] and self.Service.Profiles:Get(player) then
            for _, record in owner.Records do
                if now >= record.NextDelivery and self.Working then
                    -- Advance before awarding, so one arrival can never pay twice.
                    record.NextDelivery += (math.floor((now - record.NextDelivery) / Config.WorkerInterval) + 1) * Config.WorkerInterval
                    local accepted = self.Service:Deposit(player, Config.WorkerCapacity(record.Level), true)
                    if accepted > 0 then
                        local root = Motion.Sample(record.StartedAt + Config.WorkerInterval * Motion.DeliveryFraction,
                            record.StartedAt, record.Slot, record.Model:GetAttribute("RootHeight"), true)
                        local blocks = {}
                        for index = 1, accepted do
                            local shape = CarryGeometry.Brick(index, record.Level)
                            table.insert(blocks, {CFrame = root * shape.Offset, Size = shape.Size, Color = shape.Color})
                        end
                        self.Service.StateRemote:FireAllClients("DepositEffect", {
                            UserId = player.UserId, WorkerSlot = record.Slot, Blocks = blocks, Amount = accepted,
                            Target = Config.Positions.Build + Vector3.new(0, -0.8, -2), Duration = 0.7,
                            Stage = self.Service.Construction.Stage,
                        })
                        record.Model:SetAttribute("Deliveries", (record.Model:GetAttribute("Deliveries") or 0) + 1)
                    end
                end
            end
        end
    end
end

function Workers:Remove(player)
    local owner = self.Owners[player]
    self.Owners[player] = nil
    if owner then
        for _, record in owner.Records do record.Model:Destroy() end
    end
end

function Workers:Destroy()
    for player in self.Owners do self:Remove(player) end
    self.Folder:Destroy()
end

return Workers
