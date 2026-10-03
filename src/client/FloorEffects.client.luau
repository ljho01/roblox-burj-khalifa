-- Shared floor milestones become small, short-lived local celebrations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local state = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")
local effects = Instance.new("Folder")
effects.Name, effects.Parent = "BurjFloorEffects", workspace
local MAX_BURSTS, PUFFS, STARS, DURATION = 4, 16, 8, 1.8
local bursts, played, lastRound, lastStage = {}, 0, 0, 0
local renderConnection
local cream, white, mint = Color3.fromRGB(255, 242, 215), Color3.fromRGB(255, 253, 244), Color3.fromRGB(190, 238, 218)
local gold = Color3.fromRGB(255, 218, 107)

local function part(parent, name, color, size, position)
    local p = Instance.new("Part")
    p.Name, p.Color, p.Size, p.Position = name, color, size, position
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Material, p.Transparency = Enum.Material.SmoothPlastic, 1
    p.Parent = parent
    return p
end

local function counters()
    effects:SetAttribute("ActiveBursts", #bursts)
    effects:SetAttribute("ActivePuffs", #bursts * PUFFS)
    effects:SetAttribute("ActiveParts", #bursts * (PUFFS + STARS * 2))
    effects:SetAttribute("EffectsPlayed", played)
end

local function remove(index)
    table.remove(bursts, index).Folder:Destroy()
end

local function animate(burst, elapsed)
    for index, puff in burst.Puffs do
        local t = (elapsed - (index % 3) * .045) / DURATION
        if t <= 0 or t >= 1 then puff.Part.Transparency = 1; continue end
        local growth = .55 + math.sin(math.min(1, t / .6) * math.pi / 2) * .9
        local squash = 1 - math.sin(t * math.pi * 2) * .12
        puff.Part.Size = Vector3.new(growth, growth * squash, growth) * puff.Size
        puff.Part.Position = puff.Start + puff.Direction * (t * 5) + Vector3.new(0, t * 7 + math.sin(t * math.pi) * 1.4, 0)
        puff.Part.Transparency = .18 + math.clamp((t - .16) / .84, 0, 1) * .82
    end
    for index, star in burst.Stars do
        local t = (elapsed - .12 - (index % 2) * .05) / (DURATION * .8)
        if t <= 0 or t >= 1 then
            star.Vertical.Transparency, star.Horizontal.Transparency = 1, 1
            continue
        end
        local position = star.Start + star.Direction * (t * 5) + Vector3.new(0, math.sin(t * math.pi / 2) * 10, 0)
        local camera = workspace.CurrentCamera
        local facing = camera and CFrame.lookAt(position, camera.CFrame.Position) or CFrame.new(position)
        local cf = facing * CFrame.Angles(0, 0, t * 2 + index * .4)
        local scale = math.sin(t * math.pi) * 1.7 + .15
        star.Vertical.Size, star.Horizontal.Size = Vector3.new(.35, 1.8, .25) * scale, Vector3.new(1.35, .35, .25) * scale
        star.Vertical.CFrame, star.Horizontal.CFrame = cf, cf
        local transparency = math.clamp((t - .55) / .45, 0, 1)
        star.Vertical.Transparency, star.Horizontal.Transparency = transparency, transparency
    end
end

local function startLoop()
    if renderConnection then return end
    renderConnection = RunService.RenderStepped:Connect(function()
        local changed = false
        for index = #bursts, 1, -1 do
            local burst = bursts[index]
            local elapsed = os.clock() - burst.Started
            if elapsed > DURATION + .16 then remove(index); changed = true
            else animate(burst, elapsed) end
        end
        if changed then counters() end
        if #bursts == 0 then renderConnection:Disconnect(); renderConnection = nil end
    end)
end

local function playFloor(stage, delay)
    local world = workspace:FindFirstChild("BurjWorld")
    local tower = world and world:FindFirstChild("Burj Khalifa")
    local floor = tower and tower:FindFirstChild(string.format("Floor %02d", stage))
    if not floor then return end
    local cf, size = floor:GetBoundingBox()
    local center = Vector3.new(cf.X, Config.TowerBaseY + (stage - .55) * Config.StageHeight, cf.Z)
    local rx, rz = size.X / 2 + 1, size.Z / 2 + 1
    while #bursts >= MAX_BURSTS do remove(1) end
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "FloorPop_" .. stage, effects
    folder:SetAttribute("Stage", stage)
    folder:SetAttribute("Round", lastRound)
    local burst = {Folder = folder, Started = os.clock() + delay, Puffs = {}, Stars = {}}
    for index = 1, PUFFS do
        local angle = index / PUFFS * math.pi * 2
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local start = center + Vector3.new(direction.X * rx, (index % 3) * .7, direction.Z * rz)
        local puff = part(folder, "SoftDustPuff", index % 5 == 0 and mint or (index % 2 == 0 and cream or white), Vector3.one, start)
        puff.Shape = Enum.PartType.Ball
        table.insert(burst.Puffs, {Part = puff, Start = start, Direction = direction, Size = 3.6 + (index % 4) * .7})
    end
    for index = 1, STARS do
        local angle = (index + .35) / STARS * math.pi * 2
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local start = center + Vector3.new(direction.X * rx * 1.08, 3, direction.Z * rz * 1.08)
        local color = index % 3 == 0 and mint or gold
        local vertical = part(folder, "TwinkleVertical", color, Vector3.one, start)
        local horizontal = part(folder, "TwinkleHorizontal", color, Vector3.one, start)
        vertical.Material, horizontal.Material = Enum.Material.Neon, Enum.Material.Neon
        table.insert(burst.Stars, {Vertical = vertical, Horizontal = horizontal, Start = start, Direction = direction})
    end
    table.insert(bursts, burst)
    played += 1
    effects:SetAttribute("LastStage", stage)
    effects:SetAttribute("LastRound", lastRound)
    counters()
    startLoop()
end

local function clear()
    for index = #bursts, 1, -1 do remove(index) end
    counters()
end

local connection = state.OnClientEvent:Connect(function(kind, payload)
    if type(payload) ~= "table" then return end
    if kind == "Snapshot" and payload.Round and payload.Round > lastRound then
        clear()
        lastRound, lastStage = payload.Round, 0
    elseif kind == "FloorsRemoved" and payload.Round == lastRound then
        clear()
        lastStage = payload.ToStage
        for stage = payload.FromStage, math.max(payload.ToStage + 1, payload.FromStage - MAX_BURSTS + 1), -1 do playFloor(stage, 0) end
    elseif kind == "FloorsBuilt" then
        local first, last, round = payload.FromStage, payload.ToStage, payload.Round
        if type(first) ~= "number" or type(last) ~= "number" or type(round) ~= "number" then return end
        if round < lastRound or (round == lastRound and last <= lastStage) then return end
        if round > lastRound then clear(); lastRound, lastStage = round, 0 end
        first, last = math.max(1, first, lastStage + 1), math.min(Config.MaxStages, last)
        -- Large deliveries sample the newly completed floors; simultaneous
        -- multiplayer deliveries can never accumulate more than 128 parts.
        local count = math.min(MAX_BURSTS, last - first + 1)
        for index = 1, count do
            local stage = count == 1 and last or first + math.floor((index - 1) * (last - first) / (count - 1))
            playFloor(stage, (index - 1) * .07)
        end
        lastStage = last
    end
end)
counters()
script.Destroying:Connect(function()
    connection:Disconnect()
    if renderConnection then renderConnection:Disconnect() end
    effects:Destroy()
end)
