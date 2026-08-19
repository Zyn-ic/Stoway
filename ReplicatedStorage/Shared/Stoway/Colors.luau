--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Shared accent colors. Rarity colors drive slot rarity frames; group header
	colors live in Settings.Categories (this module stays dependency-free).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Colors = {}

-----------------------------
-- CONSTANTS --
-----------------------------

Colors.RarityColors = {
	Common = Color3.fromRGB(140, 140, 140),
	Uncommon = Color3.fromRGB(120, 170, 120),
	Rare = Color3.fromRGB(90, 130, 200),
	Epic = Color3.fromRGB(160, 100, 210),
	Legendary = Color3.fromRGB(230, 170, 60),
	Mythic = Color3.fromRGB(230, 80, 80),
	Special = Color3.fromRGB(240, 240, 240),
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Colors.getRarityColor(rarity: string?): Color3
	return Colors.RarityColors[rarity] or Color3.fromRGB(80, 80, 80)
end

function Colors.getTypeColor(itemType: string?): Color3
	-- Neutral fallback; StorageView prefers Settings.Categories colors.
	return Color3.fromRGB(100, 100, 110)
end

-----------------------------
-- MAIN --
-----------------------------

return Colors