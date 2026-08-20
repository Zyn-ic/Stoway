--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Hydrates one slot Frame cloned from the skin's Slot template: item image,
	stack count (CanStack-aware), rarity frame color, equipped indicator, and
	an optional keybind label. Shared by every HotbarType layout engine —
	Carousel and Utility Belt (Phase 5/6) call this exact same module instead
	of duplicating slot-hydration logic per layout.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Colors = require(ReplicatedStorage.Shared.Stoway.Colors)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local Query = require(script.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)

local SlotView = {}

-----------------------------
-- TYPES --
-----------------------------

export type SlotProps = {
	SlotType: CoreTypes.SlotType,
	SlotIndex: number,
	Parent: Instance,
	Template: Frame,
	Store: typeof(ClientStore),
	ShowKeybind: boolean?,
	PackOrder: Fusion.Computed<number>?,
	Keybind: Fusion.Computed<string>?,
	Visibility: Fusion.Computed<boolean>?,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function SlotView.Create(scope: Fusion.Scope<any>, props: SlotProps): Frame
	local slotFrame = props.Template:Clone()
	slotFrame.Name = props.SlotType .. "-" .. tostring(props.SlotIndex)
	slotFrame.Parent = props.Parent
	-- Not built via scope:New, so it isn't auto-tracked — register it
	-- manually so this scope's doCleanup() destroys it too.
	table.insert(scope, slotFrame)

	local store = props.Store

	local slotbutton = slotFrame:FindFirstChild("slotbutton")
	local stackcount = slotFrame:FindFirstChild("stackcount")
	local slotnumber = slotFrame:FindFirstChild("slotnumber")
	local selecticon = slotFrame:FindFirstChild("selecticon")
	local rarityframe = slotFrame:FindFirstChild("rarityframe")

	local slotUUID = scope:Computed(function(use)
		if props.SlotType == "Hotbar" then
			return Query.getHotbarUUID(use(store.Hotbar), props.SlotIndex)
		end
		return Query.getStorageUUID(use(store.Storage), props.SlotIndex)
	end)

	local currentItem = scope:Computed(function(use)
		return Query.getItem(use(store.Items), use(slotUUID))
	end)

	local hasItem = scope:Computed(function(use)
		return use(currentItem) ~= nil
	end)

	local isEquipped = scope:Computed(function(use)
		return Query.isEquipped(use(store.EquippedItemUUID), use(slotUUID))
	end)

	if slotbutton then
		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use)
				local item = use(currentItem)
				return if item and item.Metadata then item.Metadata.Image or "" else ""
			end),
			Visible = hasItem,
		}
	end

	if rarityframe then
		scope:Hydrate(rarityframe) {
			ImageColor3 = scope:Computed(function(use)
				local item = use(currentItem)
				return Colors.getRarityColor(item and item.Metadata and item.Metadata.Rarity)
			end),
			Visible = hasItem,
		}
	end

	if stackcount then
		scope:Hydrate(stackcount) {
			Visible = scope:Computed(function(use)
				local item = use(currentItem)
				local settings = use(store.Settings)
				return settings ~= nil and settings.CanStack and item ~= nil and item.Amount > 1
			end),
			Text = scope:Computed(function(use)
				local item = use(currentItem)
				if item and item.Amount > 1 then
					return tostring(item.Amount) .. "x"
				end
				return ""
			end),
		}
	end

	if slotnumber then
		scope:Hydrate(slotnumber) {
			Text = props.Keybind or "",
			Visible = props.ShowKeybind == true,
		}
	end

	if selecticon then
		scope:Hydrate(selecticon) {
			Visible = isEquipped,
		}
	end

	if props.PackOrder then
		scope:Hydrate(slotFrame) {
			LayoutOrder = props.PackOrder,
		}
	else
		slotFrame.LayoutOrder = props.SlotIndex
	end

	if props.Visibility then
		scope:Hydrate(slotFrame) {
			Visible = props.Visibility,
		}
	end

	return slotFrame
end

-----------------------------
-- MAIN --
-----------------------------

return SlotView
