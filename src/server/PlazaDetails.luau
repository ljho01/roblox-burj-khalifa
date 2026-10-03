-- Small, static details are grouped separately and never block delivery routes.
local PlazaDetails = {}
local stone = Color3.fromRGB(218, 210, 188)
local bronze = Color3.fromRGB(132, 108, 65)
local ink = Color3.fromRGB(39, 61, 67)
local warm = Color3.fromRGB(255, 225, 165)

local function part(parent, name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size = name, size
    p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
    p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function disk(parent, name, r, h, pos, color, material)
    local p = part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, material)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function bench(parent, x, z, rotation)
    local cf = CFrame.new(x, 1.2, z) * CFrame.Angles(0, rotation, 0)
    for slat = -2, 2 do
        part(parent, "Bench timber seat", Vector3.new(7, .2, .35), cf * CFrame.new(0, 1.35, slat * .42), bronze, Enum.Material.Wood)
    end
    for slat = 1, 3 do
        part(parent, "Bench timber back", Vector3.new(7, .3, .18), cf * CFrame.new(0, 1.7 + slat * .4, .94), bronze, Enum.Material.Wood)
    end
    for _, dx in ipairs({-2.7, 2.7}) do
        part(parent, "Bench metal leg", Vector3.new(.25, 1.4, 1.8), cf * CFrame.new(dx, .7, 0), ink, Enum.Material.Metal)
        part(parent, "Bench armrest", Vector3.new(.2, .18, 2), cf * CFrame.new(dx, 2.1, 0), ink, Enum.Material.Metal)
    end
end

function PlazaDetails.Create(parent, config)
    local details = Instance.new("Folder")
    details.Name, details.Parent = "Plaza craftsmanship", parent
    -- Low inlays articulate the empty paving without introducing steps.
    for _, x in ipairs({-126, 126}) do
        part(details, "Promenade stone border", Vector3.new(.45, .025, 250), Vector3.new(x, 1.018, 17), bronze)
        for z = -100, 142, 11 do
            part(details, "Promenade paving joint", Vector3.new(22, .025, .12), Vector3.new(x, 1.02, z), stone)
        end
    end
    for i = 0, 47 do
        local angle = i * math.pi / 24
        part(details, "Foundation paving ray", Vector3.new(.17, .025, 8),
            CFrame.new(math.sin(angle) * 45, 1.024, math.cos(angle) * 45) * CFrame.Angles(0, angle, 0), bronze)
    end
    -- A shallow entrance ramp meets the enlarged foundation, clear of the pad.
    local ramp = Instance.new("WedgePart")
    ramp.Name, ramp.Size = "Foundation entrance ramp", Vector3.new(15, 2, 8)
    ramp.CFrame = CFrame.new(0, 2, 38) * CFrame.Angles(0, math.pi, 0)
    ramp.Color, ramp.Material, ramp.Anchored = stone, Enum.Material.Concrete, true
    ramp.Parent = details
    for _, x in ipairs({-90, 90}) do
        for _, z in ipairs({-128, -74}) do
            bench(details, x, z, z == -128 and math.pi or 0)
        end
    end
    for _, x in ipairs({-153, 153}) do
        for _, z in ipairs({-80, -30, 72, 120}) do
            part(details, "Garden stone planter", Vector3.new(11, .9, 7), Vector3.new(x, 1.6, z), stone, Enum.Material.Slate)
            part(details, "Garden soil", Vector3.new(10, .15, 6), Vector3.new(x, 2.12, z), Color3.fromRGB(102, 84, 53), Enum.Material.Ground)
            for j = -1, 1 do
                local shrub = part(details, "Clipped garden shrub", Vector3.new(3.6, 2.5, 4), Vector3.new(x + j * 3, 3.15, z), Color3.fromRGB(67, 115 + j * 9, 74), Enum.Material.Grass)
                shrub.Shape = Enum.PartType.Ball
            end
        end
    end
    for _, x in ipairs({-91, 91}) do
        for j = -1, 1 do
            local center = Vector3.new(x + j * 10, 1.49, -101)
            disk(details, "Fountain brass nozzle", .5, .16, center, bronze, Enum.Material.Metal)
            for ring = 1, 3 do
                -- Ring made from narrow tangent segments leaves the water visible.
                for segment = 1, 16 do
                    local angle = segment * math.pi / 8
                    local radius = ring * 1.1
                    local ripple = part(details, "Fountain ripple", Vector3.new(.07, .035, radius * .4),
                        CFrame.new(center + Vector3.new(math.cos(angle) * radius, .05, math.sin(angle) * radius)) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(192, 236, 229))
                    ripple.Transparency, ripple.CastShadow = .45 + ring * .1, false
                end
            end
        end
        for _, side in ipairs({-1, 1}) do
            part(details, "Pool edge inset", Vector3.new(39, .045, .13), Vector3.new(x, 1.325, -101 + side * 11.65), bronze, Enum.Material.Metal)
        end
    end
    for _, pos in ipairs({{-122, -118}, {122, -118}, {-122, 48}, {122, 80}, {-50, 151}, {50, 151}}) do
        disk(details, "Bollard foot", .5, .12, Vector3.new(pos[1], 1.14, pos[2]), ink, Enum.Material.Metal)
        disk(details, "Bollard shaft", .25, 2.5, Vector3.new(pos[1], 2.4, pos[2]), ink, Enum.Material.Metal)
        disk(details, "Bollard lens", .28, .32, Vector3.new(pos[1], 3.5, pos[2]), warm, Enum.Material.Neon)
    end
    local sx, sz = config.Positions.Supply.X, config.Positions.Supply.Z
    for stack = 0, 2 do
        for _, offset in ipairs({-2.3, 2.3}) do
            part(details, "Pallet cargo strap", Vector3.new(.16, 3.2, 3.3), Vector3.new(sx - 24 + stack * 10 + offset, 3.05, sz + 24), ink)
        end
    end
    -- Fluted loading shelter, office cladding and visible forklift controls.
    for rib = 0, 10 do
        part(details, "Depot roof seam", Vector3.new(.12, .08, 12), Vector3.new(sx - 29 + rib * 3, 10.44, sz + 25), stone)
    end
    local fx, fz = sx - 28, sz - 5
    part(details, "Forklift seat back", Vector3.new(2.1, 1.8, .35), Vector3.new(fx, 5.15, fz + 1.4), ink)
    part(details, "Forklift dashboard", Vector3.new(3.2, .5, .9), Vector3.new(fx, 4.75, fz - 1.5), ink)
    for _, dx in ipairs({-1.6, 1.6}) do
        part(details, "Forklift headlamp", Vector3.new(.65, .45, .1), Vector3.new(fx + dx, 3.6, fz - 3.56), warm, Enum.Material.Neon)
    end
    for _, dx in ipairs({-1, 1}) do
        for _, dz in ipairs({-2.3, 2.3}) do
            local hub = part(details, "Forklift wheel hub", Vector3.new(.1, .88, .88), Vector3.new(fx + dx * 2.88, 2, fz + dz), stone, Enum.Material.Metal)
            hub.Shape = Enum.PartType.Cylinder
        end
    end
    local office = config.Positions.Worker
    for x = -7.5, 7.5, 1.5 do
        part(details, "Office wall rib", Vector3.new(.13, 6, .14), Vector3.new(office.X + x, 4.5, office.Z - 19.06), stone)
    end
    for x = -3, 3, 3 do
        part(details, "Office window mullion", Vector3.new(.12, 2.8, .16), Vector3.new(office.X + x, 5, office.Z - 8.87), ink)
    end
    return details
end

return PlazaDetails
