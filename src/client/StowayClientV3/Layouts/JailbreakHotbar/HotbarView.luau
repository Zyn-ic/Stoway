--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Bottom-center circular hotbar row, Jailbreak style. Supports Static
	(holes) and Dynamic (packed) modes. No drag wiring: slots are tap to
	equip only — sweep/paint-swap arrives in the logic pass and registers
	here. Each slot gets a white equip ring bound to EquippedItemUUID.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)
local Binds = require(script.Parent.Binds)
local State = require(script.Parent.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local SlotView = require(script.Parent.Parent.Parent.Slot.SlotView)
local PointerDragService = require(script.Parent.Parent.Parent.Interactions.PointerDragService)

local HotbarView = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local SLOT_SIZE_MIN = 48
local SLOT_SIZE_MAX = 68
local REFERENCE_VIEWPORT_MIN = 390
local REFERENCE_VIEWPORT_MAX = 1440
local SLOT_GAP = 8
local BOTTOM_MARGIN_PX = 10

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

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function HotbarView.Create(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	dragService: PointerDragService.Service?
)
	if not skin.HotbarFrame then
		warn("[JailbreakHotbar] HotbarView: skin has no Hotbar frame")
		return
	end
	if not skin.SlotTemplate then
		warn("[JailbreakHotbar] HotbarView: skin has no Slot template")
		return
	end
	local hotbarFrame = skin.HotbarFrame
	local slotTemplate = skin.SlotTemplate

	local bleed: number = skin.SlotBleedPx or 0
	local effGap = SLOT_GAP + bleed * 2

	local listLayout = hotbarFrame:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		scope:Hydrate(listLayout) {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, effGap),
		}
	end

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
		local settings: CoreTypes.Settings? = use(store.Settings)
		return State.getMaxHotbarSlots(settings)
	end)

	local slotSize = scope:Computed(function(use: Fusion.Use): number
		local vw: number = use(viewportWidth)
		return computeSlotSize(vw)
	end)

	scope:Hydrate(hotbarFrame) {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = scope:Computed(function(use: Fusion.Use): UDim2
			local size: number = use(slotSize)
			local slots: number = use(maxSlots)
			local width = slots * size + math.max(0, slots - 1) * effGap
			return UDim2.fromOffset(width, size)
		end),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN_PX),
	}

	local slotSizeUDim = scope:Computed(function(use: Fusion.Use): UDim2
		local size: number = use(slotSize)
		return UDim2.fromOffset(size, size)
	end)

	local isDynamic = scope:Computed(function(use: Fusion.Use): boolean
		local settings: CoreTypes.Settings? = use(store.Settings)
		return Query.isDynamicHotbar(settings)
	end)

	local slotIndices = scope:Computed(function(use: Fusion.Use): { [number]: boolean }
		local settings: CoreTypes.Settings? = use(store.Settings)
		return State.slotIndices(State.getMaxHotbarSlots(settings))
	end)

	local hotbarFor = scope:ForPairs(slotIndices, function(_use, slotScope: Fusion.Scope<typeof(Fusion)>, slotIndex: number)
		local packOrder = slotScope:Computed(function(use: Fusion.Use): number
			local hotbar: { [number]: string? } = use(store.Hotbar)
			local items: { [string]: CoreTypes.Item } = use(store.Items)
			local dyn: boolean = use(isDynamic)
			return Query.packedHotbarOrder(hotbar, items, slotIndex, dyn)
		end)

		local visibility = slotScope:Computed(function(use: Fusion.Use): boolean
			local hotbar: { [number]: string? } = use(store.Hotbar)
			local items: { [string]: CoreTypes.Item } = use(store.Items)
			local dyn: boolean = use(isDynamic)
			return Query.isHotbarSlotVisible(hotbar, items, slotIndex, dyn)
		end)

		-- Static position number (1..9, 0), Jailbreak style: bottom-left,
		-- tinted by team in SlotView.
		local bindCfg = Binds.HotbarSlots[slotIndex]
		local hasBind = bindCfg ~= nil and (bindCfg.PC ~= nil or bindCfg.Console ~= nil)

		local keybind = slotScope:Computed(function(use: Fusion.Use): string
			if bindCfg ~= nil and bindCfg.Display ~= nil then return bindCfg.Display end
			local display: number = use(packOrder)
			return if display == 10 then "0" else tostring(display)
		end)

		local isEquipped = slotScope:Computed(function(use: Fusion.Use): boolean
			local hotbar: { [number]: string? } = use(store.Hotbar)
			local equipped: string? = use(store.EquippedItemUUID)
			return Query.isEquipped(equipped, hotbar[slotIndex])
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
		})
		slotScope:Hydrate(slotFrame) {
			Size = slotSizeUDim,
		}

		-- Scale punch target for the swap-pop. UIScale never fights the
		-- Size binding above.
		slotScope:New("UIScale") {
			Scale = 1,
			Parent = slotFrame,
		}

		-- White equip ring on the circular button. SlotView's selecticon
		-- is absent from this template, so the layout owns the indicator.
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

		-- Sweep source + target: press paints, crossings commit.
		if dragService ~= nil then
			local slotRef: CoreTypes.SlotRef = { Type = "Hotbar", Slot = slotIndex }
			local handle = slotFrame:FindFirstChild("slotbutton") :: GuiButton?
			if handle ~= nil then dragService:RegisterDraggable(slotScope, handle, slotRef) end
			dragService:RegisterDropTarget(slotScope, slotFrame, slotRef)
		end

		return slotIndex, true
	end)
	-- New Fusion 0.3 For is lazy; side-effect For must be observed to run
	Fusion.peek(hotbarFor)
	scope:Observer(hotbarFor)
end

-----------------------------
-- MAIN --
-----------------------------

return HotbarView
