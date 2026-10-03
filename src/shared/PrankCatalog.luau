-- Build the Burj! universe 10768093665 / start place 87004379130048.
-- Each developer product costs 20 Robux; managed/regional pricing is disabled.
local Catalog = {
    Order = {"Slap", "Bat", "Banana"},
    Items = {
        Slap = {Name = "뺨때리기", Icon = "✋", Price = 20, ProductId = 3714815891, Range = 7,
            Description = "앞에 있는 친구에게 찰싹!\n명중하면 자재가 우수수 · 1회"},
        Bat = {Name = "빠따", Icon = "★", Price = 20, ProductId = 3714815912, Range = 9,
            Description = "말랑 빠따로 통!\n명중하면 자재가 우수수 · 1회"},
        Banana = {Name = "바나나", Icon = "🍌", Price = 20, ProductId = 3714815935,
            Description = "바닥에 껍질을 쏙!\n밟으면 미끌, 자재 우수수 · 1회"},
    },
}
return Catalog
