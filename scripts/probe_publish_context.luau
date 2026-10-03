local ok, publishService = pcall(function()
    return game:GetService("StudioPublishService")
end)
print("BURJ_PUBLISH_CONTEXT", game.GameId, game.PlaceId, ok, publishService)
