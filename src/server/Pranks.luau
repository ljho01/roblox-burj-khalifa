local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Catalog = require(game.ReplicatedStorage.Shared.PrankCatalog)
local Config = require(game.ReplicatedStorage.Shared.Config)
local CarryGeometry = require(game.ReplicatedStorage.Shared.CarryGeometry)
local Inventory = require(script.Parent.PrankInventory)
local Pranks = {}
Pranks.__index = Pranks

local function body(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if root and human and human.Health > 0 then return root, human end
end

local function part(parent, name, size, color, cf, anchored)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Color, p.CFrame = name, size, color, cf
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = anchored == true, false, false, false
    p.Massless = true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function Pranks.new(service)
    local self = setmetatable({Service = service, Inventory = Inventory.new(), Busy = {}, LastUse = {}, Stuns = {}, Traps = {}, Ready = {}, Alive = true}, Pranks)
    self.Folder = Instance.new("Folder")
    self.Folder.Name, self.Folder.Parent = "BurjBananas", workspace
    self.Products = {}
    for kind, item in pairs(Catalog.Items) do
        if item.ProductId > 0 then
            assert(not self.Products[item.ProductId], "Duplicate prank product ID")
            self.Products[item.ProductId] = kind
        end
    end
    MarketplaceService.ProcessReceipt = function(receipt) return self:ProcessReceipt(receipt) end
    return self
end

function Pranks:ProcessReceipt(receipt)
    local deferred = Enum.ProductPurchaseDecision.NotProcessedYet
    local kind = self.Products[receipt.ProductId]
    local player = Players:GetPlayerByUserId(receipt.PlayerId)
    if not kind or not player or not self.Alive then return deferred end
    local deadline = os.clock() + 20
    while not self.Ready[player] and player.Parent == Players and self.Alive and os.clock() < deadline do task.wait(.2) end
    if not self.Ready[player] or not self.Service.Profiles:Get(player) then return deferred end
    if not self.Inventory:Grant(player.UserId, receipt.PurchaseId, kind) then return deferred end
    if player.Parent == Players and self.Ready[player] then
        self:Refresh(player)
        self.Service:Toast(player, Catalog.Items[kind].Name .. " 사용권이 도착했어요! 아래 가방에서 꺼내 쓰세요.", "success")
    end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Pranks:Snapshot(player)
    return {Counts = self.Inventory:Counts(player.UserId), Ready = self.Ready[player] == true, Studio = RunService:IsStudio()}
end

function Pranks:Load(player)
    local result = self.Inventory:Load(player.UserId)
    if not self.Alive or player.Parent ~= Players then self.Inventory:Remove(player.UserId); return end
    if not result then
        self.Service:Toast(player, "장난감 가방을 불러오지 못했어요. 잠시 후 다시 열어 주세요.", "error")
        return
    end
    self.Ready[player] = true
    self:Refresh(player)
end

function Pranks:MakeTool(player, kind)
    local item = Catalog.Items[kind]
    local tool = Instance.new("Tool")
    tool.Name, tool.ToolTip = item.Name, "장착 후 클릭 / 화면 터치 · " .. (kind == "Banana" and "바닥에 놓기" or "가까운 상대에게 사용")
    tool.CanBeDropped, tool.RequiresHandle = false, true
    tool:SetAttribute("PrankKind", kind)
    local colors = {Slap = Color3.fromRGB(255, 183, 174), Bat = Color3.fromRGB(191, 166, 235), Banana = Color3.fromRGB(255, 226, 101)}
    local handle = part(tool, "Handle", Vector3.new(.35, 1.4, .35), colors[kind], CFrame.new())
    local function detail(name, size, offset, color, shape)
        local p = part(tool, name, size, color or colors[kind], handle.CFrame * offset)
        if shape then p.Shape = shape end
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = handle, p, p
        return p
    end
    if kind == "Slap" then
        detail("SoftPalm", Vector3.new(1.35, 1.2, .36), CFrame.new(0, 1.1, 0))
        for i = 1, 4 do detail("Finger", Vector3.new(.28, .7 + (i % 2) * .16, .35), CFrame.new((i - 2.5) * .34, 1.91, 0), nil, Enum.PartType.Ball) end
        detail("Thumb", Vector3.new(.35, .8, .35), CFrame.new(-.85, 1.15, 0) * CFrame.Angles(0, 0, -.5))
    elseif kind == "Bat" then
        detail("FoamBat", Vector3.new(.85, 2.7, .85), CFrame.new(0, 1.8, 0), nil, Enum.PartType.Ball)
        detail("GripRibbon", Vector3.new(.48, .25, .48), CFrame.new(0, -.35, 0), Color3.fromRGB(255, 221, 153))
    else
        for i = -1, 1 do detail("Banana", Vector3.new(.6, 1.0, .6), CFrame.new(i * .32, .65 + .28 * i * i, 0) * CFrame.Angles(0, 0, -i * .5), nil, Enum.PartType.Ball) end
    end
    tool.Grip = CFrame.new(0, -.2, 0)
    tool.Activated:Connect(function() self:Use(player, kind, tool) end)
    return tool
end

function Pranks:Refresh(player)
    if player.Parent ~= Players then return end
    local counts = self.Inventory:Counts(player.UserId)
    player:SetAttribute("HasPrankTools", counts.Slap + counts.Bat + counts.Banana > 0)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, kind in ipairs(Catalog.Order) do
            local found
            for _, parent in ipairs({backpack, player.Character}) do
                for _, child in parent:GetChildren() do
                    if child:IsA("Tool") and child:GetAttribute("PrankKind") == kind then
                        if counts[kind] <= 0 or found then child:Destroy() else found = child end
                    end
                end
            end
            if counts[kind] > 0 and not found then found = self:MakeTool(player, kind); found.Parent = backpack end
            if found then found:SetAttribute("Uses", counts[kind]) end
        end
    end
    self.Service:Sync(player)
end

function Pranks:TryInStudio(player, kind)
    if not RunService:IsStudio() or not self.Ready[player] or not Catalog.Items[kind] then return false end
    if self.Inventory:Counts(player.UserId)[kind] >= 5 then return false end
    if not self.Inventory:Grant(player.UserId, "studio-" .. HttpService:GenerateGUID(false), kind) then return false end
    self:Refresh(player)
    self.Service:Toast(player, "Studio 무료 체험 · " .. Catalog.Items[kind].Name .. " 1회 지급!", "success")
    return true
end

function Pranks:CanHit(attacker, target, kind)
    if attacker == target or not self.Service.Profiles:Get(target) or target:GetAttribute("PrankStunned") then return false end
    local a = body(attacker)
    local b = body(target)
    if not a or not b then return false end
    local delta = b.Position - a.Position
    if delta.Magnitude > Catalog.Items[kind].Range or delta.Magnitude < .01 or math.abs(delta.Y) > 5 then return false end
    if a.CFrame.LookVector:Dot(delta.Unit) < .25 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {attacker.Character, self.Folder, self.Service.Workers.Folder}
    local hit = workspace:Raycast(a.Position, delta, params)
    return not hit or hit.Instance:IsDescendantOf(target.Character)
end

function Pranks:FindTarget(player, kind)
    local root = body(player)
    if not root then return end
    local best, distance
    for _, other in Players:GetPlayers() do
        if self:CanHit(player, other, kind) then
            local d = (other.Character.HumanoidRootPart.Position - root.Position).Magnitude
            if not distance or d < distance then best, distance = other, d end
        end
    end
    return best
end

function Pranks:DropAndStun(victim, origin, kind)
    local root, human = body(victim)
    local profile = self.Service.Profiles:Get(victim)
    if not root or not profile or victim:GetAttribute("PrankStunned") then return false end
    local stoppedTheft = self.Service.Sabotage.Pending[victim] ~= nil or profile.StolenRound ~= nil
    local amount, blocks = profile.Carry, {}
    for i = 1, amount do
        local shape = CarryGeometry.Brick(i, profile.Strength, profile.StolenRound ~= nil)
        table.insert(blocks, {CFrame = root.CFrame * shape.Offset, Size = shape.Size, Color = shape.Color})
    end
    self.Service.Sabotage:Cancel(victim)
    profile.Carry = 0
    self.Service:CarryVisual(victim)
    self.Service:Sync(victim)
    local token = {}
    self.Stuns[victim] = token
    victim:SetAttribute("PrankStunned", true)
    human.PlatformStand = true
    local direction = Vector3.new(root.Position.X - origin.X, 0, root.Position.Z - origin.Z)
    if direction.Magnitude < .01 then direction = root.CFrame.LookVector end
    pcall(function() root:SetNetworkOwner(nil) end)
    root.AssemblyLinearVelocity = direction.Unit * (kind == "Bat" and 27 or 17) + Vector3.new(0, 15, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, kind == "Banana" and 7 or 3)
    self.Service.StateRemote:FireAllClients("PrankHit", {UserId = victim.UserId, Kind = kind, Origin = root.Position, Blocks = blocks, Amount = amount})
    self.Service:Toast(victim, stoppedTheft and "들켰어요! 빼돌리기가 취소되고 자재가 공사장에 남았어요." or amount > 0 and string.format("앗! 자재 %d개가 우수수! 창고에서 다시 챙겨요.", amount) or "앗, 깜짝이야!", "info")
    task.delay(1.15, function()
        if self.Stuns[victim] ~= token then return end
        self.Stuns[victim] = nil
        victim:SetAttribute("PrankStunned", false)
        if human.Parent and human.Health > 0 then
            human.PlatformStand = false
            human:ChangeState(Enum.HumanoidStateType.GettingUp)
            root.AssemblyAngularVelocity = Vector3.zero
            pcall(function() root:SetNetworkOwnershipAuto() end)
        end
    end)
    return true, stoppedTheft
end

function Pranks:BananaPosition(player)
    local root = body(player)
    if not root then return end
    local ignored = {self.Folder, self.Service.Workers.Folder}
    for _, other in Players:GetPlayers() do if other.Character then table.insert(ignored, other.Character) end end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored
    local forward = root.CFrame.LookVector * 3
    local wall = workspace:Raycast(root.Position, forward, params)
    if wall then return end
    local ground = workspace:Raycast(root.Position + forward + Vector3.new(0, 1, 0), Vector3.new(0, -8, 0), params)
    if ground and ground.Normal.Y > .8 then return ground.Position + Vector3.new(0, .15, 0) end
end

function Pranks:PlaceBanana(player, position)
    local model = Instance.new("Model")
    model.Name = "BananaPeel"
    model:SetAttribute("OwnerId", player.UserId)
    model.Parent = self.Folder
    part(model, "Stem", Vector3.new(.45, .8, .45), Color3.fromRGB(247, 202, 71), CFrame.new(position + Vector3.new(0, .45, 0)), true)
    for i = 1, 3 do
        local cf = CFrame.new(position) * CFrame.Angles(0, i * math.pi * 2 / 3, 0) * CFrame.new(0, .12, -.65) * CFrame.Angles(.22, 0, 0)
        local peel = part(model, "Peel", Vector3.new(.72, .24, 1.8), Color3.fromRGB(255, 231, 111), cf, true)
        peel.Shape = Enum.PartType.Ball
    end
    table.insert(self.Traps, {Owner = player, Model = model, Position = position, ArmedAt = os.clock() + .6, Expires = os.clock() + 90})
    Debris:AddItem(model, 91)
end

function Pranks:Use(player, kind, tool)
    if not Catalog.Items[kind] or not self.Ready[player] or self.Busy[player] or player:GetAttribute("PrankStunned") or self.Service.Sabotage.Pending[player] then return false end
    if not tool or tool.Parent ~= player.Character or tool:GetAttribute("PrankKind") ~= kind or not body(player) then return false end
    if os.clock() - (self.LastUse[player] or -math.huge) < 1.5 then return false end
    self.LastUse[player] = os.clock()
    local target, placement
    if kind == "Banana" then
        local own = 0
        for _, trap in self.Traps do if trap.Owner == player then own += 1 end end
        if own >= 2 or #self.Traps >= 32 then self.Service:Toast(player, "먼저 놓은 바나나가 사라지면 다시 놓을 수 있어요."); return false end
        placement = self:BananaPosition(player)
        if not placement then self.Service:Toast(player, "평평한 바닥 가까이에서 놓아 주세요."); return false end
    else
        target = self:FindTarget(player, kind)
        TweenService:Create(tool, TweenInfo.new(.14), {Grip = CFrame.new(0, -.2, 0) * CFrame.Angles(0, 0, -1.6)}):Play()
        task.delay(.18, function() if tool.Parent then TweenService:Create(tool, TweenInfo.new(.18), {Grip = CFrame.new(0, -.2, 0)}):Play() end end)
        if not target then self.Service:Toast(player, "가까운 친구를 바라보고 사용해요. 사용권은 그대로예요!"); return false end
    end
    self.Busy[player] = true
    local used = self.Inventory:Consume(player.UserId, kind)
    if used and player.Parent == Players then
        -- The server selected the target/position before the durable consume.
        -- No client-supplied target, amount, or arbitrary trap position is used.
        if kind == "Banana" then self:PlaceBanana(player, placement)
        else
            local hit, stoppedTheft = self:DropAndStun(target, player.Character and player.Character:GetPivot().Position or Vector3.zero, kind)
            if hit and stoppedTheft then self.Service:Toast(player, "빼돌리기를 막았어요! 자재를 지켰어요.", "success") end
        end
    elseif not used then
        self.Service:Toast(player, "사용권을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.", "error")
    end
    task.delay(.4, function() if self.Ready[player] then self:Refresh(player) end end)
    self.Busy[player] = nil
    return used
end

function Pranks:Step()
    for i = #self.Traps, 1, -1 do
        local trap = self.Traps[i]
        local remove = not trap.Model.Parent or os.clock() >= trap.Expires or trap.Owner.Parent ~= Players
        if not remove and os.clock() >= trap.ArmedAt then
            for _, player in Players:GetPlayers() do
                local root = body(player)
                if player ~= trap.Owner and root and math.abs(root.Position.Y - trap.Position.Y) < 5
                    and (Vector3.new(root.Position.X, trap.Position.Y, root.Position.Z) - trap.Position).Magnitude < 2.8 then
                    if self:DropAndStun(player, trap.Position, "Banana") then remove = true; break end
                end
            end
        end
        if remove then trap.Model:Destroy(); table.remove(self.Traps, i) end
    end
end

function Pranks:Remove(player)
    self.Ready[player], self.LastUse[player], self.Stuns[player] = nil, nil, nil
    self.Inventory:Remove(player.UserId)
    for i = #self.Traps, 1, -1 do
        if self.Traps[i].Owner == player then self.Traps[i].Model:Destroy(); table.remove(self.Traps, i) end
    end
end

function Pranks:Destroy()
    self.Alive = false
    self.Folder:Destroy()
    table.clear(self.Traps)
end
return Pranks
