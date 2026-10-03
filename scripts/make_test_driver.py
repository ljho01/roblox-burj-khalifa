from pathlib import Path
import sys
root = Path(__file__).resolve().parent.parent
sabotage = '--sabotage' in sys.argv
multi = '--multi' in sys.argv or sabotage
server = (root / ('tests/SabotageSmoke.server.luau' if sabotage else 'tests/MultiplayerSmoke.server.luau' if multi else 'tests/RuntimeSmoke.server.luau')).read_text()
workers = (root/'tests/WorkersSmoke.luau').read_text()
client = (root / ('tests/SabotageSmoke.client.luau' if sabotage else 'tests/ClientSmoke.client.luau')).read_text()
execute = 'ExecuteMultiplayerTestAsync(2, {Smoke = true})' if multi else 'ExecutePlayModeAsync({Smoke = true})'
script = '''local workerTests = Instance.new("ModuleScript")
workerTests.Name = "WorkersSmoke"
workerTests.Source = [====[%s]====]
workerTests.Parent = game.ServerScriptService
local prankTests = Instance.new("ModuleScript")
prankTests.Name = "PranksSmoke"
prankTests.Source = [====[%s]====]
prankTests.Parent = game.ServerScriptService
local server = Instance.new("Script")
server.Name = "RuntimeSmoke"
server.Source = [====[%s]====]
server.Parent = game.ServerScriptService
local client = Instance.new("LocalScript")
client.Name = "ClientSmoke"
client.Source = [====[%s]====]
client.Parent = game.StarterPlayer.StarterPlayerScripts
local hotbarClient = Instance.new("LocalScript")
hotbarClient.Name = "HotbarSmoke"
hotbarClient.Source = [====[%s]====]
hotbarClient.Parent = game.StarterPlayer.StarterPlayerScripts
local ready = Instance.new("RemoteEvent")
ready.Name, ready.Parent = "SmokeReady", game.ReplicatedStorage
local bridge = Instance.new("Script")
bridge.Source = [[game.ReplicatedStorage.SmokeReady.OnServerEvent:Connect(function(p, command)
    if type(command) == "string" and string.sub(command, 1, 6) == "Hotbar" then p:SetAttribute("Smoke" .. command, true); return end
    local attributes = {HoldFailure = "SmokeHoldFailure", HoldImmediate = "SmokeHoldImmediate", TheftFX = "SmokeTheftFX", TheftUI = "SmokeTheftUI", TrashFX = "SmokeTrashFX", SabotageClear = "SmokeSabotageClear", StolenBag = "SmokeStolenBag", RebuiltFX = "SmokeRebuiltFX", Pranks = "SmokePranks", Complete = "SmokeSawComplete", Animation = "SmokeSawAnimation", Workers = "SmokeSawWorkers", WorkerTeam = "SmokeSawWorkerTeam", WorkerLoad = "SmokeWorkerLoad", FloorEffects = "SmokeSawFloorEffects", FloorClear = "SmokeFloorClear"}
    p:SetAttribute(attributes[command] or "SmokeClientReady", true)
end)]]
bridge.Parent = game.ServerScriptService
local result = game:GetService("StudioTestService"):%s
print("BURJ_TEST_RESULT", result and result.Passed, result and result.Error)
assert(result and result.Passed, result and result.Error or "Missing test result")
''' % (workers, (root/'tests/PranksSmoke.luau').read_text(), server, client, (root/'tests/HotbarSmoke.client.luau').read_text(), execute)
(root/'dist/smoke-driver.luau').write_text(script)
