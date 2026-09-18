--!strict

--@author: yyumchi
--@date: 2026-09-16
--[[@description:
	Modern skin entry. Delegates loading to the generic skin loader, then
	stamps Modern-only look data (dark metal header colors) onto the
	handle. Views consume HeaderColors generically and fall back to
	category colors when absent, so other skins are unaffected.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local SkinLoader = require(script.Parent.SkinLoader)

local Modern = {}

-----------------------------
-- CONSTANTS --
-----------------------------

-- Saturated jewel tones: deliberately far from the muted category hues,
-- built to pop against the charcoal slot chrome. Keyed by item Type.
local HEADER_COLORS: { [string]: Color3 } = {
	Weapon = Color3.fromRGB(170, 50, 60),
	Consumable = Color3.fromRGB(40, 160, 110),
	Material = Color3.fromRGB(200, 150, 50),
	Armor = Color3.fromRGB(60, 110, 220),
	Trinket = Color3.fromRGB(150, 90, 220),
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Modern.Load(scope: Fusion.Scope<typeof(Fusion)>, playerGui: PlayerGui, skinAssetName: string): CoreTypes.SkinHandle?
	local handle = SkinLoader.Load(scope, playerGui, skinAssetName)
	if handle then
		handle.HeaderColors = HEADER_COLORS
		-- Slight left bias on desktop (shared default is 0.57).
		handle.DesktopHotbarXScale = 0.52
	end
	return handle
end

-----------------------------
-- MAIN --
-----------------------------

return Modern
