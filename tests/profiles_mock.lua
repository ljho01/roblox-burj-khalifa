-- Repeatable persistence checks without Roblox Studio or third-party Lua libraries.
-- From the repository root, run: lua tests/profiles_mock.lua
-- Requires Lua 5.3+ (the development machine provides /opt/homebrew/bin/lua).
-- Only Luau compound assignment syntax is desugared; the real Profiles source
-- is evaluated against isolated, deterministic Roblox/DataStore mocks below.
-- These tests do not contact Roblox or prove production DataStore availability.

local checks, calls, guid, timeNow, clockNow = 0, 0, 0, 1000, 0
local studio, failMode, failCount, waitHook = false, nil, 0, nil
local records, warnings = {}, {}
local Players = {}
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local store = {}
function store:UpdateAsync(key, transform)
    if failMode == 'pre' and failCount > 0 then failCount=failCount-1; error('mock service outage') end
    local result = transform(copy(records[key]), {GetMetadata=function()return {custom='preserved'}end})
    if result ~= nil then records[key] = copy(result) end
    if failMode == 'post' and failCount > 0 then failCount=failCount-1; error('mock lost response after commit') end
    return copy(result)
end
local services = {
    DataStoreService = {GetDataStore=function(_,name) assert(name=='BurjBuildersProfiles_v1'); calls=calls+1; return store end},
    HttpService = {GenerateGUID=function()guid=guid+1; return 'token-'..guid end},
    Players = Players,
    RunService = {IsStudio=function()return studio end},
}
game = {GameId=123,GetService=function(_,name)return services[name]end}
task = {wait=function(seconds) clockNow=clockNow+(seconds or 0); timeNow=timeNow+(seconds or 0); if waitHook then waitHook() end end,spawn=function(fn)fn()end}
warn=function(message)table.insert(warnings,message)end
os.time=function()return math.floor(timeNow)end
os.clock=function()return clockNow end
math.clamp=function(value,min,max)return math.max(min,math.min(max,value))end
local moduleFile = assert(io.open('src/server/Profiles.luau', 'r'))
local moduleSource = moduleFile:read('*a')
moduleFile:close()
moduleSource = moduleSource:gsub('([%w_%.]+)%s+([+-])=%s+([^\n]+)', function(target, operator, value)
    return target .. ' = ' .. target .. ' ' .. operator .. ' ' .. value
end)
local Profiles = assert(load(moduleSource, '@src/server/Profiles.luau', 't', _G))()
local config = {StartCoins=0,MaxUpgradeLevel=20}
local function player(id)return {UserId=id,Parent=Players}end
local function check(condition,message)checks=checks+1; assert(condition,message)end

studio=true
local localProfiles, localPlayer=Profiles.new(config),player(1)
local profile=assert(localProfiles:Load(localPlayer)); profile.Coins=42; profile.Carry=8
check(profile.Saved==false and calls==0,'Studio touched DataStore')
assert(localProfiles:Close(localPlayer)); profile=assert(localProfiles:Load(localPlayer))
check(profile.Coins==42 and profile.Carry==0 and profile.Saved==false,'Studio session-local persistence')
studio=false;game.GameId=0
local unpublished=Profiles.new(config); assert(unpublished:Load(player(2)))
check(calls==0,'Unpublished place touched DataStore');game.GameId=123

local a,p=Profiles.new(config),player(10)
profile=assert(a:Load(p)); check(profile.Saved and records.Player_10.Session.ExpiresAt>=os.time()+150,'Lease not acquired')
profile.Coins=80;profile.Strength=999;profile.Speed=-5;profile.Worker=0/0;profile.Wins=1.9;profile.Contributed=math.huge;profile.Carry=7
assert(a:Save(p)); local saved=records.Player_10.Data
check(saved.Coins==80 and saved.Strength==20 and saved.Speed==0 and saved.Worker==0 and saved.Wins==1 and saved.Contributed==0 and saved.Carry==nil and saved.Saved==nil,'Invalid data not sanitized')
local before=copy(records.Player_10)
local b,p2=Profiles.new(config),player(10)
local denied,reason=b:Load(p2)
check(denied==nil and reason:find('another server') and records.Player_10.Session.Token==before.Session.Token,'Active lease stolen')
assert(a:Close(p)); check(records.Player_10.Session==nil and a:Get(p)==nil,'Close did not release')
local rejoined=assert(b:Load(p2));check(rejoined.Coins==80 and rejoined.Carry==0,'Rejoin failed to restore saved data')

local staleToken=records.Player_10.Session.Token
timeNow=timeNow+181
local c,p3=Profiles.new(config),player(10)
assert(c:Load(p3));check(records.Player_10.Session.Token~=staleToken,'Expired lease could not be acquired')
rejoined.Coins=999
local ok=b:Save(p2)
check(not ok and b:Get(p2)==nil and records.Player_10.Data.Coins==80,'Stale server overwrote new session')
assert(c:Close(p3))

local d,p4=Profiles.new(config),player(20)
failMode='pre';failCount=3
local failed=d:Load(p4)
check(failed==nil and d:Get(p4)==nil and records.Player_20==nil,'Failed load played with blank defaults')
failMode='post';failCount=1
assert(d:Load(p4)); check(d:Get(p4)~=nil,'Ambiguous successful load could not retry its own lease')
d:Get(p4).Coins=125
failMode='post';failCount=1
assert(d:Close(p4));check(records.Player_20.Session==nil and records.Player_20.Data.Coins==125,'Ambiguous release failed idempotent retry')
failMode='pre';failCount=3
local reload = Profiles.new(config)
check(reload:Load(player(20))==nil and records.Player_20.Data.Coins==125 and records.Player_20.Session==nil,'Load outage overwrote existing progress')
failMode=nil;failCount=0

local outage, outagePlayer = Profiles.new(config), player(25)
local outageProfile = assert(outage:Load(outagePlayer))
outageProfile.Coins=55;assert(outage:Save(outagePlayer));outageProfile.Coins=70
failMode='pre';failCount=3
check(not outage:Save(outagePlayer) and outageProfile.Saved==false and records.Player_25.Data.Coins==55,'Failed save changed durable progress or hid failure')
failMode=nil;failCount=0
assert(outage:Save(outagePlayer))
check(outageProfile.Saved==true and records.Player_25.Data.Coins==70,'Saving did not recover after outage')
assert(outage:Close(outagePlayer))

records.Player_30={Version=99,Data={Coins=500}}
local corrupt=Profiles.new(config);check(corrupt:Load(player(30))==nil and records.Player_30.Version==99 and records.Player_30.Data.Coins==500,'Unsupported record overwritten')
local departed,p5=Profiles.new(config),player(40);p5.Parent=nil
check(departed:Load(p5)==nil and departed:Get(p5)==nil and records.Player_40.Session==nil,'Load finishing after departure leaked lease')

local releaseLock,p6=Profiles.new(config),player(50)
assert(releaseLock:Load(p6));releaseLock._entries[50].Saving=true
local waits=0
waitHook=function()
    assert(releaseLock._pending > 0, 'Close wait disappeared from shutdown accounting')
    waits=waits+1
    if waits==2 then releaseLock._entries[50].Saving=false end
end
assert(releaseLock:Close(p6));waitHook=nil
check(records.Player_50.Session==nil and waits==2 and releaseLock._pending==0,'Close raced the active save or leaked pending accounting')
local shutdown,p7=Profiles.new(config),player(60)
assert(shutdown:Load(p7));shutdown:Get(p7).Coins=77;shutdown:Shutdown()
check(records.Player_60.Data.Coins==77 and records.Player_60.Session==nil and shutdown:Load(player(61))==nil,'Shutdown failed to release or reject new players')
print('PASS: '..checks..' persistence behavior assertions (mocked DataStore; source compound assignments desugared for Lua).')
