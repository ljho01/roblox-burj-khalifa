local Config = require(script.Parent.Config)
local Motion = {DeliveryFraction = 0.59}

function Motion.Sample(now, startedAt, slot, height, working)
    local direction = (Config.Positions.Build - Config.Positions.Supply).Unit
    local side = Vector3.new(-direction.Z, 0, direction.X)
    local lane = ((slot - 1) % 5 - 2) * 1.25
    local supply = Vector3.new(Config.Positions.Supply.X, height, Config.Positions.Supply.Z) + side * lane
    local build = Vector3.new(Config.Positions.Build.X, height, Config.Positions.Build.Z) + side * lane
    local phase = math.max(0, now - startedAt) % Config.WorkerInterval / Config.WorkerInterval
    local position, facing, state, carrying, moving, bend
    bend, moving = 0, false
    if not working then
        position, facing, state, carrying = build, -direction, "공사 완료! 쉬는 중", false
    elseif now < startedAt or phase < 0.12 then
        position, facing, state, carrying = supply, direction, "자재 챙기는 중", phase > 0.075 and now >= startedAt
        bend = now >= startedAt and math.sin(phase / 0.12 * math.pi) * 0.32 or 0
    elseif phase < 0.53 then
        position = supply:Lerp(build, (phase - 0.12) / 0.41)
        facing, state, carrying, moving = direction, "자재 운반 중", true, true
    elseif phase < 0.65 then
        position, facing, state, carrying = build, direction, "착착 쌓는 중", phase < Motion.DeliveryFraction
        bend = math.sin((phase - 0.53) / 0.12 * math.pi) * 0.45
    else
        position = build:Lerp(supply, (phase - 0.65) / 0.35)
        facing, state, carrying, moving = -direction, "창고로 돌아가는 중", false, true
    end
    local stride = moving and math.sin((now - startedAt) * 15) or 0
    local bob = moving and math.abs(stride) * 0.12 or 0
    local root = CFrame.lookAt(position + Vector3.new(0, bob, 0), position + facing + Vector3.new(0, bob, 0))
    return root, state, carrying, stride, bend
end

return Motion
