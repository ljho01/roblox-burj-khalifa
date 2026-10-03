-- Server-only persistence. Call Save about every 40 seconds, Close on
-- PlayerRemoving, and Shutdown from BindToClose. Stop awarding coins before
-- Close/Shutdown. A failed Load must never be replaced with a blank profile.
--
-- Studio and unpublished places use process-local memory and never contact a
-- DataStore. Published servers use atomic UpdateAsync leases: after a crash a
-- player may need to wait up to 180 seconds before another server can load.
-- Transient outages may lose progress since the last successful save; no
-- server may overwrite another server's active session. Saved is a status flag,
-- not durable data. Carry is intentionally discarded between sessions.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Profiles = {}
Profiles.__index = Profiles

local STORE_NAME = "BurjBuildersProfiles_v1"
local VERSION = 1
local LEASE_SECONDS = 180
local RELEASE_WAIT_SECONDS = 20
local SHUTDOWN_SECONDS = 25 -- Leave room inside Roblox's BindToClose window.
local MAX_ATTEMPTS = 3
local MAX_COINS = 1e12
local MAX_WINS = 1e9
local MAX_CONTRIBUTED = 1e12

local function finiteNumber(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function integer(value, fallback, maximum)
    if not finiteNumber(value) then return fallback end
    return math.clamp(math.floor(value), 0, maximum)
end

local function snapshot(data, config)
    data = type(data) == "table" and data or {}
    local maxLevel = integer(config.MaxUpgradeLevel, 20, 1000)
    return {
        Coins = integer(data.Coins, integer(config.StartCoins, 0, MAX_COINS), MAX_COINS),
        Strength = integer(data.Strength, 0, maxLevel),
        Speed = integer(data.Speed, 0, maxLevel),
        Worker = integer(data.Worker, 0, maxLevel),
        Wins = integer(data.Wins, 0, MAX_WINS),
        Contributed = integer(data.Contributed, 0, MAX_CONTRIBUTED),
    }
end

local function validRecord(record)
    if type(record) ~= "table" or record.Version ~= VERSION or type(record.Data) ~= "table" then
        return false
    end
    local session = record.Session
    return session == nil or (type(session) == "table"
        and type(session.Token) == "string" and #session.Token > 0
        and finiteNumber(session.ExpiresAt))
end

local function recordFor(data, token, lastWrite)
    return {
        Version = VERSION,
        Data = data,
        Session = token and {Token = token, ExpiresAt = os.time() + LEASE_SECONDS} or nil,
        LastWrite = lastWrite,
        UpdatedAt = os.time(),
    }
end

local function metadata(keyInfo)
    return keyInfo and keyInfo:GetMetadata() or {}
end

local function logFailure(operation, player, reason)
    warn(string.format("[BurjProfiles] %s failed for user %d: %s", operation, player.UserId, tostring(reason)))
end

function Profiles.new(config)
    local self = setmetatable({
        _config = config,
        _entries = {},
        _loading = {},
        _memory = {},
        _pending = 0,
        _shuttingDown = false,
        _localOnly = RunService:IsStudio() or game.GameId == 0,
    }, Profiles)
    if not self._localOnly then
        local ok, result = pcall(function()
            return DataStoreService:GetDataStore(STORE_NAME)
        end)
        if ok then self._store = result else self._storeError = tostring(result) end
    end
    return self
end

function Profiles:Get(player)
    local entry = self._entries[player.UserId]
    if entry and entry.Player == player and not entry.Closing and not entry.LeaseLost and not entry.Released then
        return entry.Profile
    end
    return nil
end

function Profiles:Load(player)
    if self._shuttingDown then return nil, "server is shutting down" end
    local existing = self._entries[player.UserId]
    if existing then
        if existing.Player == player and not existing.Closing and not existing.LeaseLost and not existing.Released then
            return existing.Profile
        end
        return nil, "an earlier player session is still closing"
    end
    if self._loading[player.UserId] then return nil, "profile load already in progress" end
    if not self._localOnly and not self._store then
        local reason = self._storeError or "DataStore unavailable"
        logFailure("load", player, reason)
        return nil, reason
    end

    self._loading[player.UserId] = true
    self._pending += 1
    local token = HttpService:GenerateGUID(false)
    local data, failure
    if self._localOnly then
        data = snapshot(self._memory[player.UserId], self._config)
    else
        for attempt = 1, MAX_ATTEMPTS do
            local rejected
            local ok, result = pcall(function()
                return self._store:UpdateAsync("Player_" .. player.UserId, function(old, keyInfo)
                    rejected = nil -- UpdateAsync can rerun this callback after a conflict.
                    if old ~= nil and not validRecord(old) then
                        rejected = "saved record is corrupt or has an unsupported version; preserving it"
                        return nil
                    end
                    if old and old.Session and old.Session.Token ~= token and old.Session.ExpiresAt > os.time() then
                        rejected = "profile is in use by another server; retry shortly"
                        return nil
                    end
                    local nextData = snapshot(old and old.Data, self._config)
                    return recordFor(nextData, token, old and old.LastWrite), {player.UserId}, metadata(keyInfo)
                end)
            end)
            if ok and validRecord(result) and result.Session and result.Session.Token == token then
                data = snapshot(result.Data, self._config)
                break
            end
            failure = rejected or (ok and "profile lease was not acquired" or tostring(result))
            if rejected and string.find(rejected, "corrupt", 1, true) then break end
            if attempt < MAX_ATTEMPTS and not self._shuttingDown then task.wait(attempt) else break end
        end
    end

    self._loading[player.UserId] = nil
    if not data then
        self._pending -= 1
        logFailure("load", player, failure)
        return nil, failure
    end
    data.Carry = 0
    data.Saved = not self._localOnly
    self._entries[player.UserId] = {
        Player = player, Profile = data, Token = token,
        Saving = false, Closing = false, LeaseLost = false,
    }
    -- PlayerRemoving or BindToClose can occur while UpdateAsync is yielding.
    if self._shuttingDown or player.Parent ~= Players then
        self:Close(player)
        self._pending -= 1
        return nil, "player left while profile was loading"
    end
    self._pending -= 1
    return data
end

function Profiles:Save(player, release)
    local entry = self._entries[player.UserId]
    if not entry or entry.Player ~= player then return false, "profile is not loaded" end
    if entry.LeaseLost then return false, "profile session lease was lost" end
    if entry.Released then return false, "profile session was already released" end
    if entry.Closing and not release then return false, "profile is closing" end
    if self._shuttingDown and not release then return false, "server is shutting down" end
    if entry.Saving then
        if not release then return false, "save already in progress" end
        local deadline = os.clock() + RELEASE_WAIT_SECONDS
        while entry.Saving and os.clock() < deadline do task.wait(0.1) end
        if entry.Saving then return false, "timed out waiting for the active save" end
        if entry.LeaseLost or entry.Released then return false, "profile session is no longer owned" end
    end

    entry.Saving = true
    self._pending += 1
    local data = snapshot(entry.Profile, self._config)
    local success, failure = false, nil
    if self._localOnly then
        self._memory[player.UserId] = data
        success = true
    else
        -- An idempotency marker handles a release that committed before a
        -- transport error; a retry still cannot touch a newly acquired lease.
        local writeId = HttpService:GenerateGUID(false)
        for attempt = 1, MAX_ATTEMPTS do
            local rejected
            local ok, result = pcall(function()
                return self._store:UpdateAsync("Player_" .. player.UserId, function(old, keyInfo)
                    rejected = nil
                    if not validRecord(old) then
                        rejected = "saved record changed format; refusing to overwrite it"
                        return nil
                    end
                    if release and old.LastWrite == writeId and old.Session == nil then
                        return old, {player.UserId}, metadata(keyInfo)
                    end
                    if not old.Session or old.Session.Token ~= entry.Token then
                        rejected = "profile session lease was lost; refusing to overwrite another session"
                        return nil
                    end
                    return recordFor(data, not release and entry.Token or nil, writeId), {player.UserId}, metadata(keyInfo)
                end)
            end)
            if ok and validRecord(result) and result.LastWrite == writeId then
                success = true
                break
            end
            failure = rejected or (ok and "save was not committed" or tostring(result))
            if rejected then
                entry.LeaseLost = true
                break
            end
            if attempt < MAX_ATTEMPTS then task.wait(attempt) end
        end
    end
    entry.Profile.Saved = success and not self._localOnly
    if success and release then entry.Released = true end
    entry.Saving = false
    self._pending -= 1
    if not success then logFailure(release and "release" or "save", player, failure) end
    return success, failure
end

function Profiles:Close(player)
    local entry = self._entries[player.UserId]
    if not entry or entry.Player ~= player then return true end
    if entry.Closing then return false, "profile close already in progress" end
    entry.Closing = true
    -- Count the entire close, including time spent waiting for an autosave,
    -- so Shutdown cannot finish between that autosave and the release write.
    self._pending += 1
    local ok, failure = self:Save(player, true)
    if self._entries[player.UserId] == entry then self._entries[player.UserId] = nil end
    self._pending -= 1
    if not ok and entry.Saving then logFailure("release", player, failure) end
    return ok, failure
end

function Profiles:Shutdown()
    if self._shuttingDown then return end
    self._shuttingDown = true
    local pendingCloses = 0
    for _, entry in pairs(self._entries) do
        if not entry.Closing then
            pendingCloses += 1
            task.spawn(function()
                self:Close(entry.Player)
                pendingCloses -= 1
            end)
        end
    end
    local deadline = os.clock() + SHUTDOWN_SECONDS
    while (pendingCloses > 0 or self._pending > 0) and os.clock() < deadline do task.wait(0.1) end
    if pendingCloses > 0 or self._pending > 0 then
        warn("[BurjProfiles] Shutdown save budget exhausted; unfinished leases will expire automatically.")
    end
end

return Profiles
