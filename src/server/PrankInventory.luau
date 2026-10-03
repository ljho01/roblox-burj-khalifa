-- Purchases and consumption live in one atomic record, separate from progress
-- autosaves. Each receipt is a durable ticket; used tickets remain as receipts.
-- No gameplay remote accepts a receipt or grants a live purchase.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Catalog = require(game.ReplicatedStorage.Shared.PrankCatalog)
local Inventory = {}
Inventory.__index = Inventory

local function validate(record)
    if record == nil then return {Version = 1, Tickets = {}} end
    assert(type(record) == "table" and record.Version == 1 and type(record.Tickets) == "table", "Unsupported purchase record")
    for id, ticket in pairs(record.Tickets) do
        assert(type(id) == "string" and type(ticket) == "table" and Catalog.Items[ticket.Item]
            and (ticket.UseId == nil or type(ticket.UseId) == "string"), "Corrupt purchase record")
    end
    return record
end

function Inventory.new()
    local self = setmetatable({Cache = {}, Memory = {}, Busy = {}, Pending = {}, LocalOnly = RunService:IsStudio() or game.GameId == 0}, Inventory)
    if not self.LocalOnly then
        local ok, store = pcall(function() return DataStoreService:GetDataStore("BurjPrankTickets_v1") end)
        if ok then self.Store = store end
    end
    return self
end

function Inventory:Update(userId, transform)
    if self.Busy[userId] then return nil, "busy" end
    self.Busy[userId] = true
    local result, failure
    for attempt = 1, 3 do
        local ok, value = pcall(function()
            if self.LocalOnly then
                -- Copy before transforming so a failed write cannot mutate cache.
                local old = self.Memory[userId]
                local copy = {Version = 1, Tickets = {}}
                for id, ticket in pairs(old and old.Tickets or {}) do copy.Tickets[id] = table.clone(ticket) end
                local nextRecord = transform(validate(copy))
                self.Memory[userId] = nextRecord
                return nextRecord
            end
            return self.Store:UpdateAsync("Player_" .. userId, function(old, info)
                return transform(validate(old)), {userId}, info and info:GetMetadata() or {}
            end)
        end)
        if ok and value then result = value; break end
        failure = tostring(value)
        if attempt < 3 then task.wait(attempt) end
    end
    if result then self.Cache[userId] = result end
    self.Busy[userId] = nil
    return result, failure
end

function Inventory:Load(userId)
    return self:Update(userId, function(record) return record end)
end

function Inventory:Counts(userId)
    local counts = {Slap = 0, Bat = 0, Banana = 0}
    local record = self.Cache[userId]
    for _, ticket in pairs(record and record.Tickets or {}) do
        if ticket.UseId == nil then counts[ticket.Item] += 1 end
    end
    -- Keep an ambiguous, committed use accessible so the next activation can
    -- finish the SAME operation, even if a later receipt refreshed the cache.
    local pending = self.Pending[userId]
    local ticket = pending and record and record.Tickets[pending.TicketId]
    if ticket and ticket.UseId == pending.UseId then counts[ticket.Item] += 1 end
    return counts
end

function Inventory:Grant(userId, purchaseId, kind)
    if type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 200 or not Catalog.Items[kind] then return false end
    local result = self:Update(userId, function(record)
        local ticket = record.Tickets[purchaseId]
        assert(not ticket or ticket.Item == kind, "Receipt product changed")
        if not ticket then record.Tickets[purchaseId] = {Item = kind} end
        return record
    end)
    return result ~= nil and result.Tickets[purchaseId] ~= nil
end

function Inventory:Consume(userId, kind)
    if not Catalog.Items[kind] then return false end
    local pending = self.Pending[userId]
    if pending and pending.Kind ~= kind then return false end
    if not pending then
        local record = self.Cache[userId]
        for id, ticket in pairs(record and record.Tickets or {}) do
            if ticket.Item == kind and not ticket.UseId then
                pending = {TicketId = id, UseId = HttpService:GenerateGUID(false), Kind = kind}
                break
            end
        end
        if not pending then return false end
        self.Pending[userId] = pending
    end
    local result = self:Update(userId, function(record)
        local ticket = record.Tickets[pending.TicketId]
        if ticket and ticket.Item == kind and not ticket.UseId then ticket.UseId = pending.UseId end
        return record
    end)
    if not result then return false end -- Retry the same operation after a lost response.
    self.Pending[userId] = nil
    return result.Tickets[pending.TicketId] and result.Tickets[pending.TicketId].UseId == pending.UseId
end

function Inventory:Remove(userId)
    -- An in-flight receipt may finish after leaving. Its record is durable and
    -- must not be deleted or rewritten by PlayerRemoving.
    self.Cache[userId], self.Pending[userId] = nil, nil
end
return Inventory
