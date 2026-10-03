local TweenService = game:GetService("TweenService")
local Crane = {}
Crane.__index = Crane
local X, Z, BASE = -53, -24, 2
local GOLD = Color3.fromRGB(249, 189, 62)
local INK = Color3.fromRGB(47, 66, 80)

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, typeof(position) == "CFrame" and position or CFrame.new(position)
    p.Color, p.Material = color, material or Enum.Material.Metal
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function beam(parent, name, a, b, width, color)
    return part(parent, name, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
end

function Crane.new(parent, config)
    local self = setmetatable({Config = config, Columns = {}, Sections = {}, VisibleSections = 0}, Crane)
    self.Model = Instance.new("Model")
    self.Model.Name, self.Model.Parent = "ConstructionCrane", parent
    local foundation = part(self.Model, "Crane foundation", Vector3.new(9, 2, 9), Vector3.new(X, 1, Z), Color3.fromRGB(173, 178, 173), Enum.Material.Concrete)
    foundation.CanCollide, foundation.CanQuery = true, true
    local mast = Instance.new("Folder")
    mast.Name, mast.Parent = "ExtendingMast", self.Model
    for _, dx in {-1.9, 1.9} do
        for _, dz in {-1.9, 1.9} do
            table.insert(self.Columns, {Part = part(mast, "Crane mast", Vector3.new(.38, 1, .38), Vector3.new(X + dx, BASE, Z + dz), GOLD), X = X + dx, Z = Z + dz})
        end
    end
    local maxHeight = self:HeightForStage(config.MaxStages)
    for index = 1, math.ceil((maxHeight - BASE) / 6) do
        local y = BASE + (index - 1) * 6
        local section = {Top = y + 6, Parts = {}}
        for _, dz in {-1.9, 1.9} do
            table.insert(section.Parts, beam(mast, "Crane diagonal", Vector3.new(X - 1.9, y, Z + dz), Vector3.new(X + 1.9, y + 6, Z + dz), .19, GOLD))
        end
        table.insert(section.Parts, part(mast, "Crane mast rung", Vector3.new(4.2, .2, 4.2), Vector3.new(X, y + 6, Z), GOLD))
        for _, p in section.Parts do p.Transparency = 1 end
        table.insert(self.Sections, section)
    end
    self.Head = Instance.new("Model")
    self.Head.Name, self.Head.Parent = "CraneHead", self.Model
    local pivot = part(self.Head, "HeadPivot", Vector3.one, Vector3.new(X, 0, Z), GOLD)
    pivot.Transparency = 1
    self.Head.PrimaryPart = pivot
    part(self.Head, "Crane jib", Vector3.new(72, 1.2, 3.2), Vector3.new(X + 23, 4, Z), GOLD)
    part(self.Head, "Crane top rail", Vector3.new(72, .25, .25), Vector3.new(X + 23, 7, Z), GOLD)
    for x = X - 12, X + 53, 5 do
        beam(self.Head, "Crane jib truss", Vector3.new(x, 4, Z), Vector3.new(x + 2.5, 7, Z), .16, GOLD)
        beam(self.Head, "Crane jib truss", Vector3.new(x + 2.5, 7, Z), Vector3.new(x + 5, 4, Z), .16, GOLD)
    end
    part(self.Head, "Crane counterweight", Vector3.new(6, 5, 5), Vector3.new(X - 10, 2, Z), INK, Enum.Material.Concrete)
    part(self.Head, "Crane cabin", Vector3.new(4, 4, 5), Vector3.new(X + 4, 2, Z), Color3.fromRGB(255, 245, 213))
    part(self.Head, "Crane cabin glass", Vector3.new(.1, 2.7, 4), Vector3.new(X + 6.05, 2, Z), Color3.fromRGB(101, 183, 209), Enum.Material.Glass)
    beam(self.Head, "Hoist cable", Vector3.new(0, 3.5, Z), Vector3.new(0, -15, Z), .08, INK)
    part(self.Head, "Hoist load", Vector3.new(4.5, 1.8, 3.5), Vector3.new(0, -16, Z), Color3.fromRGB(172, 224, 207), Enum.Material.SmoothPlastic)
    for _, dx in {-1.4, 1.4} do
        part(self.Head, "Cargo strap", Vector3.new(.17, 1.9, 3.6), Vector3.new(dx, -16, Z), GOLD)
    end
    self.Height = Instance.new("NumberValue")
    self.Height.Name, self.Height.Parent = "LiftHeight", self.Model
    self.Height.Changed:Connect(function(height) self:ApplyHeight(height) end)
    self.Model.Destroying:Connect(function() if self.Tween then self.Tween:Cancel() end end)
    self:SetStage(0, false)
    return self
end

function Crane:HeightForStage(stage)
    local roof = self.Config.TowerBaseY + stage * self.Config.StageHeight
    if stage == self.Config.MaxStages then roof += self.Config.SpireHeight end
    return roof + 22
end

function Crane:ApplyHeight(height)
    for _, column in self.Columns do
        column.Part.Size = Vector3.new(.38, math.max(1, height - BASE), .38)
        column.Part.Position = Vector3.new(column.X, BASE + (height - BASE) / 2, column.Z)
    end
    local visible = math.clamp(math.floor((height - BASE) / 6), 0, #self.Sections)
    if visible ~= self.VisibleSections then
        for index = math.min(visible, self.VisibleSections) + 1, math.max(visible, self.VisibleSections) do
            for _, p in self.Sections[index].Parts do p.Transparency = index <= visible and 0 or 1 end
        end
        self.VisibleSections = visible
    end
    self.Head:PivotTo(CFrame.new(X, height, Z))
    self.Model:SetAttribute("CurrentHeight", height)
end

function Crane:SetStage(stage, animate)
    local target = self:HeightForStage(stage)
    if self.Tween then self.Tween:Cancel(); self.Tween = nil end
    self.Model:SetAttribute("Stage", stage)
    self.Model:SetAttribute("TargetHeight", target)
    if animate and math.abs(target - self.Height.Value) > .01 then
        local duration = math.clamp(math.abs(target - self.Height.Value) / 40, .75, 2.4)
        self.Tween = TweenService:Create(self.Height, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Value = target})
        self.Tween:Play()
    else
        self.Height.Value = target
        self:ApplyHeight(target)
    end
end

return Crane
