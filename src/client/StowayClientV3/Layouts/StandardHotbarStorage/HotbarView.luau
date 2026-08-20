--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Bottom hotbar (1..MaxHotbarSlots). Static: fixed positions, holes shown
	as empty slots. Dynamic: occupied slots pack left (visible order from
	CoreStore.Query.packedHotbarOrder), empty slots hidden, keybind label
	follows the packed position rather than the raw slot index.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)
local State = require(script.Parent.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local SlotView = require(script.Parent.Parent.Parent.Slot.SlotView)

local HotbarView = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function HotbarView.Create(scope: Fusion.Scope<any>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	if not skin.HotbarFrame then
		warn("[StandardHotbarStorage] HotbarView: skin has no Hotbar frame")
		return
	end
	if not skin.SlotTemplate then
		warn("[StandardHotbarStorage] HotbarView: skin has no Slot template")
		return
	end
	local hotbarFrame = skin.HotbarFrame
	local slotTemplate = skin.SlotTemplate

	local isDynamic = scope:Computed(function(use)
		return Query.isDynamicHotbar(use(store.Settings))
	end)

	local slotIndices = scope:Computed(function(use)
		return State.slotIndices(State.getMaxHotbarSlots(use(store.Settings)))
	end)

	scope:ForPairs(slotIndices, function(use, slotScope, slotIndex)
		local packOrder = slotScope:Computed(function(use)
			return Query.packedHotbarOrder(use(store.Hotbar), use(store.Items), slotIndex, use(isDynamic))
		end)

		local keybind = slotScope:Computed(function(use)
			return tostring(use(packOrder))
		end)

		local visibility = slotScope:Computed(function(use)
			return Query.isHotbarSlotVisible(use(store.Hotbar), use(store.Items), slotIndex, use(isDynamic))
		end)

		SlotView.Create(slotScope, {
			SlotType = "Hotbar",
			SlotIndex = slotIndex,
			Parent = hotbarFrame,
			Template = slotTemplate,
			Store = store,
			ShowKeybind = true,
			PackOrder = packOrder,
			Keybind = keybind,
			Visibility = visibility,
		})

		return slotIndex, true
	end)
end

-----------------------------
-- MAIN --
-----------------------------

return HotbarView
