--!strict

--@author: yyumchi
--@date: 2026-09-16
--[[@description:
	Metal skin entry. Delegates loading to the generic skin loader.
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
	return SkinLoader.Load(scope, playerGui, skinAssetName)
end

-----------------------------
-- MAIN --
-----------------------------

return Metal
