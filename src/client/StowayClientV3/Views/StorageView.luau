--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Sectioned storage (backpack). Slots are grouped by item Type — visual only,
	storage array order is preserved within each group. Group headers
	(display name + count) toggle collapse. Weight label reflects Limit.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local ClientStore = require(script.Parent.Parent.Core.ClientStore)
local SlotView = require(script.Parent.Parent.Slot.SlotView)

local StorageView = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local CELL_SIZE = UDim2.fromOffset(96, 120)
local HEADER_HEIGHT = 26
local OTHER_COLOR = Color3.fromRGB(80, 80, 90)

-----------------------------
-- TYPES --
-----------------------------

type Skin = {
	BackpackFrame: Frame?,
	ScrollingFrame: ScrollingFrame?,
	WeightLabel: TextLabel?,
	SlotTemplate: Frame?,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StorageView.Create(scope: Fusion.Scope, skin: Skin, store: typeof(ClientStore))
	if not skin.BackpackFrame then
		warn("[StowayClientV3] StorageView: missing Backpack frame")
		return
	end

	scope:Computed(function(use)
		local settings = use(store.Settings)
		skin.BackpackFrame.Visible = settings ~= nil and settings.BackpackEnabled
	end)

	if skin.WeightLabel then
		scope:Hydrate(skin.WeightLabel) {
			Text = scope:Computed(function(use)
				local weight = use(store.Weight)
				local settings = use(store.Settings)
				local limit = settings and settings.Limit or 0
				if limit <= 0 then
					return tostring(weight)
				end
				return `{weight}/{limit}`
			end),
			Visible = scope:Computed(function(use)
				local settings = use(store.Settings)
				return settings ~= nil and settings.Limit > 0
			end),
		}
	end

	if not skin.ScrollingFrame or not skin.SlotTemplate then
		warn("[StowayClientV3] StorageView: missing ScrollingFrame or slot template")
		return
	end

	-- { [Type] = { { index, uuid } } } — storage positions preserved per group.
	local groupedSlots = scope:Computed(function(use)
		local storage = use(store.Storage)
		local items = use(store.Items)
		local groups: { [string]: { { index: number, uuid: string } } } = {}
		for index, uuid in storage do
			local item = items[uuid]
			local itemType = if item and item.Metadata and item.Metadata.Type
				then item.Metadata.Type
				else "Other"
			local group = groups[itemType]
			if not group then
				group = {}
				groups[itemType] = group
			end
			table.insert(group, { index = index, uuid = uuid })
		end
		return groups
	end)

	-- { [Type] = true } while a group is collapsed.
	local collapsed = scope:Value({} :: { [string]: boolean })

	-- Deterministic type order: Settings.Categories by Order, then unknowns.
	local groupOrder = scope:Computed(function(use)
		local settings = use(store.Settings)
		local categories = settings and settings.Categories or {}
		local keys: { string } = {}
		local seen: { [string]: boolean } = {}
		for itemType in use(groupedSlots) do
			if not seen[itemType] then
				table.insert(keys, itemType)
				seen[itemType] = true
			end
		end
		table.sort(keys, function(a, b)
			local ca = categories[a]
			local cb = categories[b]
			local oa = if ca then ca.Order else math.huge
			local ob = if cb then cb.Order else math.huge
			if oa ~= ob then
				return oa < ob
			end
			return a < b
		end)
		return keys
	end)

	scope:ForPairs(groupOrder, function(use, groupScope, orderIndex, itemType)
		local categoryInfo = groupScope:Computed(function(use)
			local settings = use(store.Settings)
			return settings and settings.Categories[itemType]
		end)

		local displayName = groupScope:Computed(function(use)
			local category = use(categoryInfo)
			return if category and category.DisplayName then category.DisplayName else itemType
		end)

		local headerColor = groupScope:Computed(function(use)
			local category = use(categoryInfo)
			return if category and category.Color then category.Color else OTHER_COLOR
		end)

		local records = groupScope:Computed(function(use)
			return use(groupedSlots)[itemType] or {}
		end)

		local container = groupScope:New("Frame") {
			Name = "Group-" .. itemType,
			LayoutOrder = orderIndex,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = skin.ScrollingFrame,
		}

		groupScope:New("UIListLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 4),
			Parent = container,
		}

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
			TextTransparency = 0,
			AutoButtonColor = false,
			Parent = container,
		}

		groupScope:Hydrate(header) {
			Text = groupScope:Computed(function(use)
				local isCollapsed = use(collapsed)[itemType] == true
				local count = #use(records)
				return `{(if isCollapsed then "▸" else "▾")} {use(displayName)} ({count})`
			end),
		}

		header.Activated:Connect(function()
			local nextCollapsed = table.clone(Fusion.peek(collapsed))
			nextCollapsed[itemType] = not (nextCollapsed[itemType] == true)
			collapsed:set(nextCollapsed)
		end)

		local slotGrid = groupScope:New("Frame") {
			Name = "Slots",
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = container,
		}

		groupScope:New("UIGridLayout") {
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = CELL_SIZE,
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = slotGrid,
		}

		groupScope:ForPairs(records, function(use, slotScope, slotIndex, record)
			local slotFrame = SlotView.Create(slotScope, {
				SlotType = "Storage",
				SlotIndex = record.index,
				Parent = slotGrid,
				Template = skin.SlotTemplate,
			})
			slotFrame.LayoutOrder = slotIndex
			slotFrame.Size = CELL_SIZE
			return slotIndex, record
		end)

		groupScope:Hydrate(container) {
			Visible = groupScope:Computed(function(use)
				return not (use(collapsed)[itemType] == true)
			end),
		}
	end)
end

-----------------------------
-- MAIN --
-----------------------------

return StorageView