--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Bottom hotbar (1..MaxHotbarSlots). Static: all slots visible, holes
	allowed. Dynamic: occupied slots pack left, empty slots hidden, keybinds
	follow the packed position.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local ClientStore = require(script.Parent.Parent.Core.ClientStore)
local SlotView = require(script.Parent.Parent.Slot.SlotView)

local HotbarView = {}

-----------------------------
-- TYPES --
-----------------------------

type Skin = {
	HotbarFrame: Frame?,
	SlotTemplate: Frame?,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function HotbarView.Create(scope: Fusion.Scope, skin: Skin, store: typeof(ClientStore))
	if not skin.HotbarFrame then
		warn("[StowayClientV3] HotbarView: missing Hotbar frame")
		return
	end
	if not skin.SlotTemplate then
		warn("[StowayClientV3] HotbarView: missing slot template")
		return
	end

	local isDynamic = scope:Computed(function(use)
		local settings = use(store.Settings)
		return settings ~= nil and settings.HotbarType == "Dynamic"
	end)

	local slotKeys = scope:Computed(function(use)
		local settings = use(store.Settings)
		local maxSlots = settings and settings.MaxHotbarSlots or 10
		local keys: { [number]: boolean } = {}
		for i = 1, maxSlots do
			keys[i] = true
		end
		return keys
	end)

	scope:ForPairs(slotKeys, function(use, slotScope, slotIndex)
		-- Packed visible index: occupied slots left-to-right, empties off the end.
		local packOrder = slotScope:Computed(function(use)
			if not use(isDynamic) then
				return slotIndex
			end
			local hotbar = use(store.Hotbar)
			local items = use(store.Items)
			local visible = 0
			for i = 1, slotIndex do
				local uuid = hotbar[i]
				if uuid and items[uuid] then
					visible += 1
				end
			end
			if visible == 0 then
				return 1000 + slotIndex
			end
			return visible
		end)

		local keybind = slotScope:Computed(function(use)
			return tostring(use(packOrder))
		end)

		local visibility = slotScope:Computed(function(use)
			if not use(isDynamic) then
				return true
			end
			local hotbar = use(store.Hotbar)
			local items = use(store.Items)
			local uuid = hotbar[slotIndex]
			return uuid ~= nil and items[uuid] ~= nil
		end)

		SlotView.Create(slotScope, {
			SlotType = "Hotbar",
			SlotIndex = slotIndex,
			Parent = skin.HotbarFrame,
			Template = skin.SlotTemplate,
			ShowKeybind = true,
			PackOrder = packOrder,
			Keybind = keybind,
			Visibility = visibility,
		})
	end)
end

-----------------------------
-- MAIN --
-----------------------------

return HotbarView