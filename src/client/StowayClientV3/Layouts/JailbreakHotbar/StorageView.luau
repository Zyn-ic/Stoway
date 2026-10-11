--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Centered storage popup, default-Roblox-backpack style. Flat grid in
	index order (no sections/search/sort): tap a slot to equip. Visible
	only while the layout-local storageOpen flag is set (toggled by
	Input via the BackpackStuff button or backpack keybind).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local SlotView = require(script.Parent.Parent.Parent.Slot.SlotView)
local CooldownService = require(script.Parent.Parent.Parent.Interactions.CooldownService)
local PointerDragService = require(script.Parent.Parent.Parent.Interactions.PointerDragService)

local StorageView = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local CELL_SIZE = 56
local CELL_PADDING = 8

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StorageView.Create(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	storageOpen: Fusion.Value<boolean>,
	dragService: PointerDragService.Service?
)
	if not skin.BackpackFrame then
		warn("[JailbreakHotbar] StorageView: skin has no Backpack frame")
		return
	end
	local backpackFrame = skin.BackpackFrame

	scope:Hydrate(backpackFrame) {
		Visible = scope:Computed(function(use: Fusion.Use): boolean
			if not use(storageOpen) then return false end
			local settings: CoreTypes.Settings? = use(store.Settings)
			return settings == nil or settings.BackpackEnabled ~= false
		end),
	}

	if skin.WeightLabel then
		local weightLabel = skin.WeightLabel
		scope:Hydrate(weightLabel) {
			Text = scope:Computed(function(use: Fusion.Use): string
				local settings: CoreTypes.Settings? = use(store.Settings)
				local weight: number = use(store.Weight)
				return Query.formatWeight(weight, if settings then settings.Limit else 0)
			end),
		}
	end

	if not skin.ScrollingFrame or not skin.SlotTemplate then
		warn("[JailbreakHotbar] StorageView: skin missing ScrollingFrame or Slot template")
		return
	end
	local scrollingFrame = skin.ScrollingFrame
	local slotTemplate = skin.SlotTemplate

	local bleed: number = skin.SlotBleedPx or 0

	scope:New("UIGridLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.fromOffset(CELL_SIZE, CELL_SIZE),
		CellPadding = UDim2.fromOffset(CELL_PADDING + bleed * 2, CELL_PADDING + bleed * 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = scrollingFrame,
	}

	local cellSizeUDim = UDim2.fromOffset(CELL_SIZE, CELL_SIZE)

	-- Flat index-order records, Roblox-backpack style.
	local records = scope:Computed(function(use: Fusion.Use): { CoreTypes.ItemRecord }
		local storage: { string } = use(store.Storage)
		local list: { CoreTypes.ItemRecord } = {}
		for index, uuid in storage do
			table.insert(list, { index = index, uuid = uuid })
		end
		return list
	end)

	local storageFor = scope:ForPairs(records, function(_use, slotScope: Fusion.Scope<typeof(Fusion)>, listPosition: number, record: CoreTypes.ItemRecord)
		local slotFrame = SlotView.Create(slotScope, {
			SlotType = "Storage",
			SlotIndex = record.index,
			Parent = scrollingFrame,
			Template = slotTemplate,
			Store = store,
			ShowKeybind = false,
			HideChrome = skin.HideInStorage,
		})
		local orderState = slotScope:Computed(function(): number
			return listPosition
		end)
		slotScope:Hydrate(slotFrame) {
			LayoutOrder = orderState,
			Size = cellSizeUDim,
		}

		-- Scale punch target for the swap-pop. UIScale never fights the
		-- Size binding above.
		slotScope:New("UIScale") {
			Scale = 1,
			Parent = slotFrame,
		}

		-- Cooldown veil + countdown, derived from the shared Tick clock.
		local slotUUID = slotScope:Computed(function(): string?
			return record.uuid
		end)
		local coolingLeft = slotScope:Computed(function(use: Fusion.Use): number
			use(CooldownService.Tick)
			local uuid: string? = use(slotUUID)
			if not uuid then return 0 end
			return CooldownService.Remaining(uuid)
		end)
		local coolingFrac = slotScope:Computed(function(use: Fusion.Use): number
			local left: number = use(coolingLeft)
			if left <= 0 then return 0 end
			local items: { [string]: CoreTypes.Item } = use(store.Items)
			local uuid: string? = use(slotUUID)
			local item: CoreTypes.Item? = if uuid then items[uuid] else nil
			local dur = 0
			if item and item.Metadata then
				local raw = item.Metadata.Cooldown
				if typeof(raw) == "number" and raw > 0 then dur = raw end
			end
			if dur <= 0 then return 0 end
			return math.clamp(left / dur, 0, 1)
		end)
		local isCooling = slotScope:Computed(function(use: Fusion.Use): boolean
			return use(coolingLeft) > 0
		end)
		local veil = slotFrame:FindFirstChild("cooldown") :: Frame?
		if veil then
			slotScope:Hydrate(veil) {
				Visible = isCooling,
				BackgroundTransparency = slotScope:Computed(function(use: Fusion.Use): number
					return 0.75 - 0.45 * use(coolingFrac)
				end),
			}
		end
		local veilText = slotFrame:FindFirstChild("cooldowntext") :: TextLabel?
		if veilText then
			slotScope:Hydrate(veilText) {
				Visible = isCooling,
				Text = slotScope:Computed(function(use: Fusion.Use): string
					return tostring(math.ceil(use(coolingLeft)))
				end),
			}
		end

		-- White equip ring, same as the hotbar: storage equips are real,
		-- they just had no witness (the popup covers the character).
		local isEquipped = slotScope:Computed(function(use: Fusion.Use): boolean
			local storage: { string } = use(store.Storage)
			local equipped: string? = use(store.EquippedItemUUID)
			return Query.isEquipped(equipped, storage[record.index])
		end)
		local btn = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
		if btn ~= nil then
			local ring = slotScope:New("UIStroke") {
				Thickness = 3,
				Color = Color3.new(1, 1, 1),
				Transparency = 0.15,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = btn,
			} :: UIStroke
			slotScope:Hydrate(ring) {
				Enabled = isEquipped,
			}
		end

		-- Sweep source + target: popup slots paint both ways.
		if dragService ~= nil then
			local slotRef: CoreTypes.SlotRef = { Type = "Storage", Slot = record.index }
			local handle = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
			if handle ~= nil then dragService:RegisterDraggable(slotScope, handle, slotRef) end
			dragService:RegisterDropTarget(slotScope, slotFrame, slotRef)
		end

		return record.index, record
	end)
	Fusion.peek(storageFor)
	scope:Observer(storageFor)
end

-----------------------------
-- MAIN --
-----------------------------

return StorageView
