--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StandardHotbarStorage HotbarType layout engine: a fixed 1..MaxHotbarSlots
	bottom hotbar (Static holes / Dynamic packed) plus Storage grouped
	visually by item Type with collapsible group headers. This is the
	Milestone 1 deliverable from the master plan (sections 4 and 5, Phase 4).

	A layout engine's contract is just Mount(scope, skin, store) — how it
	renders internally is entirely up to it. CarouselHotbar and UtilityBelt
	(Phase 5/6) will each get their own sibling folder here with their own
	Mount, reusing Slot/SlotView.luau and the same Controller/CoreStore
	layers untouched.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)

local HotbarView = require(script.HotbarView)
local StorageView = require(script.StorageView)

local StandardHotbarStorage = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StandardHotbarStorage.Mount(scope: Fusion.Scope<any>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	HotbarView.Create(scope, skin, store)
	StorageView.Create(scope, skin, store)
end

-----------------------------
-- MAIN --
-----------------------------

return StandardHotbarStorage
