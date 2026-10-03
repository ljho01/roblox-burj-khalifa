-- Cosmetic bricks run locally; the server has already accepted the materials.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local stateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")
local effects = Instance.new("Folder")
effects.Name = "BurjEffects"
effects:SetAttribute("ActiveBursts", 0)
effects:SetAttribute("ActiveParts", 0)
effects:SetAttribute("ActiveBricks", 0)
effects:SetAttribute("DepositsPlayed", 0)
effects:SetAttribute("ReceivedDeposits", 0)
effects.Parent = Workspace

local MAX_BURSTS = 6
local MAX_BRICKS = 32
local SPARK_COUNT = 8
local bursts = {}
local renderConnection
local depositsPlayed = 0
local mint = Color3.fromRGB(156, 255, 216)
local cream = Color3.fromRGB(255, 232, 156)

local function cosmeticPart(parent, name, size, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function updateCounters()
    local count = 0
    local bricks = 0
    for _, burst in ipairs(bursts) do
        count += burst.PartCount
        bricks += #burst.Bricks
    end
    effects:SetAttribute("ActiveBursts", #bursts)
    effects:SetAttribute("ActiveParts", count)
    effects:SetAttribute("ActiveBricks", bricks)
end

local function removeBurst(index)
    local burst = table.remove(bursts, index)
    if burst then burst.Folder:Destroy() end
end

local function animateBurst(burst, elapsed)
    local duration = burst.Duration
    for _, brick in ipairs(burst.Bricks) do
        local flight = (elapsed - brick.Delay) / (duration * 0.42)
        if flight <= 0 then
            brick.Part.CFrame = brick.Start
        elseif flight < 1 then
            local t = flight
            local position = brick.Start.Position:Lerp(brick.Landing.Position, t)
            position += Vector3.new(0, math.sin(t * math.pi) * brick.Arc, 0)
            position += brick.Sway * math.sin(t * math.pi)
            local rotation = brick.Start.Rotation:Lerp(brick.Landing.Rotation, t)
            -- A small turn gives each brick the feel of a tossed toy.
            local wobble = math.sin(t * math.pi * 2) * 0.24
            brick.Part.CFrame = CFrame.new(position) * rotation * CFrame.Angles(wobble, 0, -wobble * 0.5)
        else
            local landed = elapsed - brick.Delay - duration * 0.42
            local bounce = math.clamp(landed / (duration * 0.12), 0, 1)
            local hop = math.sin(bounce * math.pi) * 0.55
            brick.Part.CFrame = brick.Landing + Vector3.new(0, hop, 0)
            brick.Part.Transparency = math.clamp((landed / duration - 0.1) / 0.16, 0, 1)
        end
    end

    -- A soft expanding landing circle and eight little confetti pieces need no assets.
    local impact = (elapsed / duration - 0.40) / 0.47
    if impact >= 0 and impact < 1 then
        local width = 2 + impact * 10
        burst.Ring.Size = Vector3.new(0.07, width, width)
        burst.Ring.Transparency = 0.67 + impact * 0.33
    else
        burst.Ring.Transparency = 1
    end
    for index, spark in ipairs(burst.Sparks) do
        local t = (elapsed / duration - 0.42 - (index % 3) * 0.04) / 0.42
        if t >= 0 and t < 1 then
            local distance = 1 + t * 5
            local position = burst.Target + spark.Direction * distance
            position += Vector3.new(0, 0.25 + math.sin(t * math.pi) * 2.3, 0)
            spark.Part.CFrame = CFrame.new(position) * CFrame.Angles(t * 5, index, t * 4)
            spark.Part.Transparency = math.clamp((t - 0.45) / 0.55, 0, 1)
            spark.Part.Size = Vector3.one * (0.25 + (1 - t) * 0.15)
        else
            spark.Part.Transparency = 1
        end
    end
end

local function ensureAnimationLoop()
    if renderConnection then return end
    renderConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local changed = false
        for index = #bursts, 1, -1 do
            local burst = bursts[index]
            local elapsed = now - burst.Started
            if not burst.Folder.Parent or elapsed > burst.Duration * 1.1 then
                removeBurst(index)
                changed = true
            else
                animateBurst(burst, elapsed)
            end
        end
        if changed then updateCounters() end
        if #bursts == 0 then
            renderConnection:Disconnect()
            renderConnection = nil
        end
    end)
end

local function playDeposit(payload)
    if type(payload) ~= "table" or type(payload.Blocks) ~= "table"
        or typeof(payload.Target) ~= "Vector3" or #payload.Blocks == 0 then return end

    -- Include the bottom and top of a tall stack when grouping a large delivery.
    local count = math.min(MAX_BRICKS, #payload.Blocks)
    local sources = {}
    for index = 1, count do
        local sourceIndex = count == 1 and 1 or 1 + math.floor((index - 1) * (#payload.Blocks - 1) / (count - 1))
        local source = payload.Blocks[sourceIndex]
        if type(source) == "table" and typeof(source.CFrame) == "CFrame"
            and typeof(source.Size) == "Vector3" and typeof(source.Color) == "Color3" then
            table.insert(sources, source)
        end
    end
    if #sources == 0 then return end
    while #bursts >= MAX_BURSTS do removeBurst(1) end

    depositsPlayed += 1
    local folder = Instance.new("Folder")
    folder.Name = "Deposit_" .. depositsPlayed
    folder:SetAttribute("UserId", payload.UserId)
    folder:SetAttribute("Amount", payload.Amount)
    folder:SetAttribute("Stage", payload.Stage)
    folder:SetAttribute("VisibleBricks", #sources)
    folder.Parent = effects
    local duration = math.clamp(tonumber(payload.Duration) or 1, 0.6, 2)
    Debris:AddItem(folder, duration * 1.1 + 2)

    local burst = {
        Folder = folder,
        Started = os.clock(),
        Duration = duration,
        Target = payload.Target,
        Bricks = {},
        Sparks = {},
        PartCount = #sources + SPARK_COUNT + 1,
    }

    for index, source in ipairs(sources) do
        local part = cosmeticPart(folder, "FlyingBrick", source.Size, source.Color)
        part.CFrame = source.CFrame
        part:SetAttribute("Index", index)
        local slot = (index - 1) % 16
        local layer = math.floor((index - 1) / 16)
        local x = (slot % 4 - 1.5) * (source.Size.X + 0.14)
        local z = (math.floor(slot / 4) - 1.5) * (source.Size.Z + 0.12)
        local landing = CFrame.new(payload.Target + Vector3.new(x, layer * source.Size.Y, z))
        local relative = landing.Position - source.CFrame.Position
        local perpendicular = Vector3.new(-relative.Z, 0, relative.X)
        if perpendicular.Magnitude > 0 then perpendicular = perpendicular.Unit end
        table.insert(burst.Bricks, {
            Part = part,
            Start = source.CFrame,
            Landing = landing,
            Delay = (index - 1) / math.max(1, #sources - 1) * duration * 0.40,
            Arc = 4.5 + (index % 4) * 0.65 + math.min(relative.Magnitude * 0.10, 4),
            Sway = perpendicular * ((index % 3) - 1) * 1.6,
        })
    end

    for index = 1, SPARK_COUNT do
        local angle = index / SPARK_COUNT * math.pi * 2
        local spark = cosmeticPart(folder, "LandingSparkle", Vector3.one * 0.4, index % 2 == 0 and mint or cream)
        spark.Material = Enum.Material.Neon
        spark.Transparency = 1
        table.insert(burst.Sparks, {Part = spark, Direction = Vector3.new(math.cos(angle), 0, math.sin(angle))})
    end
    burst.Ring = cosmeticPart(folder, "LandingRipple", Vector3.new(0.07, 2, 2), mint)
    burst.Ring.Shape = Enum.PartType.Cylinder
    burst.Ring.Material = Enum.Material.Neon
    burst.Ring.Transparency = 1
    burst.Ring.CFrame = CFrame.new(payload.Target - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)

    table.insert(bursts, burst)
    effects:SetAttribute("DepositsPlayed", depositsPlayed)
    effects:SetAttribute("LastUserId", payload.UserId)
    effects:SetAttribute("LastAmount", payload.Amount)
    effects:SetAttribute("LastVisibleBricks", #sources)
    updateCounters()
    ensureAnimationLoop()
end

local stateConnection = stateEvent.OnClientEvent:Connect(function(kind, payload)
    if kind == "DepositEffect" or kind == "TrashEffect" then
        effects:SetAttribute("ReceivedDeposits", effects:GetAttribute("ReceivedDeposits") + 1)
        playDeposit(payload)
    end
end)

script.Destroying:Connect(function()
    stateConnection:Disconnect()
    if renderConnection then renderConnection:Disconnect() end
    effects:Destroy()
end)
