--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Sectioned storage view. Buckets Storage by item type with collapsible
	headers; supports flat ungrouped mode and local search/sort.
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
local PointerDragService = require(script.Parent.Parent.Parent.Interactions.PointerDragService)

local StorageView = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local CELL_PADDING = 7
local HEADER_HEIGHT = 26
local FALLBACK_HEADER_COLOR = Color3.fromRGB(80, 80, 90)

-- Match hotbar sizing for uniform slots.
local SLOT_SIZE_MIN = 36
local SLOT_SIZE_MAX = 62
local REFERENCE_VIEWPORT_MIN = 390
local REFERENCE_VIEWPORT_MAX = 1440

-- Gap above hotbar, with small reclaim on phones.
local MOBILE_HOTBAR_GAP = 8
local DESKTOP_HOTBAR_GAP = 12
local HOTBAR_GAP_TAPER_START_WIDTH = 900
local HOTBAR_GAP_TAPER_END_WIDTH = 1300
local PHONE_RECLAIM_PX = 16

-- Reserve taper keeps thumbstick area on phones, tight gap on desktop.
local TAPER_START_WIDTH = 900
local TAPER_END_WIDTH = 1600

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function computeSlotSize(viewportWidth: number): number
	local t = if REFERENCE_VIEWPORT_MAX > REFERENCE_VIEWPORT_MIN
		then (viewportWidth - REFERENCE_VIEWPORT_MIN) / (REFERENCE_VIEWPORT_MAX - REFERENCE_VIEWPORT_MIN)
		else 1
	t = math.clamp(t, 0, 1)
	return SLOT_SIZE_MIN + (SLOT_SIZE_MAX - SLOT_SIZE_MIN) * t
end

local function computeHotbarGap(viewportWidth: number): number
	local t = (viewportWidth - HOTBAR_GAP_TAPER_START_WIDTH) / (HOTBAR_GAP_TAPER_END_WIDTH - HOTBAR_GAP_TAPER_START_WIDTH)
	t = math.clamp(t, 0, 1)
	return MOBILE_HOTBAR_GAP + (DESKTOP_HOTBAR_GAP - MOBILE_HOTBAR_GAP) * t
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StorageView.Create(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	dragService: PointerDragService.Service?
)
	if not skin.BackpackFrame then
		warn("[StandardHotbarStorage] StorageView: skin has no Backpack frame")
		return
	end

	local backpackFrame = skin.BackpackFrame
	-- Reserve hotbar height from the backpack so they never overlap.
	local hotbarFrame = skin.HotbarFrame
	local originalBackpackWidth = backpackFrame.Size.X
	local bottomReserve = scope:Value(0)
	local camera = workspace.CurrentCamera
	local viewportWidthValue = scope:Value(if camera then camera.ViewportSize.X else REFERENCE_VIEWPORT_MAX)
	if camera then
		table.insert(
			scope,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				viewportWidthValue:set(camera.ViewportSize.X)
			end)
		)
	end
	if hotbarFrame then
		local gui = skin.Gui
		local function updateBottomReserve()
			local viewportHeight = if camera then camera.ViewportSize.Y else 0
			if viewportHeight <= 0 then
				return
			end
			local viewportWidth = if camera then camera.ViewportSize.X else TAPER_END_WIDTH
			local hotbarTopY = hotbarFrame.AbsolutePosition.Y
			local gap = computeHotbarGap(viewportWidth)
			local viewportReserve = math.max(0, viewportHeight - hotbarTopY) + gap
			local guiReserve = viewportReserve
			if gui then
				local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
				guiReserve = math.max(0, guiBottom - hotbarTopY) + gap
			end
			local t = (viewportWidth - TAPER_START_WIDTH) / (TAPER_END_WIDTH - TAPER_START_WIDTH)
			t = math.clamp(t, 0, 1)
			local tapered = viewportReserve + (guiReserve - viewportReserve) * t
			local phoneT = 1 - t
			tapered -= PHONE_RECLAIM_PX * phoneT
			bottomReserve:set(math.max(gap, tapered))
		end
		table.insert(scope, hotbarFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBottomReserve))
		table.insert(scope, hotbarFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateBottomReserve))
		if camera then
			table.insert(scope, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateBottomReserve))
		end
		if gui then
			table.insert(scope, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBottomReserve))
			table.insert(scope, gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateBottomReserve))
		end
		task.defer(updateBottomReserve)
	end

	scope:Hydrate(backpackFrame) {
		Visible = scope:Computed(function(use: Fusion.Use): boolean
			local settings: CoreTypes.Settings? = use(store.Settings)
			return settings ~= nil and settings.BackpackEnabled
		end),
		Size = scope:Computed(function(use: Fusion.Use): UDim2
			local reserve: number = use(bottomReserve)
			return UDim2.new(originalBackpackWidth.Scale, originalBackpackWidth.Offset, 1, -reserve)
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
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				local settings: CoreTypes.Settings? = use(store.Settings)
				return settings ~= nil and settings.Limit > 0
			end),
		}
	end

	-- Local search, no CoreStore mutation.
	local searchText = scope:Value("")
	if skin.SearchFilter then
		local searchFilterBox = skin.SearchFilter
		scope:Hydrate(searchFilterBox) {
			[Fusion.OnChange("Text")] = function(newText: string)
				searchText:set(newText)
			end,
		}
	end

	if not skin.ScrollingFrame or not skin.SlotTemplate then
		warn("[StandardHotbarStorage] StorageView: skin missing ScrollingFrame or Slot template")
		return
	end
	local scrollingFrame = skin.ScrollingFrame
	local slotTemplate = skin.SlotTemplate

	-- Skin-declared art bleed (px per side): added to grid cell padding so
	-- overhang deco clears headers and neighboring cells.
	local bleed: number = skin.SlotBleedPx or 0

	-- Normalize the skin's scroll layout (generic): group containers expect
	-- vertical stacking. Reuse a skin list when present, create one when
	-- absent, and drop grid layouts that would crush groups into cells.
	-- Operates on the live clone only; the skin prefab is untouched.
	local scrollList = scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if scrollList then
		scope:Hydrate(scrollList) {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
		}
	else
		scope:New("UIListLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 4),
			Parent = scrollingFrame,
		}
	end
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("UIGridLayout") then
			warn("[StandardHotbarStorage] StorageView: removing skin UIGridLayout in ScrollingFrame (groups need vertical stacking)")
			child:Destroy()
		end
	end

	-- Square cells sized like the hotbar.
	local cellSize = scope:Computed(function(use: Fusion.Use): UDim2
		local vw: number = use(viewportWidthValue)
		local size = computeSlotSize(vw)
		return UDim2.fromOffset(size, size)
	end)

	local groupedSlots = scope:Computed(function(use: Fusion.Use): CoreTypes.GroupedStorage
		local settings: CoreTypes.Settings? = use(store.Settings)
		local groupByCategory = settings ~= nil and settings.GroupByCategory == true
		local storage: { string } = use(store.Storage)
		local items: { [string]: CoreTypes.Item } = use(store.Items)
		return Query.groupStorageByType(storage, items, groupByCategory)
	end)

	local collapsedGroups = scope:Value({} :: { [string]: boolean })

	local groupOrder = scope:Computed(function(use: Fusion.Use): { string }
		local settings: CoreTypes.Settings? = use(store.Settings)
		local groups: CoreTypes.GroupedStorage = use(groupedSlots)
		return Query.orderedGroupKeys(groups, if settings then settings.Categories else nil)
	end)

	local groupFor = scope:ForPairs(groupOrder, function(_use, groupScope: Fusion.Scope<typeof(Fusion)>, orderIndex: number, itemType: string)
		local isUngrouped = itemType == Query.UNGROUPED_KEY

		local categoryInfo = groupScope:Computed(function(use: Fusion.Use): CoreTypes.CategoryDef?
			local settings: CoreTypes.Settings? = use(store.Settings)
			return if settings then settings.Categories[itemType] else nil
		end)

		local displayName = groupScope:Computed(function(use: Fusion.Use): string
			local category: CoreTypes.CategoryDef? = use(categoryInfo)
			return if category and category.DisplayName then category.DisplayName else itemType
		end)

		local headerColor = groupScope:Computed(function(use: Fusion.Use): Color3
			-- Per-skin look first (e.g. Modern's dark metal headers),
			-- then category color, then fallback. Skins without
			-- HeaderColors render exactly as before.
			local skinOverride = skin.HeaderColors and skin.HeaderColors[itemType]
			if skinOverride then return skinOverride end
			local category: CoreTypes.CategoryDef? = use(categoryInfo)
			return if category and category.Color then category.Color else FALLBACK_HEADER_COLOR
		end)

		local records = groupScope:Computed(function(use: Fusion.Use): { CoreTypes.ItemRecord }
				local groups: CoreTypes.GroupedStorage = use(groupedSlots)
				local raw = groups[itemType] or {}
			local items: { [string]: CoreTypes.Item } = use(store.Items)
			local search: string = use(searchText)
			local filtered = Query.filterRecordsBySearch(raw, items, search)
			local settings: CoreTypes.Settings? = use(store.Settings)
			return Query.sortRecords(filtered, items, if settings then settings.SortOrder else "None")
		end)

		local isCollapsed = groupScope:Computed(function(use: Fusion.Use): boolean
			local collapsed: { [string]: boolean } = use(collapsedGroups)
			return not isUngrouped and collapsed[itemType] == true
		end)

		-- Container hidden during search when no matches.
		local container = groupScope:New("Frame") {
			Name = if isUngrouped then "Ungrouped" else "Group-" .. itemType,
			LayoutOrder = orderIndex,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = groupScope:Computed(function(use: Fusion.Use): boolean
				local search: string = use(searchText)
				local recs: { CoreTypes.ItemRecord } = use(records)
				if search ~= "" and #recs == 0 then
					return false
				end
				return true
			end),
			Parent = scrollingFrame,
		}

		groupScope:New("UIListLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 4),
			Parent = container,
		}

		if not isUngrouped then
			local header = groupScope:New("TextButton") {
				Name = "Header",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundColor3 = headerColor,
				BackgroundTransparency = 0.35,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Text = groupScope:Computed(function(use: Fusion.Use): string
						local collapsed: boolean = use(isCollapsed)
						local arrow = if collapsed then "▶" else "▼"
						local name: string = use(displayName)
						local recs: { CoreTypes.ItemRecord } = use(records)
					return `{arrow} {name} ({#recs})`
				end),
				Parent = container,
			} :: TextButton

			-- Toggle collapses grid, header stays visible.
			(header :: TextButton).Activated:Connect(function()
				local current: { [string]: boolean } = Fusion.peek(collapsedGroups)
				local nextCollapsed: { [string]: boolean } = table.clone(current)
				nextCollapsed[itemType] = not (nextCollapsed[itemType] == true)
				collapsedGroups:set(nextCollapsed)
			end)

			-- RivetLite: match slot chrome (rounded, edged, inset label).
			groupScope:New("UICorner") {
				CornerRadius = UDim.new(0, 6),
				Parent = header,
			}
			groupScope:New("UIStroke") {
				Color = Color3.fromRGB(58, 58, 68),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = header,
			}
			groupScope:New("UIPadding") {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = header,
			}
		end

		local slotGrid = groupScope:New("Frame") {
			Name = "Slots",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = groupScope:Computed(function(use: Fusion.Use): boolean
				local collapsed: boolean = use(isCollapsed)
				return not collapsed
			end),
			Parent = container,
		}

		-- Container inset for overhang bleed: prevents art clipping at
		-- ScrollingFrame edge (ClipsDescendants) and art-on-header/neighbor
		-- collisions on row edges. HotbarView handles this via effPad;
		-- storage grids need the same inset via padding. Zero bleed = no-op.
		if bleed > 0 then
			groupScope:New("UIPadding") {
				PaddingTop = UDim.new(0, bleed),
				PaddingBottom = UDim.new(0, bleed),
				PaddingLeft = UDim.new(0, bleed),
				PaddingRight = UDim.new(0, bleed),
				Parent = slotGrid,
			}
		end

		groupScope:New("UIGridLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = cellSize,
			CellPadding = UDim2.fromOffset(CELL_PADDING + bleed * 2, CELL_PADDING + bleed * 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = slotGrid,
		}

		local storageFor = groupScope:ForPairs(records, function(_use, slotScope: Fusion.Scope<typeof(Fusion)>, listIndex: number, record: CoreTypes.ItemRecord)
			local slotFrame = SlotView.Create(slotScope, {
				SlotType = "Storage",
				SlotIndex = record.index,
				Parent = slotGrid,
				Template = slotTemplate,
				Store = store,
				HideChrome = skin.HideInStorage,
				DragService = dragService,
				GlowSpread = skin.GlowSpread,
				Hooks = skin.Hooks,
			})
			do
				local cursor = skin.SelectionCursorTemplate
				local btn = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
				if cursor ~= nil and btn ~= nil then btn.SelectionImageObject = cursor end
			end
			-- LayoutOrder via Hydrate+Computed so reorder is task.defer coalesced
			-- with the SlotView image/stack/rarity updates (atomic with hotbar swaps).
			-- listIndex is the ForPairs key (1..n) – wrap in Computed to make it a
			-- state so applyInstanceProps defers it.
			local orderState = slotScope:Computed(function(): number
				return listIndex
			end)
			slotScope:Hydrate(slotFrame) {
				LayoutOrder = orderState,
				Size = cellSize,
			}

			if dragService ~= nil then
				local slotRef: CoreTypes.SlotRef = { Type = "Storage", Slot = record.index }
				local handle = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
				if handle ~= nil then dragService:RegisterDraggable(slotScope, handle, slotRef) end
				dragService:RegisterDropTarget(slotScope, slotFrame, slotRef)
			end

			return listIndex, record
		end)
		Fusion.peek(storageFor)
		groupScope:Observer(storageFor)

		return orderIndex, itemType
	end)
	Fusion.peek(groupFor)
	scope:Observer(groupFor)
end

-----------------------------
-- MAIN --
-----------------------------

return StorageView
