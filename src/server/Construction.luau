-- Pure construction rules, shared by live gameplay and Studio smoke tests.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Construction = {}
function Construction.new()
    return {Stage = 0, StageProgress = 0, TotalBuilt = 0, Complete = false, Round = 1, Contributions = {}, Reservations = {}, Reserved = 0}
end
function Construction.Deposit(state, amount, userId)
    if state.Complete or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0, 0 end
    local accepted = math.min(math.floor(amount), Config.TotalCost() - state.TotalBuilt)
    local remaining = accepted
    local before = state.Stage
    while remaining > 0 and state.Stage < Config.MaxStages do
        local needed = Config.StageCost(state.Stage + 1) - state.StageProgress
        local used = math.min(needed, remaining)
        state.StageProgress += used
        state.TotalBuilt += used
        remaining -= used
        if state.StageProgress >= Config.StageCost(state.Stage + 1) then
            state.Stage += 1
            state.StageProgress = 0
        end
    end
    state.Contributions[userId] = (state.Contributions[userId] or 0) + accepted
    state.Complete = state.Stage == Config.MaxStages
    return accepted, state.Stage - before
end
-- Taking a bag only reserves materials. The shared tower changes at the bin.
function Construction.Reserve(state, amount, userId)
    if state.Complete or state.Reservations[userId] or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
    local taken = math.min(math.floor(amount), math.max(0, state.TotalBuilt - state.Reserved))
    if taken <= 0 then return 0 end
    state.Reservations[userId] = {Amount = taken, Round = state.Round}
    state.Reserved += taken
    return taken
end
function Construction.Release(state, userId)
    local reservation = state.Reservations[userId]
    if not reservation then return 0 end
    state.Reservations[userId] = nil
    state.Reserved -= reservation.Amount
    return reservation.Amount
end
function Construction.Discard(state, userId, round)
    local reservation = state.Reservations[userId]
    if state.Complete or not reservation or round ~= state.Round or reservation.Round ~= round then return 0, 0 end
    local before = state.Stage
    local removed = Construction.Release(state, userId)
    state.TotalBuilt = math.max(0, state.TotalBuilt - removed)
    local remaining = state.TotalBuilt
    state.Stage = 0
    while state.Stage < Config.MaxStages and remaining >= Config.StageCost(state.Stage + 1) do
        remaining -= Config.StageCost(state.Stage + 1)
        state.Stage += 1
    end
    state.StageProgress = remaining
    return removed, before - state.Stage
end
function Construction.Reset(state)
    state.Stage, state.StageProgress, state.TotalBuilt = 0, 0, 0
    state.Complete = false
    state.Round += 1
    state.Contributions = {}
    state.Reservations, state.Reserved = {}, 0
end
return Construction
