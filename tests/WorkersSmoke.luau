return function()
    local Workers = require(game.ServerScriptService.Game.Workers)
    local Config = require(game.ReplicatedStorage.Shared.Config)
    local Motion = require(game.ReplicatedStorage.Shared.WorkerMotion)
    local function untilReady(check)
        local deadline = os.clock() + 5
        repeat task.wait(0.03) until check() or os.clock() > deadline
        assert(check(), "Worker fixture timed out")
    end
    local owner = {UserId = 9990001, Parent = game:GetService("Players"), SetAttribute = function() end}
    local earned, avatarCalls = 0, {}
    local service = {
        Leaving = {}, Profiles = {Get = function() return {} end}, Construction = {Stage = 0},
        StateRemote = {FireAllClients = function() end},
        Deposit = function(_, _, amount) earned += amount; return amount end,
    }
    local page = 1
    local pages = {IsFinished = false}
    function pages:GetCurrentPage()
        return page == 1 and {{Id = 101, Username = "First", DisplayName = "첫 친구"}} or {{Id = 102, Username = "Second", DisplayName = "둘째 친구"}, {Id = 101, Username = "Duplicate"}}
    end
    function pages:AdvanceToNextPageAsync() page = 2; self.IsFinished = true end
    local workers = Workers.new(service, {
        GetFriends = function() return pages end,
        CreateAvatar = function(id) table.insert(avatarCalls, id); return Workers.Fallback() end,
    })
    workers.Folder.Name = "WorkersFixture"
    workers:Ensure(owner, 3)
    untilReady(function() return #avatarCalls == 1 and not workers.Owners[owner].Loading end)
    local records = workers.Owners[owner].Records
    assert(#records == 1 and #workers.Owners[owner].Friends == 2, "Restored level must create one carrier; friend pages must be deduplicated")
    local function checkLoad(amount, layers)
        assert(#records == 1 and #workers.Folder:GetChildren() == 1, "Upgrade spawned extra carriers")
        local stack = records[1].Model.WorkerMaterials
        assert(#stack:GetChildren() == amount and stack:GetAttribute("MaterialCount") == amount, "Carried load does not match upgrade level")
        assert(stack:GetAttribute("LayerCount") == layers, "Carried stack height is wrong")
        for _, block in stack:GetChildren() do
            assert(not block.CanCollide and not block.CanTouch and block.Massless, "Worker load interferes with physics")
        end
    end
    checkLoad(6, 2)
    for _, record in records do
        assert(record.Model:GetAttribute("AvatarSource") == "Friend", "Friend avatar did not replace fallback")
        assert(record.Model:FindFirstChild("WorkerMaterials"), "Worker materials missing")
        assert(not record.Model:FindFirstChild("WorkerBadge") and record.Model.Humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None, "Worker displays a name or status bubble")
    end
    local arrival = records[1].NextDelivery
    workers:Step(arrival - 0.01)
    assert(earned == 0, "Worker rewarded before arriving")
    workers:Step(arrival)
    workers:Step(arrival)
    assert(earned == 6, "Arrival paid more than once or used the old 2-material rate")
    workers:SetWorking(false)
    workers:Step(arrival + 100)
    assert(earned == 6, "Celebrating workers are still earning")
    workers:SetWorking(true)
    workers:Step(records[1].NextDelivery)
    assert(earned == 12, "Workers did not resume next round with their upgraded load")
    local avatar, friendId, startedAt, nextDelivery = records[1].Model, records[1].Model:GetAttribute("FriendId"), records[1].StartedAt, records[1].NextDelivery
    workers:Ensure(owner, Config.MaxUpgradeLevel)
    checkLoad(40, 10)
    assert(records[1].Model == avatar and avatar:GetAttribute("FriendId") == friendId and #avatarCalls == 1, "Upgrade rerolled the friend avatar")
    assert(records[1].StartedAt == startedAt and records[1].NextDelivery == nextDelivery, "Upgrade reset the delivery cycle")
    workers:Step(nextDelivery)
    assert(earned == 52, "High-level carrier did not deliver its full visible load")
    workers:Ensure(owner, 100)
    checkLoad(40, 10)
    workers:Ensure(owner, 1)
    checkLoad(2, 1)
    workers:Ensure(owner, 0)
    assert(#workers.Folder:GetChildren() == 0 and workers.Owners[owner] == nil, "Leaving player left workers behind")
    workers.GetFriends = function() error("Friends API unavailable") end
    workers:Ensure(owner, 1)
    untilReady(function() return not workers.Owners[owner].Loading end)
    assert(workers.Owners[owner].RosterStatus == "Unavailable", "Friend request failure not handled")
    assert(workers.Owners[owner].Records[1].Model:GetAttribute("AvatarSource") == "Fallback", "API failure removed fallback worker")
    workers:Remove(owner)
    workers.GetFriends = function() return {IsFinished = true, GetCurrentPage = function() return {} end} end
    workers:Ensure(owner, 1)
    untilReady(function() return not workers.Owners[owner].Loading end)
    assert(workers.Owners[owner].RosterStatus == "Empty", "Empty friend list not handled")
    workers:Remove(owner)
    workers.GetFriends = function() return {IsFinished = true, GetCurrentPage = function() return {{Id = 101, Username = "Late"}} end} end
    workers.CreateAvatar = function() task.wait(0.15); return Workers.Fallback() end
    workers:Ensure(owner, 1)
    local cycleStart = workers.Owners[owner].Records[1].StartedAt
    task.wait(0.05)
    workers:Ensure(owner, 5)
    untilReady(function() return not workers.Owners[owner].Loading end)
    assert(#workers.Owners[owner].Records == 1 and workers.Owners[owner].Records[1].Model.WorkerMaterials:GetAttribute("MaterialCount") == 10, "Late avatar discarded an upgrade")
    assert(workers.Owners[owner].Records[1].StartedAt == cycleStart, "Late avatar reset its trip")
    workers:Remove(owner)
    local lateModel
    workers.CreateAvatar = function() task.wait(0.15); lateModel = Workers.Fallback(); return lateModel end
    workers:Ensure(owner, 1)
    task.wait(0.05)
    workers:Remove(owner)
    task.wait(0.2)
    assert(lateModel and lateModel.Parent == nil and #lateModel:GetChildren() == 0, "Late avatar leaked after player left")
    workers:Destroy()
    local start = 100
    local pickup = Motion.Sample(start, start, 1, 4, true)
    local delivered, _, carrying = Motion.Sample(start + Config.WorkerInterval * 0.6, start, 1, 4, true)
    assert((pickup.Position - delivered.Position).Magnitude > 110 and not carrying, "Worker route or unloading is incorrect")
    print("BURJ_WORKER_LIFECYCLE_PASSED", "one carrier, same friend, loads 2/6/40, earnings, async upgrades, reset, fallback, cleanup")
end
