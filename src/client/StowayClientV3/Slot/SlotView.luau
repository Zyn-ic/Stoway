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

-- Wrappers hide Fusion's unannotated generics from the new solver.
-- Call sites stay strictly typed via the left-hand annotation.
local function useTyped(useFn: Fusion.Use, target: any): any
	return (useFn :: any)(target)
end

local function peekValue(target: any): any
	return (Fusion.peek :: any)(target)
end

-----------------------------
-- TYPES --
-----------------------------

export type DragLike = {
	IsDragging: (self: DragLike) -> boolean,
	WasRecentlyDragging: (self: DragLike, number?) -> boolean,
}

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
	DragService: DragLike?,
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

	local hotbarSlotUUID = scope:Computed(function(use: Fusion.Use): string?
		local hotbar: { [number]: string? } = useTyped(use, store.Hotbar)
		return Query.getHotbarUUID(hotbar, props.SlotIndex)
	end)

	local storageSlotUUID = scope:Computed(function(use: Fusion.Use): string?
		local storage: { string } = useTyped(use, store.Storage)
		return Query.getStorageUUID(storage, props.SlotIndex)
	end)

	local slotUUID = scope:Computed(function(use: Fusion.Use): string?
		if props.SlotType == "Hotbar" then
			return useTyped(use, hotbarSlotUUID)
		end
		return useTyped(use, storageSlotUUID)
	end)

	local currentItem = scope:Computed(function(use: Fusion.Use): CoreTypes.Item?
		local items: { [string]: CoreTypes.Item } = useTyped(use, store.Items)
		local uuid: string? = useTyped(use, slotUUID)
		return Query.getItem(items, uuid)
	end)

	local hasItem = scope:Computed(function(use: Fusion.Use): boolean
		return useTyped(use, currentItem) ~= nil
	end)

	local isEquipped = scope:Computed(function(use: Fusion.Use): boolean
		local uuid: string? = useTyped(use, slotUUID)
		local equipped: string? = useTyped(use, store.EquippedItemUUID)
		return Query.isEquipped(equipped, uuid)
	end)

	local hasImage = scope:Computed(function(use: Fusion.Use): boolean
		local item: CoreTypes.Item? = useTyped(use, currentItem)
		return item ~= nil and item.Metadata ~= nil and item.Metadata.Image ~= nil and item.Metadata.Image ~= ""
	end)

	local fallbackText = scope:Computed(function(use: Fusion.Use): string
		local item: CoreTypes.Item? = useTyped(use, currentItem)
		if not item then return "" end
		local id = item.Id or "?"
		if #id > 12 then return string.sub(id, 1, 10) .. ".." end
		return id
	end)

	if slotbutton then
		local fallbackLabel = scope:New("TextLabel") {
			Name = "fallbacklabel",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.72),
			ZIndex = 2,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.2,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			Parent = slotbutton,
		}
		scope:New("UITextSizeConstraint") {
			MaxTextSize = 18,
			MinTextSize = 7,
			Parent = fallbackLabel,
		}
		scope:New("UIPadding") {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = fallbackLabel,
		}

		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use: Fusion.Use): string
				local item: CoreTypes.Item? = useTyped(use, currentItem)
				return if item and item.Metadata then item.Metadata.Image or "" else ""
			end),
			ImageTransparency = scope:Computed(function(use: Fusion.Use): number
				return if useTyped(use, hasImage) then 0 else 1
			end),
			Visible = hasItem,
		}

		scope:Hydrate(fallbackLabel) {
			Text = fallbackText,
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				return useTyped(use, hasItem) and not useTyped(use, hasImage)
			end),
			TextColor3 = scope:Computed(function(use: Fusion.Use): Color3
				local item: CoreTypes.Item? = useTyped(use, currentItem)
				-- Use rarity tint for fallback text so color-blind still has Id, but hue helps
				return Colors.getRarityColor(item and item.Metadata and item.Metadata.Rarity)
			end),
		}

		-- Tap/Activated to equip (covers Mouse, Touch, and Gamepad ButtonA via
		-- GuiService.SelectedObject + Activated). Guard against firing right
		-- after a drag so a drag-release doesn't also equip.
		local dragService = props.DragService
		table.insert(
			scope,
			slotbutton.Activated:Connect(function()
				if dragService ~= nil then
					if dragService:IsDragging() then return end
					if dragService:WasRecentlyDragging(0.25) then return end
				end
				local uuid: string? = peekValue(slotUUID)
				if not uuid then return end
				local has: boolean = peekValue(hasItem)
				if not has then return end
				local equipped: string? = peekValue(store.EquippedItemUUID)
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
				local item: CoreTypes.Item? = useTyped(use, currentItem)
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
				local item: CoreTypes.Item? = useTyped(use, currentItem)
				local settings: CoreTypes.Settings? = useTyped(use, store.Settings)
				return settings ~= nil and settings.CanStack and item ~= nil
			end),
			Text = scope:Computed(function(use: Fusion.Use): string
				local item: CoreTypes.Item? = useTyped(use, currentItem)
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
