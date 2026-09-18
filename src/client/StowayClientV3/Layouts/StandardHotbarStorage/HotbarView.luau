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
local Binds = require(script.Parent.Binds)

local function useTyped(useFn: Fusion.Use, target: any): any
	return (useFn :: any)(target)
end

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

local function computeHotbarXScale(viewportWidth: number, desktopOverride: number?): number
	local t = (viewportWidth - HOTBAR_X_TAPER_START_WIDTH) / (HOTBAR_X_TAPER_END_WIDTH - HOTBAR_X_TAPER_START_WIDTH)
	t = math.clamp(t, 0, 1)
	local desktop = desktopOverride or DESKTOP_HOTBAR_X_SCALE
	return MOBILE_HOTBAR_X_SCALE + (desktop - MOBILE_HOTBAR_X_SCALE) * t
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function HotbarView.Create(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	dragService: any?
)
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

	-- Skin-declared art bleed (px per side): deco that paints past cell bounds
	-- is given room in gap + padding math instead of swallowing the rhythm.
	-- Hotbar caps bleed at 8 so Storage can breathe (cap 16) without the
	-- bar blowing out — storage needs wall-to-wall clearance, hotbar
	-- tolerates a tighter overhang.
	local bleed: number = skin.SlotBleedPx or 0
	local hotbarBleed = math.min(bleed, 8)
	local effGap = SLOT_GAP + hotbarBleed * 2
	local effPad = INNER_PADDING + hotbarBleed

	-- Use LayoutOrder for deterministic slot ordering and fixed pixel gaps.
	local hotbarListLayout = hotbarFrame:FindFirstChildOfClass("UIListLayout")
	if hotbarListLayout then
		scope:Hydrate(hotbarListLayout) {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, effGap),
		}
	end

	-- Fixed inset for the hotbar container. Outer pad scales with
	-- bleed so the first/last slot overhang doesn't clip at the
	-- container edge (hotbar has no ScrollingFrame clipping but the
	-- spill still needs room). Gaps use bleed*2 so neighbors clear.
	local hotbarPadding = hotbarFrame:FindFirstChildOfClass("UIPadding")
	if hotbarPadding then
		scope:Hydrate(hotbarPadding) {
			PaddingTop = UDim.new(0, effPad),
			PaddingBottom = UDim.new(0, effPad),
			PaddingLeft = UDim.new(0, effPad),
			PaddingRight = UDim.new(0, effPad),
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

	local maxSlots = scope:Computed(function(use: Fusion.Use): number
		local settings: CoreTypes.Settings? = useTyped(use, store.Settings)
		return State.getMaxHotbarSlots(settings)
	end)

	local slotSize = scope:Computed(function(use: Fusion.Use): number
		local vw: number = useTyped(use, viewportWidth)
		return computeSlotSize(vw)
	end)

	scope:Hydrate(hotbarFrame) {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = scope:Computed(function(use: Fusion.Use): UDim2
			local size: number = useTyped(use, slotSize)
			local slots: number = useTyped(use, maxSlots)
			local width = effPad * 2 + slots * size + math.max(0, slots - 1) * effGap
			local height = effPad * 2 + size
			return UDim2.fromOffset(width, height)
		end),
		Position = scope:Computed(function(use: Fusion.Use): UDim2
			local vw: number = useTyped(use, viewportWidth)
			local marginPx = computeBottomMarginPx(vw)
			-- Per-skin desktop bias (e.g. Modern sits slightly left);
			-- absent = shared default. Taper math unchanged.
			local xScale = computeHotbarXScale(vw, skin.DesktopHotbarXScale)
			return UDim2.new(xScale, originalPosition.X.Offset, 1, -marginPx)
		end),
	}

	local slotSizeUDim = scope:Computed(function(use: Fusion.Use): UDim2
		local size: number = useTyped(use, slotSize)
		return UDim2.fromOffset(size, size)
	end)

	local isDynamic = scope:Computed(function(use: Fusion.Use): boolean
		local settings: CoreTypes.Settings? = useTyped(use, store.Settings)
		return Query.isDynamicHotbar(settings)
	end)

	local slotIndices = scope:Computed(function(use: Fusion.Use): { [number]: boolean }
		local settings: CoreTypes.Settings? = useTyped(use, store.Settings)
		return State.slotIndices(State.getMaxHotbarSlots(settings))
	end)

	local hotbarFor = (scope :: any):ForPairs(slotIndices :: any, function(_use, slotScope: Fusion.Scope<typeof(Fusion)>, slotIndex: number)
		local packOrder = slotScope:Computed(function(use: Fusion.Use): number
			local hotbar: { [number]: string? } = useTyped(use, store.Hotbar)
			local items: { [string]: CoreTypes.Item } = useTyped(use, store.Items)
			local dyn: boolean = useTyped(use, isDynamic)
			return Query.packedHotbarOrder(hotbar, items, slotIndex, dyn)
		end)

		-- Unbound when the entry is missing OR carries no usable keys
		-- (e.g. Display-only). Unbound slots keep rendering + drag + tap.
		local bindCfg = Binds.HotbarSlots[slotIndex]
		local hasBind = bindCfg ~= nil and (bindCfg.PC ~= nil or bindCfg.Console ~= nil)

		local keybind = slotScope:Computed(function(use: Fusion.Use): string
			if not hasBind then return "!" end
			if bindCfg ~= nil and bindCfg.Display ~= nil then return bindCfg.Display end
			local display: number = useTyped(use, packOrder)
			return if display == 10 then "0" else tostring(display)
		end)

		local visibility = slotScope:Computed(function(use: Fusion.Use): boolean
			local hotbar: { [number]: string? } = useTyped(use, store.Hotbar)
			local items: { [string]: CoreTypes.Item } = useTyped(use, store.Items)
			local dyn: boolean = useTyped(use, isDynamic)
			return Query.isHotbarSlotVisible(hotbar, items, slotIndex, dyn)
		end)

		local slotFrame = SlotView.Create(slotScope, {
			SlotType = "Hotbar",
			SlotIndex = slotIndex,
			Parent = hotbarFrame,
			Template = slotTemplate,
			Store = store,
			ShowKeybind = true,
			HasBind = hasBind,
			HideChrome = skin.HideInHotbar,
			PackOrder = packOrder,
			Keybind = keybind,
			Visibility = visibility,
			DragService = dragService,
			GlowSpread = skin.GlowSpread,
		})
		slotScope:Hydrate(slotFrame) {
			Size = slotSizeUDim,
		}

		-- Override default selection cursor for gamepad with skin's custom Frame
		do
			local cursor = skin.SelectionCursorTemplate
			local btn = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
			if cursor ~= nil and btn ~= nil then btn.SelectionImageObject = cursor end
		end

		if dragService ~= nil then
			local slotRef: CoreTypes.SlotRef = { Type = "Hotbar", Slot = slotIndex }
			local handle = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
			if handle ~= nil then dragService:RegisterDraggable(slotScope, handle, slotRef) end
			dragService:RegisterDropTarget(slotScope, slotFrame, slotRef)
		end

		return slotIndex, true
	end)
	-- New Fusion 0.3 For is lazy; side-effect For must be observed to run
	;(Fusion.peek :: any)(hotbarFor)
	;(scope :: any):Observer(hotbarFor)
end

-----------------------------
-- MAIN --
-----------------------------

return HotbarView
