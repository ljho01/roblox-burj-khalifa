local RunService = game:GetService("RunService")
local Motion = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorkerMotion"))
local folder = workspace:WaitForChild("BurjWorkers")
local workers = {}

local function track(model)
    if not model:IsA("Model") or workers[model] then return end
    local rig = {Joints = {}, Bricks = {}}
    local function add(object)
        if object:IsA("Motor6D") then
            local name = object.Name:gsub(" ", "")
            if name == "LeftShoulder" or name == "RightShoulder" or name == "LeftHip" or name == "RightHip" or name == "RootJoint" or name == "Waist" then
                table.insert(rig.Joints, {Motor = object, Base = object.C0, Name = name})
            end
        elseif object:IsA("BasePart") and object.Parent.Name == "WorkerMaterials" then
            rig.Bricks[object] = true
            -- Upgrades can add bricks between phase changes, including on the
            -- empty return trip. Apply the current visibility immediately.
            object.LocalTransparencyModifier = rig.Carrying and 0 or 1
        end
    end
    for _, object in model:GetDescendants() do add(object) end
    rig.Added = model.DescendantAdded:Connect(add)
    rig.Removing = model.DescendantRemoving:Connect(function(object) rig.Bricks[object] = nil end)
    workers[model] = rig
end
folder.ChildAdded:Connect(track)
folder.ChildRemoved:Connect(function(model)
    if workers[model] then
        workers[model].Added:Disconnect()
        workers[model].Removing:Disconnect()
    end
    workers[model] = nil
end)
for _, model in folder:GetChildren() do track(model) end

RunService.RenderStepped:Connect(function()
    local now = workspace:GetServerTimeNow()
    for model, rig in workers do
        local startedAt, height = model:GetAttribute("StartedAt"), model:GetAttribute("RootHeight")
        if not startedAt or not height or not model.PrimaryPart then continue end
        local root, state, carrying, stride, bend = Motion.Sample(now, startedAt, model:GetAttribute("Slot"), height, model:GetAttribute("Working"))
        model:PivotTo(root)
        for _, joint in rig.Joints do
            local name = joint.Name
            local angle = 0
            if name == "LeftHip" then angle = stride * 0.65
            elseif name == "RightHip" then angle = -stride * 0.65
            elseif name == "LeftShoulder" then angle = carrying and -0.3 + stride * 0.12 or -stride * 0.6
            elseif name == "RightShoulder" then angle = carrying and -0.3 - stride * 0.12 or stride * 0.6
            else angle = -bend end
            joint.Motor.C0 = CFrame.new(joint.Base.Position) * CFrame.Angles(angle, 0, 0) * joint.Base.Rotation
        end
        if rig.Carrying ~= carrying then
            rig.Carrying = carrying
            for brick in rig.Bricks do brick.LocalTransparencyModifier = carrying and 0 or 1 end
            model:SetAttribute("VisualCarrying", carrying)
        end
        if rig.State ~= state then
            rig.State = state
            model:SetAttribute("VisualState", state)
        end
    end
end)
