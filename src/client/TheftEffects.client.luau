-- Cosmetic pink bricks fill the bag while the server times the extraction.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local remote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")
local geometry = require(game.ReplicatedStorage.Shared.CarryGeometry)
local effects = Instance.new("Folder")
effects.Name = "BurjTheftEffects"
effects:SetAttribute("ExtractionsPlayed", 0)
effects.Parent = workspace
local bursts = {}
local connection

local function counters()
    local count = 0
    for _, burst in bursts do count += #burst.Bricks end
    effects:SetAttribute("ActiveParts", count)
end

local function remove(index)
    local burst = table.remove(bursts, index)
    burst.Folder:Destroy()
    counters()
end

local function start(payload)
    local owner = Players:GetPlayerByUserId(payload.UserId)
    local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    while #bursts >= 4 do remove(1) end
    local folder = Instance.new("Folder")
    folder.Name = "Extraction_" .. payload.Id
    folder.Parent = effects
    local burst = {Id = payload.Id, Folder = folder, Root = root, EndsAt = payload.EndsAt,
        Duration = payload.Duration, Bricks = {}}
    local count = math.min(24, payload.Amount)
    for index = 1, count do
        local materialIndex = count == 1 and 1 or 1 + math.floor((index - 1) * (payload.Amount - 1) / (count - 1))
        local shape = geometry.Brick(materialIndex, 0, true)
        local part = Instance.new("Part")
        part.Name = "SneakyBrick"
        part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
        part.Size, part.Color, part.Material = shape.Size, shape.Color, Enum.Material.SmoothPlastic
        part.Transparency = 1
        part.Parent = folder
        table.insert(burst.Bricks, {Part = part, Offset = shape.Offset,
            Origin = payload.Origin + Vector3.new((index % 3 - 1) * 1.2, -0.3, -7.5),
            Delay = (index - 1) / math.max(1, count - 1) * payload.Duration * 0.58})
    end
    table.insert(bursts, burst)
    counters()
    effects:SetAttribute("ExtractionsPlayed", effects:GetAttribute("ExtractionsPlayed") + 1)
    if connection then return end
    connection = RunService.RenderStepped:Connect(function()
        local now = workspace:GetServerTimeNow()
        for index = #bursts, 1, -1 do
            local active = bursts[index]
            if not active.Root.Parent or now > active.EndsAt + 0.35 then
                remove(index)
            else
                local elapsed = now - active.EndsAt + active.Duration
                for _, brick in active.Bricks do
                    local t = math.clamp((elapsed - brick.Delay) / (active.Duration * 0.4), 0, 1)
                    local target = active.Root.CFrame * brick.Offset
                    local position = brick.Origin:Lerp(target.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 4, 0)
                    brick.Part.CFrame = CFrame.new(position) * target.Rotation * CFrame.Angles(0, 0, math.sin(t * math.pi) * 0.4)
                    brick.Part.Transparency = elapsed < brick.Delay and 1 or 0.15
                end
            end
        end
        if #bursts == 0 then connection:Disconnect(); connection = nil end
    end)
end

local listener = remote.OnClientEvent:Connect(function(kind, payload)
    if kind == "TheftStart" then
        start(payload)
    elseif kind == "TheftEnd" then
        for index = #bursts, 1, -1 do
            if bursts[index].Id == payload.Id then remove(index) end
        end
    end
end)

script.Destroying:Connect(function()
    listener:Disconnect()
    if connection then connection:Disconnect() end
    effects:Destroy()
end)
