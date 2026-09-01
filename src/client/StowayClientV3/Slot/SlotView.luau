--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Hydrates a slot frame from the skin template. Handles icon, stack
	count, rarity color, equipped state and keybind. Used by all layouts.
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
local ClientController = require(script.Parent.Parent.Controller.ClientController)

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

function SlotView.Create(scope: Fusion.Scope<typeof(Fusion)>, props: SlotProps): Frame
	local slotFrame = props.Template:Clone()
	slotFrame.Name = props.SlotType .. "-" .. tostring(props.SlotIndex)
	slotFrame.Parent = props.Parent
	table.insert(scope, slotFrame)

	local store = props.Store

	local slotbutton = slotFrame:FindFirstChild("slotbutton") :: ImageButton?
	local stackcount = slotFrame:FindFirstChild("stackcount") :: TextLabel?
	local slotnumber = slotFrame:FindFirstChild("slotnumber") :: TextLabel?
	local selecticon = slotFrame:FindFirstChild("selecticon") :: GuiObject?
	local rarityframe = slotFrame:FindFirstChild("rarityframe") :: ImageLabel?

	local hotbarSlotUUID = scope:Computed(function(use: Fusion.Use)
		return Query.getHotbarUUID(use(store.Hotbar), props.SlotIndex)
	end)

	local storageSlotUUID = scope:Computed(function(use: Fusion.Use)
		return Query.getStorageUUID(use(store.Storage), props.SlotIndex)
	end)

	local slotUUID = scope:Computed(function(use: Fusion.Use)
		if props.SlotType == "Hotbar" then
			return use(hotbarSlotUUID)
		end
		return use(storageSlotUUID)
	end)

	local currentItem = scope:Computed(function(use: Fusion.Use)
		return Query.getItem(use(store.Items) :: { [string]: CoreTypes.Item }, use(slotUUID) :: string?)
	end)

	local hasItem = scope:Computed(function(use: Fusion.Use)
		return use(currentItem) ~= nil
	end)

	local isEquipped = scope:Computed(function(use: Fusion.Use)
		return Query.isEquipped(use(store.EquippedItemUUID), use(slotUUID))
	end)

	if slotbutton then
		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use: Fusion.Use): string
				local item = use(currentItem)
				return if item and item.Metadata then item.Metadata.Image or "" else ""
			end),
			Visible = hasItem,
		}

		-- Click to equip / unequip. Tracked by Fusion scope so ForPairs cleanup
		-- disconnects it (fixes master issue #2: connection leak per slot).
		table.insert(
			scope,
			slotbutton.MouseButton1Click:Connect(function()
				local uuid = Fusion.peek(slotUUID)
				if not uuid then return end
				if not Fusion.peek(hasItem) then return end
				local equipped = Fusion.peek(store.EquippedItemUUID)
				if equipped == uuid then
					ClientController.Unequip()
				else
					ClientController.Equip(uuid)
				end
			end)
		)
	end

	if rarityframe then
		scope:Hydrate(rarityframe) {
			ImageColor3 = scope:Computed(function(use: Fusion.Use): Color3
				local item = use(currentItem)
				return Colors.getRarityColor(item and item.Metadata and item.Metadata.Rarity)
			end),
			Visible = hasItem,
		}
	end

	if stackcount then
		-- Keep badge inside the cell and tilted for readability.
		if props.SlotType == "Storage" then
			stackcount.AnchorPoint = Vector2.new(1, 1)
			stackcount.Position = UDim2.new(1, -3, 1, -3)
			stackcount.Size = UDim2.fromOffset(30, 22)
			stackcount.ZIndex = 3
			stackcount.Rotation = -15
		elseif props.SlotType == "Hotbar" then
			stackcount.AnchorPoint = Vector2.new(1, 1)
			stackcount.Position = UDim2.new(1, -2, 1, -2)
			stackcount.Size = UDim2.fromOffset(32, 18)
			stackcount.ZIndex = 3
			stackcount.Rotation = -15
		else
			stackcount.Rotation = -15
		end
		scope:Hydrate(stackcount) {
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				local item = use(currentItem)
				local settings = use(store.Settings)
				return settings ~= nil and settings.CanStack and item ~= nil
			end),
			Text = scope:Computed(function(use: Fusion.Use): string
				local item = use(currentItem)
				if item then
					return Query.formatAmount(item.Amount)
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
