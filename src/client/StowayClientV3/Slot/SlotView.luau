--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Hydrates one slot frame cloned from the skin's Slot/template: item image,
	stack count (CanStack-aware), rarity frame color, equipped indicator,
	hotbar keybinds, and Dynamic hotbar packing.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local SharedTypes = require(ReplicatedStorage.Shared.Stoway.Types)
local Colors = require(ReplicatedStorage.Shared.Stoway.Colors)
local ClientStore = require(script.Parent.Parent.Core.ClientStore)

local SlotView = {}

-----------------------------
-- TYPES --
-----------------------------

export type SlotProps = {
	SlotType: SharedTypes.SlotType,
	SlotIndex: number,
	Parent: Instance,
	Template: Frame,
	KeybindText: string?,
	ShowKeybind: boolean?,
	PackOrder: Fusion.Computed<number>?,
	Keybind: Fusion.Computed<string>?,
	Visibility: Fusion.Computed<boolean>?,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function SlotView.Create(scope: Fusion.Scope, props: SlotProps): Frame
	local slotFrame = props.Template:Clone()
	slotFrame.Name = props.SlotType .. "-" .. tostring(props.SlotIndex)
	slotFrame.Parent = props.Parent

	local slotbutton = slotFrame:FindFirstChild("slotbutton")
	local stackcount = slotFrame:FindFirstChild("stackcount")
	local slotnumber = slotFrame:FindFirstChild("slotnumber")
	local selecticon = slotFrame:FindFirstChild("selecticon")
	local rarityframe = slotFrame:FindFirstChild("rarityframe")

	local slotUUID = scope:Computed(function(use)
		if props.SlotType == "Hotbar" then
			return use(ClientStore.Hotbar)[props.SlotIndex]
		end
		return use(ClientStore.Storage)[props.SlotIndex]
	end)

	local currentItem = scope:Computed(function(use)
		local uuid = use(slotUUID)
		if not uuid then
			return nil
		end
		return use(ClientStore.Items)[uuid]
	end)

	local hasItem = scope:Computed(function(use)
		return use(currentItem) ~= nil
	end)

	local isEquipped = scope:Computed(function(use)
		local equipped = use(ClientStore.EquippedItemUUID)
		local uuid = use(slotUUID)
		return equipped ~= nil and uuid ~= nil and equipped == uuid
	end)

	if slotbutton then
		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use)
				local item = use(currentItem)
				local metadata = item and item.Metadata
				return if metadata then metadata.Image or "" else ""
			end),
			Visible = hasItem,
		}
	end

	if rarityframe then
		scope:Hydrate(rarityframe) {
			ImageColor3 = scope:Computed(function(use)
				local item = use(currentItem)
				return Colors.getRarityColor(item and item.Metadata.Rarity)
			end),
			Visible = hasItem,
		}
	end

	if stackcount then
		scope:Hydrate(stackcount) {
			Visible = scope:Computed(function(use)
				local item = use(currentItem)
				local settings = use(ClientStore.Settings)
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
			Text = props.Keybind or props.KeybindText or "",
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