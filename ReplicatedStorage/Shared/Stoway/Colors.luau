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

-- Team ring colors for Jailbreak-style layouts. Slot tint reads
-- Metadata.Team (case-insensitive, "Cop"/"Prison" accepted as aliases).
Colors.TeamColors = {
	Criminal = Color3.fromRGB(220, 70, 60),
	Prisoner = Color3.fromRGB(235, 150, 50),
	Police = Color3.fromRGB(70, 130, 235),
}

-- Ascending rank for Settings.SortOrder == "Rarity". Unknown/nil rarities
-- rank 0, sorting after every known tier.
Colors.RarityOrder = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Special = 7,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

local function normalizeRarity(rarity: string): string
	return rarity:sub(1, 1):upper() .. rarity:sub(2):lower()
end

function Colors.getRarityColor(rarity: string?): Color3
	local key = if rarity then normalizeRarity(rarity) else nil
	return Colors.RarityColors[key] or Color3.fromRGB(80, 80, 80)
end

function Colors.getRarityRank(rarity: string?): number
	if not rarity then
		return 0
	end
	return Colors.RarityOrder[normalizeRarity(rarity)] or 0
end

function Colors.getTypeColor(itemType: string?): Color3
	-- Neutral fallback; StorageView prefers Settings.Categories colors.
	return Color3.fromRGB(100, 100, 110)
end

local TeamAliases: { [string]: string } = {
	criminal = "Criminal",
	prison = "Prisoner",
	prisoner = "Prisoner",
	cop = "Police",
	police = "Police",
}

function Colors.getTeamColor(team: string?): Color3
	if not team then
		return Color3.fromRGB(80, 80, 80)
	end
	local key = TeamAliases[string.lower(team)] or (team:sub(1, 1):upper() .. team:sub(2):lower())
	return Colors.TeamColors[key] or Color3.fromRGB(80, 80, 80)
end

-----------------------------
-- MAIN --
-----------------------------

return Colors
