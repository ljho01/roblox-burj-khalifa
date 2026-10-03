-- Real inventory module under deterministic transport/conflict mocks; no Robux.
local records, mode, failures, guid, checks, callbackTwice = {}, nil, 0, 0, 0, false
local function copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}; for k,v in pairs(t) do r[k]=copy(v) end; return r
end
table.clone = copy
local store = {}
function store:UpdateAsync(key, transform)
    if mode == 'before' and failures > 0 then failures=failures-1; error('offline') end
    if callbackTwice then transform(copy(records[key])) end
    local nextRecord=transform(copy(records[key]))
    if nextRecord then records[key]=copy(nextRecord) end
    if mode == 'after' and failures > 0 then failures=failures-1; error('response lost') end
    return copy(nextRecord)
end
local catalog={Items={Slap={},Bat={},Banana={}}}
local services={
    RunService={IsStudio=function()return false end},
    DataStoreService={GetDataStore=function()return store end},
    HttpService={GenerateGUID=function()guid=guid+1;return 'use-'..guid end},
}
local env=setmetatable({game={GameId=99,ReplicatedStorage={Shared={PrankCatalog={}}},GetService=function(_,name)return services[name]end},require=function()return catalog end,task={wait=function()end}}, {__index=_G})
local file=assert(io.open('src/server/PrankInventory.luau'))
local source=file:read('*a');file:close()
source=source:gsub('counts%[ticket.Item%] %+= 1','counts[ticket.Item] = counts[ticket.Item] + 1')
local Inventory=assert(load(source,'@PrankInventory','t',env))()
local function check(value,why)checks=checks+1;assert(value,why)end
local a=Inventory.new();assert(a:Load(1))
check(a:Counts(1).Slap==0,'initial inventory')
callbackTwice=true
check(a:Grant(1,'receipt-a','Slap') and a:Counts(1).Slap==1,'UpdateAsync callback retry double-granted')
check(a:Grant(1,'receipt-a','Slap') and a:Counts(1).Slap==1,'same receipt delivered twice')
local b=Inventory.new();assert(b:Load(1))
check(b:Grant(1,'receipt-a','Slap') and b:Counts(1).Slap==1,'cross-server receipt double-granted')
check(a:Consume(1,'Slap') and a:Counts(1).Slap==0,'consume did not persist')
check(not b:Consume(1,'Slap') and b:Counts(1).Slap==0,'stale server reused spent ticket')
check(a:Grant(1,'receipt-a','Slap') and a:Counts(1).Slap==0,'receipt retry revived consumed item')
check(not a:Grant(1,'receipt-a','Banana') and a:Counts(1).Banana==0,'receipt changed product')
check(not a:Grant(1,'x','Hacked') and not a:Consume(1,'Hacked'),'unknown product accepted')
mode='before';failures=3
check(not a:Grant(1,'receipt-b','Bat') and a:Counts(1).Bat==0,'failed write granted purchase')
mode='after';failures=1
check(a:Grant(1,'receipt-b','Bat') and a:Counts(1).Bat==1,'lost receipt response doubled grant')
mode='after';failures=3
check(not a:Consume(1,'Bat'),'unconfirmed consume reported success')
mode=nil
check(a:Consume(1,'Bat') and a:Counts(1).Bat==0,'ambiguous consume retry lost or duplicated use')
check(not a:Consume(1,'Bat'),'empty inventory usable')
assert(a:Grant(1,'receipt-c','Banana'));a:Remove(1)
local c=Inventory.new();assert(c:Load(1))
check(c:Counts(1).Banana==1 and c:Counts(1).Slap==0,'rejoin did not preserve purchase and consumption')
records.Player_2={Version=999,Tickets={valuable='keep'}}
check(not c:Load(2) and records.Player_2.Version==999,'corrupt data overwritten')
c.Busy[1]=true
check(not c:Grant(1,'busy','Bat'),'overlapping inventory transaction allowed')
c.Busy[1]=nil
assert(c:Load(3))
check(c:Counts(3).Banana==0 and c:Counts(1).Banana==1,'player inventories mixed')
print('PASS: '..checks..' durable prank purchase and consumption checks')
