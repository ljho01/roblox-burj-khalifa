-- Run via Studio CLI in edit mode. Saving now creates a useful editor preview;
-- the runtime regenerates its own stage-zero map when Play starts.
local config = require(game.ReplicatedStorage.Shared.Config)
local world = require(game.ServerScriptService.Game.World).Create(config)
world:SetStage(config.MaxStages)
local height = config.MaxStages * config.StageHeight + config.SpireHeight
workspace.CurrentCamera.FieldOfView = 48
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(640, 360, 790), Vector3.new(0, height * .47, 0))
workspace.CurrentCamera.Focus = CFrame.new(0, height * .47, 0)
local parts = 0
for _, instance in world.Root:GetDescendants() do if instance:IsA("BasePart") then parts += 1 end end
print("BURJ_EDITOR_PREVIEW_READY", parts)
