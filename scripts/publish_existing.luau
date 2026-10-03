local StudioPublishService = game:GetService("StudioPublishService")

local universeId = 10768093665
local placeId = 87004379130048
local finished = false
local success = false
local resultMessage = "Publish did not finish"

StudioPublishService.GamePublishFinished:Connect(function(ok, publishedPlaceId, message, reason)
    finished = true
    success = ok and publishedPlaceId == placeId
    resultMessage = string.format("place=%s message=%s reason=%s", tostring(publishedPlaceId), tostring(message), tostring(reason))
    print("BURJ_PUBLISH_FINISHED", ok, publishedPlaceId, message, reason)
end)

print("BURJ_PUBLISH_START", universeId, placeId)
StudioPublishService:PublishAs(universeId, placeId, 0, true, {}, true, false)

local deadline = os.clock() + 90
repeat task.wait(0.25) until finished or os.clock() >= deadline
assert(finished, resultMessage)
assert(success, resultMessage)
print("BURJ_PUBLISH_OK", universeId, placeId)
