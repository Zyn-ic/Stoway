--!strict

--@author: yyumchi
--@date: 2026-08-20
--[[@description:
	Bottom hotbar view. Supports Static (holes) and Dynamic (packed) modes,
	fixed pixel slot sizing and auto-sized container for consistent spacing
	across devices.
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
-- CONSTANTS --
-----------------------------

-- Responsive slot size by viewport width. Container sizes to its contents
-- to prevent percentage-based overflow.
local SLOT_SIZE_MIN = 36
local SLOT_SIZE_MAX = 62
local REFERENCE_VIEWPORT_MIN = 390
local REFERENCE_VIEWPORT_MAX = 1440
local SLOT_GAP = 7
local INNER_PADDING = 8

-- Bottom margin in pixels, tapered by width.
local MOBILE_BOTTOM_MARGIN_PX = 8
local DESKTOP_BOTTOM_MARGIN_PX = 12
local MARGIN_TAPER_START_WIDTH = 900
local MARGIN_TAPER_END_WIDTH = 1600

-- Horizontal position tapered to keep clear of jump button on phones.
local MOBILE_HOTBAR_X_SCALE = 0.51
local DESKTOP_HOTBAR_X_SCALE = 0.57
local HOTBAR_X_TAPER_START_WIDTH = 900
local HOTBAR_X_TAPER_END_WIDTH = 1300

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

local function computeBottomMarginPx(viewportWidth: number): number
	local t = (viewportWidth - MARGIN_TAPER_START_WIDTH) / (MARGIN_TAPER_END_WIDTH - MARGIN_TAPER_START_WIDTH)
	t = math.clamp(t, 0, 1)
	return MOBILE_BOTTOM_MARGIN_PX + (DESKTOP_BOTTOM_MARGIN_PX - MOBILE_BOTTOM_MARGIN_PX) * t
end

local function computeHotbarXScale(viewportWidth: number): number
	local t = (viewportWidth - HOTBAR_X_TAPER_START_WIDTH) / (HOTBAR_X_TAPER_END_WIDTH - HOTBAR_X_TAPER_START_WIDTH)
	t = math.clamp(t, 0, 1)
	return MOBILE_HOTBAR_X_SCALE + (DESKTOP_HOTBAR_X_SCALE - MOBILE_HOTBAR_X_SCALE) * t
end

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

	-- Use LayoutOrder for deterministic slot ordering and fixed pixel gaps.
	local hotbarListLayout = hotbarFrame:FindFirstChildOfClass("UIListLayout")
	if hotbarListLayout then
		scope:Hydrate(hotbarListLayout) {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, SLOT_GAP),
		}
	end

	-- Fixed inset for the hotbar container.
	local hotbarPadding = hotbarFrame:FindFirstChildOfClass("UIPadding")
	if hotbarPadding then
		scope:Hydrate(hotbarPadding) {
			PaddingTop = UDim.new(0, INNER_PADDING),
			PaddingBottom = UDim.new(0, INNER_PADDING),
			PaddingLeft = UDim.new(0, INNER_PADDING),
			PaddingRight = UDim.new(0, INNER_PADDING),
		}
	end

	-- Position and size are driven by viewport width.
	local originalPosition = hotbarFrame.Position

	local camera = workspace.CurrentCamera
	local viewportWidth = scope:Value(if camera then camera.ViewportSize.X else REFERENCE_VIEWPORT_MAX)
	if camera then
		table.insert(
			scope,
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				viewportWidth:set(camera.ViewportSize.X)
			end)
		)
	end

	local maxSlots = scope:Computed(function(use)
		return State.getMaxHotbarSlots(use(store.Settings))
	end)

	local slotSize = scope:Computed(function(use)
		return computeSlotSize(use(viewportWidth))
	end)

	scope:Hydrate(hotbarFrame) {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = scope:Computed(function(use)
			local size = use(slotSize)
			local slots = use(maxSlots)
			local width = INNER_PADDING * 2 + slots * size + math.max(0, slots - 1) * SLOT_GAP
			local height = INNER_PADDING * 2 + size
			return UDim2.fromOffset(width, height)
		end),
		Position = scope:Computed(function(use)
			local marginPx = computeBottomMarginPx(use(viewportWidth))
			local xScale = computeHotbarXScale(use(viewportWidth))
			return UDim2.new(xScale, originalPosition.X.Offset, 1, -marginPx)
		end),
	}

	local slotSizeUDim = scope:Computed(function(use)
		local size = use(slotSize)
		return UDim2.fromOffset(size, size)
	end)

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
			local display = use(packOrder)
			return if display == 10 then "0" else tostring(display)
		end)

		local visibility = slotScope:Computed(function(use)
			return Query.isHotbarSlotVisible(use(store.Hotbar), use(store.Items), slotIndex, use(isDynamic))
		end)

		local slotFrame = SlotView.Create(slotScope, {
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
		slotScope:Hydrate(slotFrame) {
			Size = slotSizeUDim,
		}

		return slotIndex, true
	end)
end

-----------------------------
-- MAIN --
-----------------------------

return HotbarView
