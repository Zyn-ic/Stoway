--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Sectioned storage: slots are visually bucketed by item Metadata.Type
	(Settings.Categories controls each group's display name/color/order)
	with collapsible group headers, gated by Settings.GroupByCategory. When
	that setting is false, Storage renders as a single flat, ungrouped list
	straight into the backpack ScrollingFrame instead — the "pure" backpack
	view, with grouping as an example of a settings-driven display toggle
	you can flip before or during runtime.

	This is all presentation-only. Storage stays a flat, order-preserving
	array the whole time; collapsing a header or typing a search only hides
	slot frames, it never reorders, filters, or otherwise touches the
	underlying data (see CoreStore.Query.groupStorageByType/filterRecordsBySearch).

	Group header is a sibling of its slot grid, not a parent — collapsing
	only hides the grid, so the header (and the ability to expand again)
	always stays visible. Getting this backwards was the collapse bug: an
	earlier version toggled Visible on the shared header+grid container, so
	collapsing hid the header along with the slots and there was nothing
	left to click to reopen it.
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

local StorageView = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local CELL_PADDING = 8
local CELL_HEIGHT = 96
local TARGET_COLUMNS = 5
local MIN_CELL_WIDTH = 48
local HEADER_HEIGHT = 26
local FALLBACK_HEADER_COLOR = Color3.fromRGB(80, 80, 90)

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StorageView.Create(scope: Fusion.Scope<any>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	if not skin.BackpackFrame then
		warn("[StandardHotbarStorage] StorageView: skin has no Backpack frame")
		return
	end
	local backpackFrame = skin.BackpackFrame

	scope:Hydrate(backpackFrame) {
		Visible = scope:Computed(function(use)
			local settings = use(store.Settings)
			return settings ~= nil and settings.BackpackEnabled
		end),
	}

	if skin.WeightLabel then
		local weightLabel = skin.WeightLabel
		scope:Hydrate(weightLabel) {
			Text = scope:Computed(function(use)
				local settings = use(store.Settings)
				return Query.formatWeight(use(store.Weight), settings and settings.Limit or 0)
			end),
			Visible = scope:Computed(function(use)
				local settings = use(store.Settings)
				return settings ~= nil and settings.Limit > 0
			end),
		}
	end

	-- Local-only search text. Never touches Storage or CoreStore — purely
	-- filters which slot records each group (or the flat list) renders.
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

	-- Responsive cell width: always TARGET_COLUMNS per row, regardless of
	-- screen size. The backpack frame is a fixed % of screen width, so the
	-- ScrollingFrame's width changes with it — recompute the cell on resize.
	local cellWidth = scope:Value(MIN_CELL_WIDTH)
	local function updateCellWidth()
		local width = scrollingFrame.AbsoluteSize.X
		if width > 0 then
			cellWidth:set(math.max(MIN_CELL_WIDTH, (width - (TARGET_COLUMNS - 1) * CELL_PADDING) / TARGET_COLUMNS))
		end
	end
	table.insert(scope, scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCellWidth))
	task.defer(updateCellWidth)

	local cellSize = scope:Computed(function(use)
		return UDim2.fromOffset(use(cellWidth), CELL_HEIGHT)
	end)

	local groupedSlots = scope:Computed(function(use)
		local settings = use(store.Settings)
		local groupByCategory = settings ~= nil and settings.GroupByCategory == true
		return Query.groupStorageByType(use(store.Storage), use(store.Items), groupByCategory)
	end)

	-- { [Type] = true } while a group's slot grid is hidden. Purely local UI
	-- state — never touches Storage or CoreStore. Irrelevant (and unused)
	-- for the ungrouped case, since there's no header to click there.
	local collapsedGroups = scope:Value({} :: { [string]: boolean })

	local groupOrder = scope:Computed(function(use)
		local settings = use(store.Settings)
		return Query.orderedGroupKeys(use(groupedSlots), settings and settings.Categories)
	end)

	scope:ForPairs(groupOrder, function(use, groupScope, orderIndex, itemType)
		local isUngrouped = itemType == Query.UNGROUPED_KEY

		local categoryInfo = groupScope:Computed(function(use)
			local settings = use(store.Settings)
			return settings and settings.Categories and settings.Categories[itemType]
		end)

		local displayName = groupScope:Computed(function(use)
			local category = use(categoryInfo)
			return if category and category.DisplayName then category.DisplayName else itemType
		end)

		local headerColor = groupScope:Computed(function(use)
			local category = use(categoryInfo)
			return if category and category.Color then category.Color else FALLBACK_HEADER_COLOR
		end)

		local records = groupScope:Computed(function(use)
			local raw = use(groupedSlots)[itemType] or {}
			return Query.filterRecordsBySearch(raw, use(store.Items), use(searchText))
		end)

		local isCollapsed = groupScope:Computed(function(use)
			return not isUngrouped and use(collapsedGroups)[itemType] == true
		end)

		-- Header always visible while it has matches (or nothing is being
		-- searched) — search hides a group entirely only when it has zero
		-- matching items, so an empty header never lingers mid-search.
		local container = groupScope:New("Frame") {
			Name = if isUngrouped then "Ungrouped" else "Group-" .. itemType,
			LayoutOrder = orderIndex,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = groupScope:Computed(function(use)
				local isSearching = use(searchText) ~= ""
				if isSearching and #use(records) == 0 then
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
				BackgroundTransparency = 0.15,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				Font = Enum.Font.GothamSemibold,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Text = groupScope:Computed(function(use)
					local arrow = if use(isCollapsed) then "▸" else "▾"
					return `{arrow} {use(displayName)} ({#use(records)})`
				end),
				Parent = container,
			}

			-- Local-only toggle: flips this group's entry in collapsedGroups.
			-- The header itself is a sibling of the slot grid below, so it
			-- stays visible (and clickable) regardless of collapse state.
			header.Activated:Connect(function()
				local nextCollapsed = table.clone(Fusion.peek(collapsedGroups))
				nextCollapsed[itemType] = not (nextCollapsed[itemType] == true)
				collapsedGroups:set(nextCollapsed)
			end)
		end

		local slotGrid = groupScope:New("Frame") {
			Name = "Slots",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Visible = groupScope:Computed(function(use)
				return not use(isCollapsed)
			end),
			Parent = container,
		}

		groupScope:New("UIGridLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = cellSize,
			CellPadding = UDim2.fromOffset(CELL_PADDING, CELL_PADDING),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = slotGrid,
		}

		groupScope:ForPairs(records, function(use, slotScope, listIndex, record)
			local slotFrame = SlotView.Create(slotScope, {
				SlotType = "Storage",
				SlotIndex = record.index,
				Parent = slotGrid,
				Template = slotTemplate,
				Store = store,
			})
			slotFrame.LayoutOrder = listIndex
			groupScope:Hydrate(slotFrame) {
				Size = cellSize,
			}
			return listIndex, record
		end)

		return orderIndex, itemType
	end)
end

-----------------------------
-- MAIN --
-----------------------------

return StorageView
