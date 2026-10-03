-- All players see the spill. Cosmetic parts cannot be collected or award coins.
local RunService = game:GetService("RunService")
local state = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("State")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "BurjPrankEffects", workspace
local bursts = {}
folder:SetAttribute("HitsPlayed", 0)
folder:SetAttribute("ActiveParts", 0)
local function count()
    local n = 0
    for _, burst in bursts do n += #burst.Bricks + #burst.Stars end
    folder:SetAttribute("ActiveParts", n)
end
local function particle(parent, name, size, tint)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Color = name, size, tint
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end
state.OnClientEvent:Connect(function(kind, data)
    if kind ~= "PrankHit" then return end
    while #bursts >= 4 do table.remove(bursts, 1).Folder:Destroy() end
    local group = Instance.new("Folder")
    group.Name, group.Parent = "SpilledMaterials", folder
    local burst = {Folder = group, Start = os.clock(), Bricks = {}, Stars = {}, Origin = data.Origin}
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {folder}
    for _, p in game.Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
    ray.FilterDescendantsInstances = ignore
    local ground = workspace:Raycast(data.Origin, Vector3.new(0, -40, 0), ray)
    local floor = ground and ground.Position.Y + .2 or data.Origin.Y - 3
    for i, source in ipairs(data.Blocks) do
        if i > 128 then break end
        local p = particle(group, "DroppedBrick", source.Size, source.Color)
        p.CFrame = source.CFrame
        local angle = i * 2.39996
        local speed = 4 + i % 6
        table.insert(burst.Bricks, {Part = p, Start = source.CFrame, Floor = floor,
            Velocity = Vector3.new(math.cos(angle) * speed, 7 + i % 4, math.sin(angle) * speed), Spin = i % 2 == 0 and 1 or -1})
    end
    for i = 1, 8 do
        local p = particle(group, "DizzyStar", Vector3.new(.24, .65, .24), Color3.fromRGB(255, 224, 126))
        p.Material = Enum.Material.Neon
        table.insert(burst.Stars, p)
    end
    table.insert(bursts, burst)
    folder:SetAttribute("HitsPlayed", folder:GetAttribute("HitsPlayed") + 1)
    folder:SetAttribute("LastAmount", data.Amount)
    count()
end)
RunService.RenderStepped:Connect(function()
    for i = #bursts, 1, -1 do
        local burst = bursts[i]
        local t = os.clock() - burst.Start
        if t > 2.7 then
            burst.Folder:Destroy()
            table.remove(bursts, i)
            count()
        else
            for _, brick in burst.Bricks do
                local position = brick.Start.Position + brick.Velocity * math.min(t, 1.3) - Vector3.new(0, 26 * t * t, 0)
                if position.Y < brick.Floor then
                    position = Vector3.new(position.X, brick.Floor + math.abs(math.sin(t * 9)) * math.max(0, 1.2 - t), position.Z)
                end
                brick.Part.CFrame = CFrame.new(position) * brick.Start.Rotation * CFrame.Angles(t * brick.Spin * 4, t * 2, t * 3)
                brick.Part.Transparency = math.clamp((t - 1.8) / .8, 0, 1)
            end
            for j, star in burst.Stars do
                local angle = j * math.pi / 4 + t * 4
                star.CFrame = CFrame.new(burst.Origin + Vector3.new(math.cos(angle) * (2 + t), 2.3 + math.sin(t * 3) * .5, math.sin(angle) * (2 + t))) * CFrame.Angles(0, 0, angle)
                star.Transparency = math.clamp((t - .6) / .8, 0, 1)
            end
        end
    end
end)
