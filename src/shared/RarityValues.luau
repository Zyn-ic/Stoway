local rarities = {}

rarities.rarityColors = {
    ["godly"] = Color3.new(0.933333, 0.92549, 0.435294),
    ["lengendary"] = Color3.new(0.639216, 0.278431, 0.278431),
    ["rare"] = Color3.new(0.372549, 0.607843, 0.721569),
    ["uncommon"] = Color3.new(0.588235, 0.72549, 0.509804),
    ["common"] = Color3.new(0.4, 0.4, 0.4);
}

rarities.RaritySortOrder = {
    ["godly"] = 1,
    ["legendary"] = 2,
    ["rare"] = 3,
    ["uncommon"] = 4,
    ["common"] = 5
}

rarities.ItemTypeColor = {
    ["consumable"] = Color3.fromRGB(169, 169, 169),
    ["weapon"] = Color3.fromRGB(115,147,179),
    ["material"] = Color3.fromRGB(255,255,255)
}

-- Same concept for ItemType
rarities.ItemTypeSortOrder = {
    ["weapon"] = 1,
    ["consumable"] = 2,
    ["resource"] = 3
}

return rarities
