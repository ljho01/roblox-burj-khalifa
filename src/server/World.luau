-- Procedural art only. The server owns progression and interactions.
local World = {}
local TowerGeometry = require(script.Parent.TowerGeometry)
local PlazaDetails = require(script.Parent.PlazaDetails)
local Crane = require(script.Parent.Crane)
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local C = {
    Sand = Color3.fromRGB(232, 210, 164),
    Paving = Color3.fromRGB(245, 235, 212),
    Concrete = Color3.fromRGB(173, 178, 173),
    Asphalt = Color3.fromRGB(93, 111, 118),
    Glass = Color3.fromRGB(86, 158, 181),
    GlassDark = Color3.fromRGB(42, 98, 122),
    Silver = Color3.fromRGB(194, 216, 218),
    Gold = Color3.fromRGB(249, 189, 62),
    Ink = Color3.fromRGB(22, 42, 54),
    Mint = Color3.fromRGB(96, 222, 185),
    White = Color3.fromRGB(246, 246, 231),
    Blue = Color3.fromRGB(73, 159, 218),
    Orange = Color3.fromRGB(247, 137, 58),
}

local function part(parent, name, size, cf, color, material, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf)
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Transparency = transparency or 0
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function cylinder(parent, name, radius, height, position, color, material, transparency)
    local p = part(parent, name, Vector3.new(height, radius * 2, radius * 2),
        CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, transparency)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function beam(parent, name, from, to, width, color, material)
    return part(parent, name, Vector3.new(width, width, (to - from).Magnitude),
        CFrame.lookAt((from + to) / 2, to), color, material)
end

local function label(parent, text, subtext, color, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Sign"
    gui.Size = UDim2.fromOffset(width or 210, subtext and 68 or 40)
    gui.StudsOffset = Vector3.new(0, 4.5, 0)
    gui.MaxDistance = 160
    gui.AlwaysOnTop = false
    gui.Parent = parent
    local top = Instance.new("TextLabel")
    top.Size = UDim2.new(1, 0, subtext and .58 or 1, 0)
    top.BackgroundColor3 = C.White
    top.BackgroundTransparency = .05
    top.Text = text
    top.TextColor3 = C.Ink
    top.TextSize = 20
    top.Font = Enum.Font.FredokaOne
    top.TextStrokeTransparency = .9
    top.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = top
    if subtext then
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, 0, .36, 0)
        sub.Position = UDim2.fromScale(0, .62)
        sub.BackgroundTransparency = 1
        sub.Text = subtext
        sub.TextColor3 = C.Ink
        sub.TextSize = 14
        sub.Font = Enum.Font.GothamMedium
        sub.TextStrokeTransparency = 1
        sub.Parent = gui
    end
    return gui
end

local function palm(parent, x, z, height, rotation)
    local ground = 1.1
    cylinder(parent, "Palm planter", 3.7, 1, Vector3.new(x, ground, z), C.Ink)
    cylinder(parent, "Palm soil", 3.2, 1.05, Vector3.new(x, ground, z), Color3.fromRGB(145, 118, 73))
    cylinder(parent, "Palm trunk", .58, height, Vector3.new(x, ground + height / 2, z), Color3.fromRGB(137, 106, 66), Enum.Material.Wood)
    for y = 2, height - 1, 1.5 do
        cylinder(parent, "Palm bark collar", .64, .18, Vector3.new(x, ground + y, z), Color3.fromRGB(115, 88, 56), Enum.Material.Wood)
    end
    for i = 1, 9 do
        local angle = i * math.pi * 2 / 9 + rotation
        local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local crown = Vector3.new(x, ground + height, z)
        local previous = crown
        for segment = 1, 4 do
            local d = segment * 2.15
            local point = crown + outward * d + Vector3.new(0, math.sin(segment / 4 * math.pi) * 2.3 - segment * .35, 0)
            local leaf = part(parent, "Palm tapered frond", Vector3.new((5 - segment) * .43, .18, (point - previous).Magnitude + .3),
                CFrame.lookAt((point + previous) / 2, point), Color3.fromRGB(49 + i * 2, 114 + segment * 7, 70), Enum.Material.Grass)
            leaf.CanCollide, leaf.CanTouch, leaf.CanQuery = false, false, false
            previous = point
        end
    end
end

local function cone(parent, x, z)
    part(parent, "Cone base", Vector3.new(1.5, .15, 1.5), Vector3.new(x, 1.2, z), C.Ink)
    for tier = 0, 4 do
        cylinder(parent, "Traffic cone", .57 - tier * .1, .32, Vector3.new(x, 1.43 + tier * .32, z), tier == 2 and C.White or C.Orange)
    end
end

local function lightpost(parent, x, z)
    cylinder(parent, "Streetlight post", .16, 12, Vector3.new(x, 7, z), C.Ink, Enum.Material.Metal)
    part(parent, "Streetlight arm", Vector3.new(3, .25, .35), Vector3.new(x + 1.3, 13, z), C.Ink, Enum.Material.Metal)
    local bulb = part(parent, "Streetlight", Vector3.new(2.2, .15, .65), Vector3.new(x + 1.6, 12.85, z), C.White, Enum.Material.Neon)
    local light = Instance.new("PointLight")
    light.Brightness = .35
    light.Range = 15
    light.Color = C.White
    light.Parent = bulb
end

local function station(parent, name, position, title, subtitle, color)
    cylinder(parent, name .. " pad rim", 6, .25, Vector3.new(position.X, 1.17, position.Z), C.White)
    local base = cylinder(parent, name, 5, .3, Vector3.new(position.X, 1.33, position.Z), color, Enum.Material.Neon)
    base:SetAttribute("Action", name)
    -- The trigger stays precisely at the configured position while the pad stays on the ground.
    local trigger = part(parent, name .. " Interaction", Vector3.new(2, 2, 2), position, color, Enum.Material.SmoothPlastic, 1)
    trigger.CanCollide = false
    trigger.CanTouch = false
    trigger:SetAttribute("Action", name)
    label(trigger, title, subtitle, color)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "Interact"
    prompt.ActionText = title
    prompt.ObjectText = subtitle
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = .25
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt:SetAttribute("Action", name)
    prompt.Parent = trigger
    return trigger
end

function World.Create(config)
    local previous = Workspace:FindFirstChild("BurjWorld")
    if previous then previous:Destroy() end
    local root = Instance.new("Model")
    root.Name = "BurjWorld"
    root.Parent = Workspace
    local scenery = Instance.new("Folder")
    scenery.Name = "Dubai Plaza"
    scenery.Parent = root
    local tower = Instance.new("Model")
    tower.Name = "Burj Khalifa"
    tower.Parent = root

    Lighting.ClockTime = 16.1
    Lighting.Brightness = 2.5
    Lighting.Ambient = Color3.fromRGB(160, 161, 181)
    Lighting.OutdoorAmbient = Color3.fromRGB(168, 170, 174)
    Lighting.GlobalShadows = true
    Lighting.ExposureCompensation = .08
    for _, name in ipairs({"Burj Atmosphere", "Burj Grade", "Burj Bloom"}) do
        local old = Lighting:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "Burj Atmosphere"
    atmosphere.Density = .19
    atmosphere.Offset = .2
    atmosphere.Color = Color3.fromRGB(220, 226, 227)
    atmosphere.Decay = Color3.fromRGB(234, 201, 158)
    atmosphere.Glare = .16
    atmosphere.Haze = .8
    atmosphere.Parent = Lighting
    local grade = Instance.new("ColorCorrectionEffect")
    grade.Name = "Burj Grade"
    grade.Contrast = .06
    grade.Saturation = .03
    grade.TintColor = Color3.fromRGB(255, 247, 231)
    grade.Parent = Lighting
    local bloom = Instance.new("BloomEffect")
    bloom.Name = "Burj Bloom"
    bloom.Intensity = .13
    bloom.Size = 22
    bloom.Threshold = 1.3
    bloom.Parent = Lighting

    part(scenery, "Desert", Vector3.new(1400, 5, 1400), Vector3.new(0, -3, 0), C.Sand, Enum.Material.Sand)
    part(scenery, "Plaza", Vector3.new(352, 2, 348), Vector3.new(0, 0, 12), C.Paving, Enum.Material.Concrete)
    part(scenery, "North boulevard", Vector3.new(900, .15, 32), Vector3.new(0, -.4, -195), C.Asphalt, Enum.Material.Asphalt)
    part(scenery, "South boulevard", Vector3.new(900, .15, 32), Vector3.new(0, -.4, 219), C.Asphalt, Enum.Material.Asphalt)
    for x = -430, 430, 25 do
        for _, z in ipairs({-195, 219}) do
            part(scenery, "Road lane marking", Vector3.new(11, .03, .4), Vector3.new(x, -.3, z), C.White)
        end
    end

    -- A broad, level diagonal connects two visibly separate destinations.
    local supply, delivery = config.Positions.Supply, config.Positions.Build
    local routeStart = Vector3.new(supply.X, 1.08, supply.Z)
    local routeEnd = Vector3.new(delivery.X, 1.08, delivery.Z)
    local direction = (routeEnd - routeStart).Unit
    local side = Vector3.new(-direction.Z, 0, direction.X)
    local function walkway(name, from, to, width, color)
        local p = part(scenery, name, Vector3.new(width, .05, (to - from).Magnitude),
            CFrame.lookAt((from + to) / 2, to), color)
        p.CanCollide = false
        return p
    end
    walkway("Material delivery walkway", routeStart, routeEnd, 17, Color3.fromRGB(255, 248, 229))
    walkway("Arrival promenade", Vector3.new(config.Positions.Spawn.X, 1.07, config.Positions.Spawn.Z), routeStart, 15, Color3.fromRGB(225, 247, 224))
    for _, sign in ipairs({-1, 1}) do
        walkway("Mint walkway border", routeStart + side * 8.7 * sign, routeEnd + side * 8.7 * sign, .55, C.Mint)
    end
    for distance = 13, (routeEnd - routeStart).Magnitude - 10, 13 do
        local center = routeStart + direction * distance + Vector3.new(0, .04, 0)
        local dot = cylinder(scenery, "Delivery stepping dot", 1.65, .055, center, C.Gold)
        dot.CanCollide = false
        -- Little white chevrons point toward the construction pad.
        for _, sign in ipairs({-1, 1}) do
            local arm = beam(scenery, "Delivery arrow", center + direction * .8 + Vector3.new(0, .05, 0),
                center - direction * .5 + side * .85 * sign + Vector3.new(0, .05, 0), .2, C.White)
            arm.CanCollide = false
        end
    end
    for _, pos in ipairs({{-151, -108}, {151, -108}, {-148, -8}, {148, -8}, {-151, 153}, {151, 153}, {-32, 156}, {32, 156}, {-66, -130}, {66, -130}}) do
        palm(scenery, pos[1], pos[2], 14 + (math.abs(pos[1]) % 4), pos[2])
    end
    for _, pos in ipairs({{-140, 149}, {140, 149}, {-151, -57}, {151, -57}, {-18, 166}, {18, 166}, {-67, 97}, {68, 54}}) do
        lightpost(scenery, pos[1], pos[2])
    end

    -- Pools sit at the rear of the expanded plaza, clear of every delivery route.
    for _, x in ipairs({-91, 91}) do
        part(scenery, "Fountain surround", Vector3.new(42, .5, 24), Vector3.new(x, 1.05, -101), C.White, Enum.Material.Slate)
        part(scenery, "Turquoise fountain", Vector3.new(40, .15, 22), Vector3.new(x, 1.37, -101), Color3.fromRGB(103, 213, 219), Enum.Material.Glass, .12)
        for j = -1, 1 do
            local jet = cylinder(scenery, "Fountain jet", .2, 3.5, Vector3.new(x + j * 10, 3.1, -101), Color3.fromRGB(175, 236, 230), Enum.Material.Neon, .38)
            jet.CanCollide = false
        end
    end

    -- Foundation and a segmented fence leave the southern delivery gate wide open.
    cylinder(tower, "Foundation skirt", 39, 1.2, Vector3.new(0, 1.7, 0), C.Ink, Enum.Material.Concrete)
    cylinder(tower, "Foundation slab", 37.8, .7, Vector3.new(0, 2.65, 0), C.Concrete, Enum.Material.Concrete)
    for i = 0, 23 do
        local angle = i * math.pi * 2 / 24
        local x, z = math.cos(angle) * 41, math.sin(angle) * 41
        if z < 27 then
            part(scenery, "Safety fence post", Vector3.new(.18, 3.4, .18), Vector3.new(x, 2.7, z), C.Gold, Enum.Material.Metal)
            local angle2 = (i + 1) * math.pi * 2 / 24
            local x2, z2 = math.cos(angle2) * 41, math.sin(angle2) * 41
            if z2 < 27 then
                beam(scenery, "Safety fence rail", Vector3.new(x, 3.8, z), Vector3.new(x2, 3.8, z2), .11, C.Gold, Enum.Material.Metal)
                beam(scenery, "Safety fence rail", Vector3.new(x, 2.25, z), Vector3.new(x2, 2.25, z2), .09, C.Gold, Enum.Material.Metal)
            end
        end
    end
    for _, x in ipairs({-16, 16}) do
        for _, z in ipairs({43, 49}) do cone(scenery, x, z) end
    end
    -- The mint depot lives entirely at the pickup end, over 120 studs from delivery.
    part(scenery, "Materials yard", Vector3.new(60, .12, 52), Vector3.new(supply.X - 8, 1.08, supply.Z + 8), Color3.fromRGB(186, 230, 203))
    part(scenery, "Delivery yard", Vector3.new(29, .11, 22), Vector3.new(delivery.X, 1.09, delivery.Z), Color3.fromRGB(255, 222, 137))
    for stack = 0, 2 do
        local x, z = supply.X - 24 + stack * 10, supply.Z + 24
        part(scenery, "Wood pallet", Vector3.new(7, .4, 5), Vector3.new(x, 1.4, z), Color3.fromRGB(193, 148, 94), Enum.Material.WoodPlanks)
        for row = 0, 2 do
            for col = 0, 2 do
                part(scenery, "Depot material block", Vector3.new(1.9, .95, 3.2), Vector3.new(x - 2.1 + col * 2.1, 2.15 + row, z),
                    row % 2 == 0 and Color3.fromRGB(210, 225, 235) or Color3.fromRGB(173, 206, 224), Enum.Material.SmoothPlastic)
            end
        end
    end
    part(scenery, "Depot canopy", Vector3.new(33, .8, 12), Vector3.new(supply.X - 14, 10, supply.Z + 25), C.Mint)
    for _, dx in ipairs({-29, 1}) do
        part(scenery, "Depot canopy post", Vector3.new(.7, 8.7, .7), Vector3.new(supply.X + dx, 5.5, supply.Z + 30), C.White)
    end
    local depotSign = part(scenery, "Depot sign", Vector3.new(1, 1, 1), Vector3.new(supply.X - 14, 9.5, supply.Z + 23), C.Mint, nil, 1)
    depotSign.CanCollide = false
    label(depotSign, "① 자재 창고", "챙기고 · 옮기고 · 차곡차곡!", C.Mint, 230)

    -- A tiny toy forklift stays to the west, outside the open loading pad and walkway.
    local fx, fz = supply.X - 28, supply.Z - 5
    part(scenery, "Toy forklift body", Vector3.new(5, 2.6, 7), Vector3.new(fx, 2.8, fz), C.Gold)
    part(scenery, "Forklift seat", Vector3.new(2.1, 1, 2.2), Vector3.new(fx, 4.4, fz + .5), C.Ink)
    part(scenery, "Forklift roof", Vector3.new(5.3, .45, 5), Vector3.new(fx, 7.2, fz + .6), C.Orange)
    for _, dx in ipairs({-2, 2}) do
        part(scenery, "Forklift roof post", Vector3.new(.23, 3.5, .23), Vector3.new(fx + dx, 5.4, fz + 2.3), C.Ink)
        part(scenery, "Forklift mast", Vector3.new(.4, 5.5, .5), Vector3.new(fx + dx * .7, 4, fz - 3.7), C.Ink)
        part(scenery, "Forklift fork", Vector3.new(.5, .3, 4), Vector3.new(fx + dx * .7, 1.6, fz - 5.1), C.Silver)
        for _, dz in ipairs({-2.3, 2.3}) do
            local wheel = part(scenery, "Forklift wheel", Vector3.new(.7, 1.8, 1.8), Vector3.new(fx + dx * 1.25, 2, fz + dz), C.Ink)
            wheel.Shape = Enum.PartType.Cylinder
        end
    end

    -- Each upgrade gets its own little kiosk behind the interaction pad.
    local worker = config.Positions.Worker
    part(scenery, "Site office", Vector3.new(17, 7, 10), Vector3.new(worker.X, 4.5, worker.Z - 14), Color3.fromRGB(255, 242, 220))
    part(scenery, "Site office roof", Vector3.new(18.5, .7, 11.5), Vector3.new(worker.X, 8.4, worker.Z - 14), C.Mint)
    part(scenery, "Site office window", Vector3.new(9, 2.7, .1), Vector3.new(worker.X, 5, worker.Z - 8.95), C.Glass, Enum.Material.Glass)
    for _, kind in ipairs({"Strength", "Speed"}) do
        local position = config.Positions[kind] + Vector3.new(0, -2, -12)
        local color = kind == "Strength" and Color3.fromRGB(255, 178, 119) or Color3.fromRGB(145, 207, 242)
        part(scenery, "Upgrade kiosk", Vector3.new(8, 5, 4), position + Vector3.new(0, 2.5, 0), C.White)
        part(scenery, "Upgrade kiosk cap", Vector3.new(9.5, .6, 5.5), position + Vector3.new(0, 5.3, 0), color)
        part(scenery, "Upgrade display", Vector3.new(6, 3, .12), position + Vector3.new(0, 2.8, 2.1), color)
    end

    -- One shared crane grows with the roof; the foundation stays on the plaza.
    local crane = Crane.new(scenery, config)

    -- A restrained, deterministic Dubai skyline silhouettes the play space.
    local rng = Random.new(828)
    for index = 1, 32 do
        local angle = index / 32 * math.pi * 2
        local distance = rng:NextNumber(280, 365)
        local x, z = math.cos(angle) * distance, math.sin(angle) * distance
        local height, width = rng:NextNumber(19, 84), rng:NextNumber(12, 21)
        local col = Color3.fromRGB(rng:NextInteger(123, 158), rng:NextInteger(164, 184), rng:NextInteger(178, 193))
        part(scenery, "Skyline tower", Vector3.new(width, height, width * .85), Vector3.new(x, height / 2, z), col, Enum.Material.Glass)
        part(scenery, "Skyline rooftop", Vector3.new(width * .73, 4, width * .65), Vector3.new(x, height + 2, z), C.Silver, Enum.Material.Metal)
        for y = 8, height, 9 do
            part(scenery, "Skyline floor band", Vector3.new(width + .12, .22, width * .85 + .12), Vector3.new(x, y, z), Color3.fromRGB(193, 206, 203), Enum.Material.Metal)
        end
        if index % 4 == 0 then
            cylinder(scenery, "Skyline antenna", .2, 10, Vector3.new(x, height + 9, z), C.Silver, Enum.Material.Metal)
        end
    end

    local welcomeX, welcomeZ = config.Positions.Spawn.X, config.Positions.Spawn.Z + 19
    local welcome = part(scenery, "Welcome sign", Vector3.new(30, 6, .7), Vector3.new(welcomeX, 8, welcomeZ), C.White)
    for _, side in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local face = Instance.new("SurfaceGui")
        face.Name = "Welcome"
        face.Face = side
        face.CanvasSize = Vector2.new(780, 162)
        face.Parent = welcome
        local title = Instance.new("TextLabel")
        title.Size = UDim2.fromScale(1, .65)
        title.BackgroundTransparency = 1
        title.Text = "BUILD THE BURJ!"
        title.TextColor3 = Color3.fromRGB(237, 156, 53)
        title.Font = Enum.Font.FredokaOne
        title.TextSize = 58
        title.Parent = face
        local subtitle = Instance.new("TextLabel")
        subtitle.Size = UDim2.fromScale(1, .28)
        subtitle.Position = UDim2.fromScale(0, .68)
        subtitle.BackgroundTransparency = 1
        subtitle.Text = "함께 차곡차곡, 하늘까지!"
        subtitle.TextColor3 = C.Ink
        subtitle.Font = Enum.Font.GothamMedium
        subtitle.TextSize = 24
        subtitle.Parent = face
    end
    for _, x in ipairs({-11.5, 11.5}) do
        part(scenery, "Welcome post", Vector3.new(.6, 6, .6), Vector3.new(welcomeX + x, 3.7, welcomeZ), C.Mint, Enum.Material.Metal)
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "Plaza Spawn"
    spawn.Size = Vector3.new(7, .3, 7)
    spawn.CFrame = CFrame.new(config.Positions.Spawn.X, 1.2, config.Positions.Spawn.Z)
    spawn.Color = C.White
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Transparency = 1
    spawn.Parent = scenery

    local stations = {}
    local descriptions = {
        Supply = {"자재 챙기기", "① 등에 차곡차곡 쌓아요!", C.Mint},
        Build = {"여기에 내려놓기", "② 함께 타워를 올려요!", C.Gold},
        Strength = {"운반력 업그레이드", "한 번에 더 많은 자재", C.Orange},
        Speed = {"속도 업그레이드", "더 빠른 운반", C.Blue},
        Worker = {"작업자 고용", "친구 아바타가 함께 운반해요", C.Mint},
        Lookout = {"전망대 이동", "내가 올린 타워 위로!", C.Blue},
    }
    for name, desc in pairs(descriptions) do
        stations[name] = station(scenery, name, config.Positions[name], desc[1], desc[2], desc[3])
    end

    local pink, plum = Color3.fromRGB(245, 169, 198), Color3.fromRGB(130, 99, 151)
    stations.Steal = station(scenery, "Steal", config.Positions.Steal, "자재 빼돌리기", "꾹 눌러 챙긴 뒤 쓰레기통으로!", plum)
    stations.Steal:FindFirstChildOfClass("ProximityPrompt").HoldDuration = config.StealDuration(config.BaseCapacity)
    stations.Steal:FindFirstChildOfClass("ProximityPrompt").MaxActivationDistance = config.InteractionDistance
    stations.Trash = station(scenery, "Trash", config.Positions.Trash, "자재 쓰레기통", "여기에 버려야 빼돌리기 성공!", pink)
    local pickup = config.Positions.Steal + Vector3.new(0, -1.7, -8)
    part(scenery, "Sneaky pallet", Vector3.new(6.5, .4, 4.5), pickup, C.White, Enum.Material.WoodPlanks)
    for i = 1, 6 do
        part(scenery, "Sneaky material", Vector3.new(1.8, .7, 2.4), pickup + Vector3.new(((i - 1) % 3 - 1) * 2, .55 + math.floor((i - 1) / 3) * .75, 0), pink)
    end
    local via = Vector3.new(68, 1.08, 61)
    walkway("Sneaky walkway", Vector3.new(config.Positions.Steal.X, 1.08, config.Positions.Steal.Z), via, 7, Color3.fromRGB(239, 219, 244))
    walkway("Trash walkway", via, Vector3.new(config.Positions.Trash.X, 1.08, config.Positions.Trash.Z), 7, Color3.fromRGB(248, 222, 232))
    local bin = Instance.new("Model")
    bin.Name, bin.Parent = "MaterialTrashBin", scenery
    local center = Vector3.new(config.Positions.Trash.X + 10, 1.3, config.Positions.Trash.Z - 4)
    part(bin, "Bin base", Vector3.new(9, .5, 7), center, plum)
    for _, x in {-4, 4} do part(bin, "Bin side", Vector3.new(.65, 5.3, 7), center + Vector3.new(x, 2.8, 0), pink) end
    for _, z in {-3.2, 3.2} do part(bin, "Bin wall", Vector3.new(8, 5.3, .6), center + Vector3.new(0, 2.8, z), pink) end
    part(bin, "Dark opening", Vector3.new(7.5, .2, 5.8), center + Vector3.new(0, 4.7, 0), plum)
    local lid = part(bin, "Open lid", Vector3.new(9, .5, 7), CFrame.new(center + Vector3.new(0, 7.1, -4.8)) * CFrame.Angles(math.rad(-62), 0, 0), Color3.fromRGB(209, 178, 232))
    lid.CanCollide = false
    for _, x in {-2.1, 2.1} do
        local eye = part(bin, "Little eye", Vector3.new(.55, .75, .15), center + Vector3.new(x, 3.5, 3.58), C.Ink)
        eye.Shape = Enum.PartType.Ball
        local cheek = part(bin, "Rosy cheek", Vector3.new(1.2, .4, .1), center + Vector3.new(x * 1.15, 2.7, 3.6), Color3.fromRGB(251, 214, 222))
        cheek.Shape = Enum.PartType.Ball
    end
    part(bin, "Tiny smile", Vector3.new(1.1, .2, .15), center + Vector3.new(0, 2.6, 3.6), C.Ink)
    for _, x in {-3, 3} do
        local wheel = part(bin, "Bin wheel", Vector3.new(.65, 1.2, 1.2), center + Vector3.new(x, .1, 2.5), plum)
        wheel.Shape = Enum.PartType.Cylinder
    end

    PlazaDetails.Create(scenery, config)
    local floors = {}
    local stageHeight = config.StageHeight
    local baseY = config.TowerBaseY
    for stage = 1, config.MaxStages do
        local floor = TowerGeometry.Floor(tower, config, stage)
        local records = {}
        for _, p in ipairs(floor:GetDescendants()) do
            if p:IsA("BasePart") then
                table.insert(records, {Part = p, Transparency = p.Transparency, CanCollide = p.CanCollide, CanQuery = p.CanQuery})
                p.Transparency = 1
                p.CanCollide = false
                p.CanTouch = false
                p.CanQuery = false
            end
        end
        floors[stage] = records
    end

    local spire = Instance.new("Model")
    spire.Name = "828m Crown"
    spire.Parent = tower
    local roofY = baseY + config.MaxStages * stageHeight
    TowerGeometry.Spire(spire, config)
    local beacon = part(spire, "Crown beacon", Vector3.new(.45, .55, .45), Vector3.new(0, roofY + config.SpireHeight, 0), C.Gold, Enum.Material.Neon)
    local beaconLight = Instance.new("PointLight")
    beaconLight.Color = C.Gold
    beaconLight.Range = 25
    beaconLight.Brightness = 2
    beaconLight.Enabled = false
    beaconLight.Parent = beacon
    local spireParts = {}
    for _, p in ipairs(spire:GetDescendants()) do
        if p:IsA("BasePart") then
            table.insert(spireParts, p)
            p.Transparency = 1
            p.CanCollide = false
            p.CanQuery = false
        end
    end

    -- A glass observation deck follows the roof; it is solid even at stage zero.
    local lookout = Instance.new("Model")
    lookout.Name = "Roof observation deck"
    lookout.Parent = root
    local deck = part(lookout, "Observation floor", Vector3.new(10, .55, 8), Vector3.new(0, baseY + .4, -7), C.Ink, Enum.Material.Metal)
    local deckParts = {{Part = deck, Offset = Vector3.new(0, .4, -7)}}
    for _, rail in ipairs({{Vector3.new(10, 2.8, .18), Vector3.new(0, 2, -11)}, {Vector3.new(.18, 2.8, 8), Vector3.new(-5, 2, -7)}, {Vector3.new(.18, 2.8, 8), Vector3.new(5, 2, -7)}}) do
        local p = part(lookout, "Observation glass", rail[1], rail[2] + Vector3.new(0, baseY, 0), C.Glass, Enum.Material.Glass, .45)
        table.insert(deckParts, {Part = p, Offset = rail[2]})
    end
    local returnPad = part(lookout, "Return to plaza", Vector3.new(3, .1, 2), Vector3.new(0, baseY + .75, -8), C.Gold, Enum.Material.Neon)
    returnPad:SetAttribute("Action", "Return")
    table.insert(deckParts, {Part = returnPad, Offset = Vector3.new(0, .75, -8)})
    local returnPrompt = Instance.new("ProximityPrompt")
    returnPrompt.ActionText = "광장으로 돌아가기"
    returnPrompt.ObjectText = "전망대"
    returnPrompt.MaxActivationDistance = 9
    returnPrompt.RequiresLineOfSight = false
    returnPrompt.HoldDuration = .25
    returnPrompt.KeyboardKeyCode = Enum.KeyCode.E
    returnPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    returnPrompt:SetAttribute("Action", "Return")
    returnPrompt.Parent = returnPad

    local currentStage = 0
    local self = {Root = root, Tower = tower, Stations = stations, Spawn = spawn, Crane = crane, TrashTarget = center + Vector3.new(0, 5.7, 0)}
    function self:SetStage(stage, animate)
        stage = math.clamp(math.floor(stage), 0, config.MaxStages)
        if stage ~= currentStage then
            local first, last = math.min(stage, currentStage) + 1, math.max(stage, currentStage)
            for i = first, last do
                local visible = i <= stage
                for _, record in ipairs(floors[i]) do
                    record.Part.Transparency = visible and record.Transparency or 1
                    record.Part.CanCollide = visible and record.CanCollide
                    record.Part.CanQuery = visible and record.CanQuery
                end
            end
            currentStage = stage
        end
        local complete = stage == config.MaxStages
        for _, p in ipairs(spireParts) do
            p.Transparency = complete and 0 or 1
            p.CanCollide = false
            p.CanQuery = false
        end
        beaconLight.Enabled = complete
        local topY = baseY + stage * stageHeight
        for _, record in ipairs(deckParts) do
            record.Part.Position = record.Offset + Vector3.new(0, topY, 0)
        end
        tower:SetAttribute("Stage", stage)
        tower:SetAttribute("HeightMeters", math.floor(stage / config.MaxStages * config.HeightMeters))
        crane:SetStage(stage, animate == true)
    end
    function self:GetLookoutCFrame()
        return CFrame.lookAt(Vector3.new(0, baseY + currentStage * stageHeight + 5, -7), Vector3.new(0, baseY + currentStage * stageHeight + 5, 80))
    end
    function self:SetCelebrating(enabled)
        beaconLight.Brightness = enabled and 5 or 2
        beacon.Color = enabled and C.Mint or C.Gold
    end
    self:SetStage(0)
    return self
end

return World
