-- Each construction stage contains three architectural storeys. Decorative
-- mullions are non-colliding; the structural shells carry the player physics.
local TowerGeometry = {}
local glass = Color3.fromRGB(101, 153, 174)
local shadowGlass = Color3.fromRGB(67, 113, 137)
local silver = Color3.fromRGB(199, 217, 222)
local dark = Color3.fromRGB(47, 72, 85)

local function part(parent, name, size, cf, color, material, solid)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Color, p.Material = color, material or Enum.Material.Metal
    p.Anchored = true
    p.CanCollide, p.CanTouch, p.CanQuery = solid == true, false, solid == true
    p.CastShadow = solid == true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function cylinder(parent, name, radius, height, position, color, material, solid)
    local p = part(parent, name, Vector3.new(height, radius * 2, radius * 2),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, solid)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function wingShape(stage, wing, scale)
    local setback = math.floor((stage - 1 + (wing - 1) * 1.5) / 4)
    local reach = math.max(0, 16.5 * (1 - setback / 12)) * scale
    local width = math.max(.8, 4.15 * (1 - setback / 14)) * scale
    return reach, width, setback
end

function TowerGeometry.Floor(parent, config, stage)
    local floor = Instance.new("Model")
    floor.Name = string.format("Floor %02d", stage)
    floor.Parent = parent
    local h, scale = config.StageHeight, config.TowerWidthScale
    local bottom = config.TowerBaseY + (stage - 1) * h
    local y, top = bottom + h / 2, bottom + h
    local t = (stage - 1) / (config.MaxStages - 1)
    local radius = (5.9 - t * 4.15) * scale
    local core = cylinder(floor, "Glazed central core", radius, h, Vector3.new(0, y, 0), glass, Enum.Material.Glass, true)
    core.Reflectance = .14
    for level = 1, 3 do
        local by = bottom + level * h / 3 - .12
        cylinder(floor, "Core floor edge", radius + .1, .24, Vector3.new(0, by, 0), silver)
    end
    for fin = 1, 12 do
        local angle = fin * math.pi / 6
        part(floor, "Core fin", Vector3.new(.13, h, .13),
            CFrame.new(math.cos(angle) * (radius + .04), y, math.sin(angle) * (radius + .04)), silver)
    end
    for wing = 1, 3 do
        local reach, halfWidth, setback = wingShape(stage, wing, scale)
        if reach > .6 then
            local angle = -math.pi / 2 + (wing - 1) * math.pi * 2 / 3
            local dx, dz = math.cos(angle), math.sin(angle)
            local length = radius * .5 + reach
            local function cf(distance, height, side)
                return CFrame.new(dx * distance - dz * side, height, dz * distance + dx * side) * CFrame.Angles(0, -angle, 0)
            end
            local pane = part(floor, "Glass wing", Vector3.new(length, h, halfWidth * 2), cf(length / 2, y, 0),
                wing == 2 and shadowGlass or glass, Enum.Material.Glass, true)
            pane.Reflectance = .12
            local tip = cylinder(floor, "Rounded wing tip", halfWidth, h, cf(length, y, 0).Position, glass, Enum.Material.Glass, true)
            tip.Reflectance = .17
            for level = 1, 3 do
                local by = bottom + level * h / 3 - .12
                part(floor, "Wing floor edge", Vector3.new(length, .24, halfWidth * 2 + .2), cf(length / 2, by, 0), silver)
                cylinder(floor, "Rounded floor edge", halfWidth + .1, .24, cf(length, by, 0).Position, silver)
                -- Recessed dark spandrels separate the glazing from the bright slab edges.
                for _, side in ipairs({-1, 1}) do
                    part(floor, "Spandrel shadow", Vector3.new(length, .38, .06), cf(length / 2, by - .3, side * (halfWidth + .015)), dark)
                end
            end
            local bays = math.max(2, math.ceil(length / 3.6))
            for bay = 1, bays do
                for _, side in ipairs({-1, 1}) do
                    part(floor, "Facade fin", Vector3.new(.16, h, .24), cf(length * bay / bays, y, side * (halfWidth + .06)), silver)
                end
            end
            -- Seven fins follow the exposed semicircular nose of each wing.
            for fin = -3, 3 do
                local a = angle + fin * math.pi / 6
                part(floor, "Curved facade fin", Vector3.new(.13, h, .13),
                    CFrame.new(dx * length + math.cos(a) * (halfWidth + .05), y, dz * length + math.sin(a) * (halfWidth + .05)), silver)
            end
            local nextReach, _, nextSetback = wingShape(stage + 1, wing, scale)
            if nextSetback > setback or stage == config.MaxStages then
                cylinder(floor, "Setback terrace coping", halfWidth + .2, .32, cf(length, top + .04, 0).Position, silver)
                cylinder(floor, "Setback terrace inset", math.max(.4, halfWidth - .35), .08, cf(length, top + .24, 0).Position, dark)
                -- A short mechanical louvre sits on the exposed outer terrace.
                if reach - nextReach > .5 and halfWidth > 2 then
                    for slat = 1, 4 do
                        part(floor, "Terrace louvre", Vector3.new(.12, .6, halfWidth), cf(length + halfWidth * .35 + slat * .18, top + .52, 0), silver)
                    end
                end
            end
        end
    end
    if stage == 1 then
        part(floor, "Entrance canopy", Vector3.new(18, .55, 9), CFrame.new(0, bottom + 6, 16), silver, Enum.Material.Metal, true)
        for _, x in ipairs({-7.5, 7.5}) do
            cylinder(floor, "Entrance column", .24, 5.8, Vector3.new(x, bottom + 2.9, 19), silver, Enum.Material.Metal, true)
        end
        part(floor, "Entrance glazing", Vector3.new(13, 5.5, .2), CFrame.new(0, bottom + 2.75, 12), shadowGlass, Enum.Material.Glass, true)
        for x = -6, 6, 3 do
            part(floor, "Entrance door frame", Vector3.new(.12, 5.5, .3), CFrame.new(x, bottom + 2.75, 12.1), silver)
        end
    end
    return floor
end

function TowerGeometry.Spire(parent, config)
    local roof = config.TowerBaseY + config.MaxStages * config.StageHeight
    for i = 1, 12 do
        local h = config.SpireHeight / 12
        local radius = math.max(.13, 2.8 * (1 - (i - 1) / 12) ^ 1.25)
        cylinder(parent, "Spire section", radius, h + .05, Vector3.new(0, roof + (i - .5) * h, 0), silver)
        if i < 10 then
            cylinder(parent, "Spire collar", radius + .14, .28, Vector3.new(0, roof + (i - 1) * h, 0), dark)
        end
    end
end

return TowerGeometry
