--!strict

--@author: yyumchi
--@date: 2026-09-16
--[[@description:
	Metal skin entry. Delegates loading to the generic skin loader, then
	stamps Metal-only look data. Views consume GlowSpread generically
	and fall back to the shared default, so other skins are unaffected.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local SkinLoader = require(script.Parent.SkinLoader)
local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local Metal = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Metal.Load(scope: Fusion.Scope<typeof(Fusion)>, playerGui: PlayerGui, skinAssetName: string): CoreTypes.SkinHandle?
	local handle = SkinLoader.Load(scope, playerGui, skinAssetName)
	if handle then
		-- Wider halo to match Metal's larger art bleed / deco overhang.
		handle.GlowSpread = UDim2.new(0.5, 0, 0.5, 0)
	end
	return handle
end

-----------------------------
-- MAIN --
-----------------------------

return Metal
