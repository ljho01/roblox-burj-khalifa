-- One visible toy brick per carried material. Four bricks make a layer, so
-- every capacity upgrade grows the stack instead of hitting an aesthetic cap.
local CarryGeometry = {}
local PALETTE = {
    Color3.fromRGB(255, 207, 132),
    Color3.fromRGB(155, 224, 204),
    Color3.fromRGB(255, 168, 160),
    Color3.fromRGB(156, 202, 244),
}
-- Double every dimension: each material has eight times its original volume.
CarryGeometry.BrickSize = Vector3.new(1.88, 0.68, 1.4)
CarryGeometry.PerLayer = 4
CarryGeometry.LayerHeight = 0.78
function CarryGeometry.LayerCount(amount)
    return math.ceil(math.max(0, amount) / CarryGeometry.PerLayer)
end
function CarryGeometry.Brick(index, level, stolen)
    local layer = math.floor((index - 1) / CarryGeometry.PerLayer)
    local slot = (index - 1) % CarryGeometry.PerLayer
    local column = slot % 2
    local depth = math.floor(slot / 2)
    return {
        Offset = CFrame.new((column - 0.5) * 2.02, -0.10 + layer * CarryGeometry.LayerHeight, 1.73 + depth * 1.52),
        Size = CarryGeometry.BrickSize,
        Color = stolen and Color3.fromRGB(243, 158 + (layer % 3) * 12, 198) or PALETTE[(layer + math.floor((level or 0) / 4)) % #PALETTE + 1],
    }
end
return CarryGeometry
