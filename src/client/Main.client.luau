-- A little toy construction kit: soft paper panels, chunky buttons, and a clear view of the tower.
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PrankCatalog = require(ReplicatedStorage.Shared.PrankCatalog)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local action = remotes:WaitForChild("Action")
local stateEvent = remotes:WaitForChild("State")
local getState = remotes:WaitForChild("GetState")

-- The built-in leaderboard covers the shop; coins and wins are already in this HUD.
task.spawn(function()
    for _ = 1, 8 do
        if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end) then return end
        task.wait(0.5)
    end
end)

local C = {
    Navy = Color3.fromRGB(74, 60, 89),
    Panel = Color3.fromRGB(245, 239, 250),
    Steel = Color3.fromRGB(118, 101, 135),
    White = Color3.fromRGB(255, 253, 249),
    Yellow = Color3.fromRGB(255, 226, 133),
    Line = Color3.fromRGB(215, 201, 225),
    Green = Color3.fromRGB(173, 229, 199),
    Red = Color3.fromRGB(236, 156, 152),
    Peach = Color3.fromRGB(255, 200, 177),
    Blue = Color3.fromRGB(189, 221, 248),
}

local function create(className, parent, properties)
    local item = Instance.new(className)
    for key, value in pairs(properties or {}) do item[key] = value end
    item.Parent = parent
    return item
end

local function round(item, radius)
    create("UICorner", item, {CornerRadius = UDim.new(0, radius or 18)})
end

local function outline(item, color)
    create("UIStroke", item, {Color = color or C.Line, Thickness = 2, Transparency = 0})
end

local function panel(parent, name, size, position)
    local frame = create("Frame", parent, {
        Name = name, Size = size, Position = position,
        BorderSizePixel = 0, BackgroundColor3 = C.White, BackgroundTransparency = 0.02,
    })
    round(frame, 21)
    outline(frame)
    return frame
end

local function label(parent, name, text, size, position, fontSize, color, font)
    return create("TextLabel", parent, {
        Name = name, Text = text, Size = size, Position = position,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = font or Enum.Font.Gotham, TextSize = fontSize or 16,
        TextColor3 = color or C.Navy, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })
end

local function button(parent, name, text, size, position, primary)
    local b = create("TextButton", parent, {
        Name = name, Text = text, Size = size, Position = position,
        BackgroundColor3 = primary and C.Yellow or C.Panel,
        TextColor3 = C.Navy,
        Font = Enum.Font.GothamBold, TextSize = 16,
        BorderSizePixel = 0, AutoButtonColor = true,
        Selectable = true,
    })
    round(b, 18)
    outline(b, primary and Color3.fromRGB(225, 186, 83) or C.Line)
    b.MouseButton1Down:Connect(function()
        if b.Active then
            TweenService:Create(b, TweenInfo.new(0.08), {BackgroundTransparency = 0.18}):Play()
        end
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)
    b.MouseLeave:Connect(function() b.BackgroundTransparency = 0 end)
    return b
end

local function number(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 10000 then return string.format("%.1fK", n / 1000) end
    local str = tostring(n)
    return str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {
    Name = "BurjHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local host = create("Frame", gui, {
    Name = "SafeArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
})
local root = create("Frame", host, {
    Name = "Dashboard", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
})
local scale = create("UIScale", root, {Scale = 1})

-- These icons are native UI shapes, so the HUD needs no uploaded assets.
local function brickIcon(parent, position, tint)
    local icon = create("Frame", parent, {Name = "BrickIcon", Position = position, Size = UDim2.fromOffset(28, 19), BackgroundColor3 = tint or C.Peach, BorderSizePixel = 0, Rotation = -8})
    round(icon, 5)
    outline(icon, C.Navy)
    for x = 5, 17, 12 do
        local stud = create("Frame", icon, {Position = UDim2.fromOffset(x, -5), Size = UDim2.fromOffset(7, 5), BackgroundColor3 = tint or C.Peach, BorderSizePixel = 0})
        round(stud, 2)
    end
    return icon
end

local brand = create("Frame", root, {
    Name = "Brand", Size = UDim2.fromOffset(265, 58), Position = UDim2.fromOffset(22, 78), BackgroundTransparency = 1,
})
local helmet = create("Frame", brand, {Name = "Helmet", Position = UDim2.fromOffset(2, 8), Size = UDim2.fromOffset(32, 26), BackgroundColor3 = C.Yellow, BorderSizePixel = 0})
round(helmet, 15)
outline(helmet, C.Navy)
local brim = create("Frame", helmet, {Position = UDim2.fromOffset(-4, 21), Size = UDim2.fromOffset(40, 8), BackgroundColor3 = C.Yellow, BorderSizePixel = 0})
round(brim, 4)
outline(brim, C.Navy)
local helmetStripe = create("Frame", helmet, {Position = UDim2.fromOffset(13, 1), Size = UDim2.fromOffset(6, 21), BackgroundColor3 = C.Peach, BorderSizePixel = 0})
round(helmetStripe, 3)
local brandTitle = label(brand, "Title", Config.Title, UDim2.fromOffset(231, 37), UDim2.fromOffset(43, 0), 29, C.White, Enum.Font.FredokaOne)
create("UIStroke", brandTitle, {Color = C.Navy, Thickness = 2.3})
local brandSub = label(brand, "Subtitle", "차곡차곡, 하늘까지!", UDim2.fromOffset(231, 22), UDim2.fromOffset(45, 35), 13, C.Navy, Enum.Font.GothamBold)
create("UIStroke", brandSub, {Color = C.White, Thickness = 1.2})

local progress = panel(root, "TowerProgress", UDim2.fromOffset(410, 82), UDim2.new(0.5, -205, 0, 8))
progress.BackgroundColor3 = C.White
local stageIcon = brickIcon(progress, UDim2.fromOffset(18, 19), C.Green)
local progressTitle = label(progress, "Stage", "첫 벽돌을 기다려요!", UDim2.new(1, -160, 0, 27), UDim2.fromOffset(57, 8), 17, C.Navy, Enum.Font.GothamBold)
local progressHeight = label(progress, "Height", "0 / 828m", UDim2.fromOffset(104, 27), UDim2.new(1, -120, 0, 8), 17, C.Steel, Enum.Font.FredokaOne)
progressHeight.TextXAlignment = Enum.TextXAlignment.Right
local progressTrack = create("Frame", progress, {
    Name = "Track", Position = UDim2.fromOffset(17, 41), Size = UDim2.new(1, -34, 0, 13),
    BackgroundColor3 = C.Panel, BorderSizePixel = 0,
})
round(progressTrack, 7)
local progressFill = create("Frame", progressTrack, {Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, BorderSizePixel = 0})
round(progressFill, 7)
local progressDetail = label(progress, "Detail", "함께 첫 구간을 만들어 봐요", UDim2.new(1, -34, 0, 20), UDim2.fromOffset(17, 57), 12, C.Steel)
progressDetail.TextXAlignment = Enum.TextXAlignment.Center

local stats = panel(root, "Inventory", UDim2.fromOffset(224, 150), UDim2.new(0, 22, 1, -40))
stats.AnchorPoint = Vector2.new(0, 1)
local statNames = {"내 코인", "등에 멘 자재", "완공한 탑"}
local statKeys = {"Coins", "Carry", "Wins"}
local statLabels, statValues, statRules = {}, {}, {}
for i, key in ipairs(statKeys) do
    statLabels[key] = label(stats, key .. "Label", statNames[i], UDim2.fromOffset(108, 40), UDim2.fromOffset(15, (i - 1) * 46 + 7), 13, C.Steel)
    statValues[key] = label(stats, key, "0", UDim2.fromOffset(92, 40), UDim2.new(1, -106, 0, (i - 1) * 46 + 7), 21, C.Navy, Enum.Font.FredokaOne)
    statValues[key].TextXAlignment = Enum.TextXAlignment.Right
    if i < 3 then
        statRules[i] = create("Frame", stats, {Name = "Divider", Size = UDim2.new(1, -30, 0, 1), Position = UDim2.fromOffset(15, i * 46 + 5), BackgroundColor3 = C.Panel, BorderSizePixel = 0})
    end
end

local tutorial = panel(root, "QuickGuide", UDim2.fromOffset(224, 133), UDim2.fromOffset(22, 260))
label(tutorial, "Heading", "작은 건축가의 첫걸음", UDim2.new(1, -50, 0, 28), UDim2.fromOffset(15, 9), 14, C.Navy, Enum.Font.GothamBold)
local tutorialClose = button(tutorial, "Close", "×", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0, 7), false)
tutorialClose.BackgroundTransparency = 1
tutorialClose:FindFirstChildOfClass("UIStroke").Enabled = false
local tutorialBody = label(tutorial, "Steps", "①  자재 창고에서 등에 차곡차곡\n②  공사장에 내려놓으면 쑥쑥!\n③  코인으로 더 많이 운반해요", UDim2.new(1, -30, 0, 82), UDim2.fromOffset(15, 41), 13, C.Steel)
tutorialBody.TextYAlignment = Enum.TextYAlignment.Top
tutorialBody.TextWrapped = true
tutorialBody.LineHeight = 1.35
tutorialClose.Activated:Connect(function() tutorial.Visible = false end)

local shopToggle = button(root, "ShopToggle", "장비 꾸러미  [B]", UDim2.fromOffset(160, 48), UDim2.new(1, -182, 0, 20), false)
local returnButton = button(root, "ReturnToSite", "↓  공사장으로", UDim2.fromOffset(160, 42), UDim2.new(1, -182, 0, 78), false)
returnButton.Visible = false
returnButton.Activated:Connect(function() action:FireServer("Return") end)

local objective = panel(root, "CurrentTask", UDim2.fromOffset(440, 105), UDim2.new(0.5, -220, 1, -129))
local objectiveLabel = label(objective, "Objective", "자재 창고로 출발!", UDim2.new(1, -30, 0, 32), UDim2.fromOffset(15, 7), 15, C.Navy, Enum.Font.GothamBold)
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Center
local interactButton = button(objective, "Interact", "창고에서 자재를 받아요", UDim2.new(1, -24, 0, 46), UDim2.fromOffset(12, 47), true)
local stealProgress = create("Frame", interactButton, {Name = "StealProgress", Visible = false, BorderSizePixel = 0,
    BackgroundColor3 = C.Peach, Position = UDim2.new(0, 8, 1, -6), Size = UDim2.new(0, 0, 0, 4)})
round(stealProgress, 3)
local stealHold = require(script.Parent.StealHold).new(player, interactButton)
local purchasePrank
local hotbarFrame = create("Frame", root, {Name = "Hotbar", BackgroundTransparency = 1,
    Size = UDim2.fromOffset(340, 60), Position = UDim2.new(.5, -170, 1, -80)})
local hotbarButtons = {}
for index = 1, 4 do
    local slot = button(hotbarFrame, "Slot" .. index, "", UDim2.new(.25, -6, 1, 0), UDim2.new((index - 1) / 4, 3, 0, 0), false)
    slot.TextSize = 13
    hotbarButtons[index] = slot
end
local hotbar = require(script.Parent.Hotbar).new(player, hotbarFrame, hotbarButtons, C, stealHold, function(kind)
    if purchasePrank then purchasePrank(kind) end
end)


local saveLabel = label(root, "SaveStatus", "서버 연결 중…", UDim2.fromOffset(290, 18), UDim2.new(0, 22, 1, -24), 11, C.Navy)
create("UIStroke", saveLabel, {Color = C.White, Thickness = 1.5, Transparency = 0.15})

local shop = panel(root, "Shop", UDim2.fromOffset(382, 398), UDim2.new(1, -404, 0.5, -150))
shop.Visible = false
shop.ZIndex = 15
label(shop, "Title", "건축가의 장비 꾸러미", UDim2.new(1, -68, 0, 35), UDim2.fromOffset(20, 14), 22, C.Navy, Enum.Font.GothamBold)
local upgradeTab = button(shop, "UpgradeTab", "코인 장비", UDim2.new(.5, -24, 0, 30), UDim2.fromOffset(16, 53), false)
local prankTab = button(shop, "PrankTab", "장난감 · 20 R$", UDim2.new(.5, -24, 0, 30), UDim2.new(.5, 8, 0, 53), false)
upgradeTab.TextSize, prankTab.TextSize = 13, 13
local shopClose = button(shop, "Close", "×", UDim2.fromOffset(36, 36), UDim2.new(1, -52, 0, 14), false)
shopClose.Activated:Connect(function() shop.Visible = false end)
local upgradeRows = {}
local descriptions = {
    Strength = function(level) return "한 번에 자재 " .. Config.Capacity(level) .. " → " .. Config.Capacity(level + 1) .. "개 운반" end,
    Speed = function(level) return string.format("이동 속도 %.1f → %.1f", Config.WalkSpeed(level), Config.WalkSpeed(level + 1)) end,
    Worker = function(level)
        if level == 0 then return "친구 운반자 1명 고용 · " .. Config.WorkerInterval .. "초마다 자재 2개" end
        return "한 명이 더 많이! 자재 " .. Config.WorkerCapacity(level) .. " → " .. Config.WorkerCapacity(level + 1) .. "개 / " .. Config.WorkerInterval .. "초"
    end,
}
for i, kind in ipairs({"Strength", "Speed", "Worker"}) do
    local row = create("Frame", shop, {Name = kind, Position = UDim2.fromOffset(16, 96 + (i - 1) * 97), Size = UDim2.new(1, -32, 0, 89), BackgroundColor3 = C.Panel, BorderSizePixel = 0})
    round(row, 17)
    outline(row)
    local nameLabel = label(row, "Name", Config.UpgradeNames[kind], UDim2.new(1, -120, 0, 27), UDim2.fromOffset(13, 8), 16, C.Navy, Enum.Font.GothamBold)
    local levelLabel = label(row, "Level", "Lv.0", UDim2.fromOffset(60, 24), UDim2.new(1, -73, 0, 10), 13, C.Steel)
    levelLabel.TextXAlignment = Enum.TextXAlignment.Right
    local description = label(row, "Benefit", "", UDim2.new(1, -130, 0, 34), UDim2.fromOffset(13, 40), 12, C.Steel)
    description.TextWrapped = true
    local buy = button(row, "Buy", "", UDim2.fromOffset(102, 34), UDim2.new(1, -115, 0, 42), true)
    buy.TextSize = 14
    upgradeRows[kind] = {Name = nameLabel, Level = levelLabel, Description = description, Buy = buy, Frame = row}
    buy.Activated:Connect(function() action:FireServer("Upgrade", kind) end)
end

local prankRows = {}
local prankState = {Ready = false, Counts = {}, Studio = RunService:IsStudio()}
local priceInfo, prompting = {}, false
purchasePrank = function(kind)
    local item = PrankCatalog.Items[kind]
    if not item or item.ProductId <= 0 or prompting then return false end
    if RunService:IsStudio() then
        action:FireServer("TryPrank", kind)
        return true
    end
    prompting = true
    local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, item.ProductId) end)
    if not ok then prompting = false end
    return ok
end
for i, kind in ipairs(PrankCatalog.Order) do
    local item = PrankCatalog.Items[kind]
    local row = create("Frame", shop, {Name = kind, Visible = false, Position = UDim2.fromOffset(16, 96 + (i - 1) * 97), Size = UDim2.new(1, -32, 0, 89), BackgroundColor3 = i == 2 and C.Panel or C.White:Lerp(C.Yellow, .3), BorderSizePixel = 0})
    round(row, 17); outline(row)
    local title = label(row, "Name", item.Icon .. "  " .. item.Name .. " · 0개", UDim2.new(1, -105, 0, 27), UDim2.fromOffset(13, 6), 15, C.Navy, Enum.Font.GothamBold)
    local info = label(row, "Description", item.Description, UDim2.new(1, -121, 0, 42), UDim2.fromOffset(13, 37), 12, C.Steel)
    info.TextWrapped = true
    local equip = button(row, "Equip", "꺼내기", UDim2.fromOffset(90, 25), UDim2.new(1, -103, 0, 8), false)
    equip.TextSize = 12
    local buy = button(row, "Buy", "20 R$ · 1회", UDim2.fromOffset(101, 34), UDim2.new(1, -114, 0, 43), true)
    buy.TextSize = 13
    prankRows[kind] = {Frame = row, Title = title, Buy = buy, Equip = equip}
    equip.Activated:Connect(function()
        if hotbar:Select(i + 1) then shop.Visible = false end
    end)
    buy.Activated:Connect(function()
        if not buy.Active or not prankState.Ready then return end
        purchasePrank(kind)
    end)
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
    if userId == player.UserId then prompting = false end -- Never grants an item here.
end)
local function renderPranks()
    for kind, row in pairs(prankRows) do
        local item = PrankCatalog.Items[kind]
        local owned = prankState.Counts[kind] or 0
        row.Title.Text = item.Icon .. "  " .. item.Name .. " · " .. owned .. "개"
        row.Equip.Active, row.Equip.AutoButtonColor = owned > 0, owned > 0
        row.Equip.BackgroundColor3 = owned > 0 and C.Green or C.Panel
        local ready = prankState.Ready and (RunService:IsStudio() or priceInfo[kind] ~= nil)
        row.Buy.Active, row.Buy.AutoButtonColor = ready, ready
        row.Buy.BackgroundColor3 = ready and C.Yellow or C.Line
        row.Buy.Text = not prankState.Ready and "가방 연결 중" or (RunService:IsStudio() and "무료 체험 +1" or (priceInfo[kind] and tostring(priceInfo[kind]) .. " R$ · 1회" or "판매 준비 중"))
    end
end
local function showShopTab(pranks)
    for _, row in pairs(upgradeRows) do row.Frame.Visible = not pranks end
    for _, row in pairs(prankRows) do row.Frame.Visible = pranks end
    upgradeTab.BackgroundColor3 = pranks and C.Panel or C.Green
    prankTab.BackgroundColor3 = pranks and C.Peach or C.Panel
    if pranks then
        action:FireServer("LoadPranks")
        renderPranks()
        task.spawn(function()
            for _, kind in ipairs(PrankCatalog.Order) do
                local item = PrankCatalog.Items[kind]
                if item.ProductId > 0 and not RunService:IsStudio() then
                    local ok, data = pcall(function() return MarketplaceService:GetProductInfoAsync(item.ProductId, Enum.InfoType.Product) end)
                    priceInfo[kind] = ok and data and data.IsForSale ~= false and data.PriceInRobux or nil
                end
            end
            renderPranks()
        end)
    end
end
upgradeTab.Activated:Connect(function() showShopTab(false) end)
prankTab.Activated:Connect(function() showShopTab(true) end)
showShopTab(false)

local toastHost = create("Frame", root, {Name = "Toasts", Size = UDim2.fromOffset(400, 224), Position = UDim2.new(0.5, -200, 0, 124), BackgroundTransparency = 1, ZIndex = 30})
create("UIListLayout", toastHost, {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
local toastOrder = 0
local function toast(text, kind)
    toastOrder += 1
    local tint = kind == "error" and C.Peach or (kind == "success" and C.Green or C.Line)
    local item = create("Frame", toastHost, {
        Name = "Toast", Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1,
        LayoutOrder = toastOrder, ZIndex = 30,
    })
    -- Fade the whole bubble together, including its outline, face and shadow.
    local bubble = create("CanvasGroup", item, {
        Name = "Bubble", Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 30,
    })
    local pop = create("UIScale", bubble, {Scale = 0.9})
    local shadow = create("Frame", bubble, {
        Name = "SoftShadow", Position = UDim2.fromOffset(5, 9), Size = UDim2.new(1, -10, 1, -14),
        BackgroundColor3 = C.Navy, BackgroundTransparency = 0.89, BorderSizePixel = 0, ZIndex = 30,
    })
    round(shadow, 20)
    local card = create("Frame", bubble, {
        Name = "Card", Position = UDim2.fromOffset(5, 4), Size = UDim2.new(1, -10, 1, -14),
        BackgroundColor3 = C.White:Lerp(tint, 0.32), BorderSizePixel = 0, ZIndex = 31,
    })
    round(card, 20)
    create("UIStroke", card, {Color = tint:Lerp(C.Navy, 0.12), Thickness = 1.5})
    local face = create("Frame", card, {
        Name = "LittleBrick", Position = UDim2.fromOffset(14, 17), Size = UDim2.fromOffset(32, 25),
        BackgroundColor3 = tint, BorderSizePixel = 0, Rotation = kind == "error" and 6 or -7, ZIndex = 32,
    })
    round(face, 7)
    create("UIStroke", face, {Color = tint:Lerp(C.Navy, 0.28), Thickness = 1.4})
    for _, x in {5, 20} do
        local stud = create("Frame", face, {
            Position = UDim2.fromOffset(x, -4), Size = UDim2.fromOffset(8, 5),
            BackgroundColor3 = tint, BorderSizePixel = 0, ZIndex = 32,
        })
        round(stud, 2)
        local eye = create("Frame", face, {
            Position = UDim2.fromOffset(x + 3, 8), Size = UDim2.fromOffset(3, 4),
            BackgroundColor3 = C.Navy, BorderSizePixel = 0, ZIndex = 33,
        })
        round(eye, 2)
    end
    local mouth = create("Frame", face, {
        Position = UDim2.fromOffset(kind == "error" and 14 or 12, 16),
        Size = UDim2.fromOffset(kind == "error" and 4 or 9, kind == "error" and 5 or 3),
        BackgroundColor3 = C.Navy, BorderSizePixel = 0, ZIndex = 33,
    })
    round(mouth, 3)
    local txt = label(card, "Text", text, UDim2.new(1, -77, 1, -10), UDim2.fromOffset(59, 5), 14, C.Navy, Enum.Font.GothamBold)
    txt.TextWrapped = true
    txt.LineHeight = 1.12
    txt.ZIndex = 32
    TweenService:Create(bubble, TweenInfo.new(0.14), {GroupTransparency = 0}):Play()
    TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    local entries = {}
    for _, child in ipairs(toastHost:GetChildren()) do
        if child:IsA("Frame") then table.insert(entries, child) end
    end
    table.sort(entries, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    if #entries > 3 then entries[1]:Destroy() end
    task.delay(3.8, function()
        if item.Parent then
            TweenService:Create(bubble, TweenInfo.new(0.22), {GroupTransparency = 1}):Play()
            TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {Scale = 0.96}):Play()
            task.wait(0.24)
            item:Destroy()
        end
    end)
end

local celebration = panel(root, "Completion", UDim2.fromOffset(470, 204), UDim2.new(0.5, -235, 0.5, -102))
celebration.Visible = false
celebration.ZIndex = 25
local celebrateTitle = label(celebration, "Title", "828m, 함께 해냈어요!", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 16), 27, C.Navy, Enum.Font.GothamBold)
celebrateTitle.TextXAlignment = Enum.TextXAlignment.Center
local celebrateBody = label(celebration, "Body", "부르즈 할리파 완공! 전망대에서 경치를 감상하세요.", UDim2.new(1, -44, 0, 50), UDim2.fromOffset(22, 64), 15, C.Navy)
celebrateBody.TextWrapped = true
celebrateBody.TextXAlignment = Enum.TextXAlignment.Center
local celebrateCountdown = label(celebration, "Countdown", "", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 119), 13, C.Steel)
celebrateCountdown.TextXAlignment = Enum.TextXAlignment.Center
local celebrateClose = button(celebration, "Continue", "계속 둘러보기", UDim2.new(1, -44, 0, 40), UDim2.fromOffset(22, 150), true)
local dismissedRound = nil

local snapshot = {
    Coins = 0, Carry = 0, Capacity = Config.BaseCapacity, Strength = 0, Speed = 0, Worker = 0,
    Wins = 0, Contributed = 0, Stage = 0, StageProgress = 0, StageCost = Config.StageCost(1),
    TotalBuilt = 0, TotalCost = Config.TotalCost(), Round = 0, Complete = false, ResetIn = 0,
}
local initialized = false
local nearest = nil
local lastConfettiRound = nil
local lastActionTime = 0

local function confetti()
    for i = 1, 32 do
        local bit = create("Frame", root, {
            Name = "Confetti", Size = UDim2.fromOffset(math.random(5, 9), math.random(10, 17)),
            Position = UDim2.new(math.random(), 0, -0.08, 0), Rotation = math.random(0, 180),
            BackgroundColor3 = ({C.Yellow, C.White, C.Steel, C.Green})[(i - 1) % 4 + 1],
            BorderSizePixel = 0, ZIndex = 40,
        })
        local t = math.random(22, 40) / 10
        TweenService:Create(bit, TweenInfo.new(t, Enum.EasingStyle.Linear), {
            Position = UDim2.new(bit.Position.X.Scale + math.random(-12, 12) / 100, 0, 1.1, 0),
            Rotation = bit.Rotation + 250, BackgroundTransparency = 0.45,
        }):Play()
        task.delay(t, function() bit:Destroy() end)
    end
end

local function openShop(kind)
    shop.Visible = true
    if kind then showShopTab(false) end
    for key, row in pairs(upgradeRows) do
        row.Frame.BackgroundColor3 = key == kind and C.Green or C.Panel
    end
end

shopToggle.Activated:Connect(function()
    if shop.Visible then shop.Visible = false else openShop() end
end)
celebrateClose.Activated:Connect(function()
    dismissedRound = snapshot.Round
    celebration.Visible = false
end)

local function updateAction()
    interactButton:SetAttribute("Action", nearest)
    local carry, cap = snapshot.Carry or 0, snapshot.Capacity or Config.BaseCapacity
    local available = nearest ~= nil and initialized
    if snapshot.Complete then
        objectiveLabel.Text = "우와, 완공! 전망대로 올라가 봐요"
    elseif snapshot.Stolen then
        objectiveLabel.Text = "빼돌린 자재 " .. carry .. "개 · 분홍 쓰레기통으로!"
    elseif carry > 0 then
        objectiveLabel.Text = "자재 " .. carry .. "개를 메고 공사장으로!"
    else
        objectiveLabel.Text = "자재 창고에서 등에 차곡차곡 쌓아요"
    end
    local prefix = UserInputService.TouchEnabled and "" or "[E]  "
    if nearest == "Supply" then
        interactButton.Text = carry >= cap and "등에 한가득! 공사장으로 출발" or prefix .. "자재 받기"
        available = available and carry < cap and not snapshot.Complete
    elseif nearest == "Build" then
        interactButton.Text = snapshot.Complete and "부르즈 할리파 완공!" or (carry > 0 and prefix .. "자재 " .. carry .. "개 내려놓기!" or "먼저 창고에서 자재를 받아요")
        available = available and carry > 0 and not snapshot.Complete
    elseif nearest == "Steal" then
        local amount = math.min(cap, snapshot.Stealable or 0)
        interactButton.Text = carry > 0 and "먼저 가방을 비워 주세요" or (amount > 0 and prefix .. string.format("꾹 누르기 · %d개 · %.1f초", amount, Config.StealDuration(amount)) or "빼돌릴 자재가 아직 없어요")
        available = available and carry == 0 and amount > 0 and not snapshot.Complete
    elseif nearest == "Trash" then
        interactButton.Text = snapshot.Stolen and prefix .. "자재 " .. carry .. "개 쓰레기통에 버리기" or "공사장에서 빼돌린 자재를 가져와요"
        available = available and snapshot.Stolen and carry > 0 and not snapshot.Complete
    elseif nearest == "Lookout" then
        interactButton.Text = prefix .. "전망대로 올라가기"
    elseif nearest and Config.UpgradeNames[nearest] then
        interactButton.Text = "장비 꾸러미 열기 · " .. Config.UpgradeNames[nearest]
    else
        interactButton.Text = snapshot.Stolen and "분홍 쓰레기통으로 걸어가요" or (carry > 0 and "노란 공사장으로 걸어가요" or "초록 창고로 걸어가요")
    end
    if snapshot.Stolen and (nearest == "Supply" or nearest == "Build" or nearest == "Lookout") then
        available = false
        interactButton.Text = "빼돌린 자재는 분홍 쓰레기통으로!"
    end
    if player:GetAttribute("Depositing") then
        available = false
        local trash = player:GetAttribute("DepositEffectKind") == "TrashEffect"
        interactButton.Text = trash and "쓰레기통에 쏙!" or "차곡차곡 쌓는 중…"
        objectiveLabel.Text = trash and "버린 자재만큼 공사가 줄어들어요" or "자재가 공사장으로 날아가요!"
    end
    local stealingUntil = player:GetAttribute("StealingUntil")
    stealProgress.Visible = stealingUntil ~= nil
    if stealingUntil then
        local remaining = math.max(0, stealingUntil - workspace:GetServerTimeNow())
        local duration = player:GetAttribute("StealingDuration") or Config.StealDuration(Config.BaseCapacity)
        local fraction = math.clamp(1 - remaining / duration, 0, 1)
        stealProgress.Size = UDim2.new(fraction, -16 * fraction, 0, 4)
        available = false
        interactButton.Text = string.format("계속 꾹 눌러 주세요 · %.1f초", remaining)
        objectiveLabel.Text = string.format("자재 %d개 빼돌리기 · 손을 떼면 취소", player:GetAttribute("StealingAmount") or 0)
    end
    if player:GetAttribute("PrankStunned") then
        available = false
        interactButton.Text = "일어나는 중… 잠깐만요!"
    end
    interactButton.Active = available
    interactButton.AutoButtonColor = available
    interactButton.BackgroundColor3 = available and C.Yellow or C.Panel
    interactButton.TextColor3 = available and C.Navy or C.Steel
end

player:GetAttributeChangedSignal("Depositing"):Connect(updateAction)
player:GetAttributeChangedSignal("StealingUntil"):Connect(updateAction)
player:GetAttributeChangedSignal("PrankStunned"):Connect(updateAction)

interactButton.Activated:Connect(function()
    if not initialized or not nearest or not interactButton.Active then return end
    if os.clock() - lastActionTime < 0.3 then return end
    lastActionTime = os.clock()
    if Config.UpgradeNames[nearest] then openShop(nearest)
    elseif nearest ~= "Steal" then action:FireServer("Interact", nearest) end
end)

local progressTween = nil
local function render(data)
    if type(data) ~= "table" then return end
    for key, value in pairs(data) do snapshot[key] = value end
    initialized = true
    stealHold:Update(snapshot)
    if snapshot.Pranks then prankState = snapshot.Pranks; renderPranks() end
    statValues.Coins.Text = number(snapshot.Coins)
    statValues.Carry.Text = string.format("%d / %d", snapshot.Carry, snapshot.Capacity)
    statLabels.Carry.Text = snapshot.Stolen and "빼돌린 자재" or "등에 멘 자재"
    statValues.Wins.Text = number(snapshot.Wins)
    if (snapshot.Contributed or 0) > 0 then tutorial.Visible = false end
    local stage = math.clamp(snapshot.Stage or 0, 0, Config.MaxStages)
    local fractional = stage + ((not snapshot.Complete and snapshot.StageCost > 0) and math.clamp(snapshot.StageProgress / snapshot.StageCost, 0, 1) or 0)
    local height = math.floor(math.min(fractional / Config.MaxStages, 1) * Config.HeightMeters)
    progressTitle.Text = snapshot.Complete and "하늘까지 완성!" or string.format("%d / %d 구간", stage, Config.MaxStages)
    progressHeight.Text = string.format("%dm / %dm", height, Config.HeightMeters)
    local ratio = math.clamp(snapshot.TotalBuilt / math.max(snapshot.TotalCost, 1), 0, 1)
    if progressTween then progressTween:Cancel() end
    progressTween = TweenService:Create(progressFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(ratio, 1)})
    progressTween:Play()
    progressDetail.Text = snapshot.Complete and string.format("다음 공사까지 %d초 · 전망대에 올라가 보세요", math.max(0, snapshot.ResetIn or 0))
        or string.format("다음 층까지  %d / %d개    ·    %.1f%% 완성", snapshot.StageProgress, snapshot.StageCost, ratio * 100)
    saveLabel.Text = RunService:IsStudio() and "Studio 테스트 · 종료하면 초기화됩니다"
        or (snapshot.Saved and "진행 상황 자동 저장 · 개인 기록 유지" or "이번 세션 진행 중 · 저장 연결 대기")
    for kind, row in pairs(upgradeRows) do
        local level = snapshot[kind] or 0
        local maxed = level >= Config.MaxUpgradeLevel
        local cost = Config.UpgradeCost(kind, level)
        row.Level.Text = string.format("Lv.%d", level)
        row.Description.Text = maxed and "최고 단계에 도달했어요" or descriptions[kind](level)
        row.Buy.Text = maxed and "최고 단계" or number(cost) .. " 코인"
        row.Buy.Active = not maxed
        row.Buy.AutoButtonColor = not maxed
        row.Buy.BackgroundColor3 = not maxed and snapshot.Coins >= cost and C.Yellow or C.Line
        row.Buy.TextColor3 = C.Navy
    end
    celebration.Visible = snapshot.Complete and dismissedRound ~= snapshot.Round
    celebrateCountdown.Text = string.format("%d초 후 새로운 공사가 시작됩니다", math.max(0, snapshot.ResetIn or 0))
    if snapshot.Complete and lastConfettiRound ~= snapshot.Round then
        lastConfettiRound = snapshot.Round
        confetti()
    end
    updateAction()
end

stateEvent.OnClientEvent:Connect(function(kind, payload)
    if kind == "Snapshot" then
        render(payload)
    elseif kind == "Toast" then
        if type(payload) == "table" then toast(payload.Text or "", payload.Kind) end
    elseif kind == "Complete" then
        if type(payload) == "table" and payload.Reward then
            toast("완공 보상 +" .. number(payload.Reward) .. " 코인!", "success")
        end
    elseif kind == "OpenShop" then
        openShop(type(payload) == "table" and payload.Kind or nil)
    end
end)

-- E belongs to Roblox ProximityPrompt. Binding it here would charge/build twice.
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.B then
        if shop.Visible then shop.Visible = false else openShop() end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        shop.Visible = false
    end
end)

local function layout()
    local viewport = host.AbsoluteSize
    if viewport.X <= 0 or viewport.Y <= 0 then return end
    local factor = viewport.X < 600 and 1 or math.clamp(math.min(viewport.X / 1080, viewport.Y / 760), 0.72, 1)
    local w, h = viewport.X / factor, viewport.Y / factor
    scale.Scale = factor
    root.Size = UDim2.fromOffset(w, h)
    local narrow = viewport.X < 960
    local compactLandscape = UserInputService.TouchEnabled and viewport.Y < 570 and viewport.X > viewport.Y
    local inset = GuiService:GetGuiInset()
    local safeTop = math.max(inset.Y, 58) / factor
    local top = narrow and safeTop + 5 or 8 / factor
    local progressWidth = narrow and math.min(440, w - 28) or 410
    if compactLandscape then progressWidth = 350 end

    brand.Visible = not narrow
    brandTitle.TextSize = 29
    brand.Position = UDim2.fromOffset(22, safeTop + 10)
    progressTitle.TextSize = narrow and 15 or 17
    progressHeight.TextSize = narrow and 15 or 17
    progress.Size = UDim2.fromOffset(progressWidth, 82)
    progress.Position = UDim2.new(0.5, -progressWidth / 2, 0, top)
    progressTitle.Size = UDim2.new(1, -166, 0, 27)
    stageIcon.Visible = progressWidth >= 350
    progressTitle.Position = UDim2.fromOffset(progressWidth >= 350 and 57 or 17, 8)
    if progressWidth < 350 then progressTitle.Size = UDim2.new(1, -127, 0, 27) end

    local inventoryWidth = narrow and math.min(440, w - 28) or 224
    local toolLift = 76
    local inventoryTop = narrow and top + 94 or safeTop + 81
    stats.Size = UDim2.fromOffset(inventoryWidth, narrow and 68 or 150)
    -- Keep the stats in the lower-left corner, above touch controls and the
    -- centered action panel on narrow displays.
    local inventoryBottom = narrow and ((UserInputService.TouchEnabled and 116 or 25) + 115 + toolLift) or 40
    stats.Position = UDim2.new(0, narrow and 14 or 22, 1, -inventoryBottom)
    for i, key in ipairs(statKeys) do
        if narrow then
            statLabels[key].Size = UDim2.new(1 / 3, -18, 0, 21)
            statLabels[key].Position = UDim2.new((i - 1) / 3, 12, 0, 5)
            statLabels[key].TextSize = 12
            statValues[key].Size = UDim2.new(1 / 3, -18, 0, 31)
            statValues[key].Position = UDim2.new((i - 1) / 3, 12, 0, 27)
            statValues[key].TextXAlignment = Enum.TextXAlignment.Left
            statValues[key].TextSize = key == "Carry" and 18 or 23
        else
            statLabels[key].Size = UDim2.fromOffset(105, 40)
            statLabels[key].Position = UDim2.fromOffset(17, (i - 1) * 46 + 7)
            statLabels[key].TextSize = 13
            statValues[key].Size = UDim2.fromOffset(94, 40)
            statValues[key].Position = UDim2.new(1, -111, 0, (i - 1) * 46 + 7)
            statValues[key].TextXAlignment = Enum.TextXAlignment.Right
            statValues[key].TextSize = key == "Carry" and 19 or 24
        end
    end
    for _, divider in ipairs(statRules) do divider.Visible = not narrow end

    shopToggle.Size = UDim2.fromOffset(narrow and 128 or 170, 47)
    shopToggle.Position = narrow and UDim2.new(1, -142, 0, inventoryTop + 80) or UDim2.new(1, -192, 0, safeTop + 12)
    shopToggle.Text = UserInputService.TouchEnabled and "장비 꾸러미" or "장비 꾸러미 [B]"
    shopToggle.BackgroundColor3 = C.Peach
    returnButton.Size = UDim2.fromOffset(narrow and 128 or 170, 40)
    returnButton.Position = narrow and UDim2.new(1, -142, 0, inventoryTop + 137) or UDim2.new(1, -192, 0, safeTop + 69)
    returnButton.TextSize = 14
    returnButton.BackgroundColor3 = C.Blue

    tutorial.Size = UDim2.fromOffset(narrow and math.max(160, w - 170) or 224, narrow and 76 or 133)
    tutorial.Position = UDim2.fromOffset(narrow and 14 or 22, narrow and inventoryTop + 80 or inventoryTop + 164)
    tutorial.BackgroundColor3 = Color3.fromRGB(255, 243, 206)
    local tutorialHeading = tutorial:FindFirstChild("Heading")
    tutorialHeading.TextSize = narrow and 12 or 14
    tutorialHeading.Text = narrow and "처음이라면?" or "작은 건축가의 첫걸음"
    tutorialBody.Position = UDim2.fromOffset(15, narrow and 35 or 41)
    tutorialBody.Size = UDim2.new(1, -30, 0, narrow and 34 or 82)
    tutorialBody.TextSize = narrow and 11 or 13
    tutorialBody.Text = narrow and "창고에서 자재 받기\n공사장에 차곡차곡 쌓기!" or "①  자재 창고에서 등에 차곡차곡\n②  공사장에 내려놓으면 쑥쑥!\n③  코인으로 더 많이 운반해요"

    local taskWidth = math.min(430, w - 28)
    local hotbarBottom = UserInputService.TouchEnabled and 108 or 25
    local hotbarWidth = math.min(340, w - 28)
    hotbarFrame.Size = UDim2.fromOffset(hotbarWidth, 60)
    hotbarFrame.Position = UDim2.new(.5, -hotbarWidth / 2, 1, -hotbarBottom - 60)
    local bottom = hotbarBottom + toolLift
    objective.Size = UDim2.fromOffset(taskWidth, 103)
    objective.Position = UDim2.new(0.5, -taskWidth / 2, 1, -103 - bottom)
    objectiveLabel.TextSize = narrow and 13 or 15
    local toastWidth = math.min(400, w - 28)
    toastHost.Size = UDim2.fromOffset(toastWidth, 224)
    toastHost.Position = UDim2.new(0.5, -toastWidth / 2, 0, narrow and inventoryTop + 167 or 105)
    local shopWidth = math.min(382, w - 28)
    shop.Size = UDim2.fromOffset(shopWidth, 398)
    shop.Position = narrow and UDim2.new(0.5, -shopWidth / 2, 0.5, -170) or UDim2.new(1, -shopWidth - 22, 0.5, -146)
    local celebrationWidth = math.min(470, w - 28)
    celebration.Size = UDim2.fromOffset(celebrationWidth, 204)
    celebration.Position = UDim2.new(0.5, -celebrationWidth / 2, 0.5, -102)
    celebrateTitle.TextSize = narrow and 22 or 27
    saveLabel.Position = UDim2.new(0, 18, 1, -22)
    if compactLandscape then
        tutorial.Visible = false
        stats.Position = UDim2.new(0, 14, 1, -144)
        stats.Size = UDim2.fromOffset(242, 68)
        shopToggle.Position = UDim2.new(1, -150, 0, safeTop + 12)
        returnButton.Position = UDim2.new(1, -150, 0, safeTop + 70)
        local compactTaskWidth = math.min(taskWidth, w - 284)
        objective.Size = UDim2.fromOffset(compactTaskWidth, 103)
        objective.Position = UDim2.new(1, -compactTaskWidth - 14, 1, -192)
        hotbarFrame.Position = UDim2.new(.5, -hotbarWidth / 2, 1, -80)
        toastHost.Position = UDim2.new(0.5, -toastWidth / 2, 0, top + 94)
        shop.Position = UDim2.new(1, -shopWidth - 14, 0.5, -180)
    end
end

host:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
player:GetAttributeChangedSignal("HasPrankTools"):Connect(layout)
layout()

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.18 then return end
    elapsed = 0
    hotbar:Refresh()
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local found, bestDistance = nil, Config.InteractionDistance
    if hrp then
        for key, position in pairs(Config.Positions) do
            if key ~= "Spawn" then
                local distance = (hrp.Position - position).Magnitude
                if distance < bestDistance then found, bestDistance = key, distance end
            end
        end
        local onLowDeck = math.abs(hrp.Position.X) < 9 and hrp.Position.Z < 0 and hrp.Position.Z > -16 and hrp.Position.Y > 10
        returnButton.Visible = hrp.Position.Y > 65 or onLowDeck
    else
        returnButton.Visible = false
    end
    if nearest ~= found or player:GetAttribute("StealingUntil") then nearest = found; updateAction() end
end)

local function setInitialCamera(character)
    local humanoid = character:WaitForChild("Humanoid", 8)
    local hrp = character:WaitForChild("HumanoidRootPart", 8)
    if not humanoid or not hrp then return end
    task.wait(0.15)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    camera.CameraSubject = humanoid
    camera.CameraType = Enum.CameraType.Custom
    camera.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(19, 15, 30), hrp.Position + Vector3.new(-5, 5, -14))
end
player.CharacterAdded:Connect(function(character) task.spawn(setInitialCamera, character) end)
if player.Character then task.spawn(setInitialCamera, player.Character) end

task.spawn(function()
    for attempt = 1, 5 do
        local ok, data = pcall(function() return getState:InvokeServer() end)
        if ok and type(data) == "table" then
            render(data)
            print("BURJ_CLIENT_READY")
            return
        end
        task.wait(attempt)
    end
    toast("서버 연결이 지연되고 있어요. 잠시 기다려 주세요.", "info")
end)
