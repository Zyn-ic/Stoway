--!strict

--@author: yyumchi
--@date: 2026-10-12
--[[@description:
	Shared layout helpers. Both HotbarType engines (StandardHotbarStorage,
	JailbreakHotbar) had their own copies of these; a single module holds
	them so behavior can't drift between layouts. Layout-specific commit
	rules (Standard's empty-area handling, Jailbreak's sweep) stay in the
	engines and call into these primitives.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local State = require(script.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.CoreStore.Query)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local PreferredInput = require(script.Parent.Parent.Interactions.PreferredInput)

local Shared = {}

-----------------------------
-- CONSTANTS --
-----------------------------

-- Code-built skins use fixed design sizes; these gaps are in pixels and
-- are applied relative to the live safe-area + hotbar geometry.
local POPUP_GAP = 12
local POPUP_SIDE_MARGIN = 12
local POPUP_FALLBACK_WIDTH = 440
local POPUP_FALLBACK_HEIGHT = 340
local POPUP_DEFAULT_TOP_OVERHANG = 12

local TOGGLE_GAP = 8
local TOGGLE_SCALE = 0.8
local TOGGLE_MIN = 32
local TOGGLE_MAX = 44

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- AbsolutePosition/AbsoluteSize are plain properties, not Fusion state.
-- Bump one Value whenever either changes so computed geometry re-runs.
-- The bump is deferred: these signals also fire DURING a Fusion graph
-- change (the hotbar resizing itself), and setting a Value from inside
-- a graph change re-enters the graph and trips Fusion's infinite-loop
-- guard. Deferring moves the update outside the current change.
local function trackGeometry(
	scope: Fusion.Scope<typeof(Fusion)>,
	gui: ScreenGui,
	hotbar: Frame
): Fusion.Value<number>
	local tick = scope:Value(0)
	local generation = 0
	local pending = false
	local alive = true
	local function bump()
		pending = false
		if not alive then return end
		generation += 1
		tick:set(generation)
	end
	local function schedule()
		if pending or not alive then return end
		pending = true
		task.defer(bump)
	end
	local tracked: { GuiBase2d } = { gui, hotbar }
	for _, inst in tracked do
		table.insert(scope, inst:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule))
		table.insert(scope, inst:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule))
	end
	-- Scope cleanup runs its tasks back-to-front, so this flag flips
	-- before the deferred bump can touch a cleaned-up scope.
	table.insert(scope, function()
		alive = false
	end)
	schedule()
	return tick
end

-- Slots are created by HotbarView before the layout binds responsive UI.
-- Prefer the real slot size; fall back to the hotbar height minus padding.
local function getSlotSize(hotbar: Frame): number
	local first = hotbar:FindFirstChild("Hotbar-1")
	if first and first:IsA("GuiObject") and first.AbsoluteSize.X > 0 then
		return first.AbsoluteSize.X
	end
	for _, child in hotbar:GetChildren() do
		if child:IsA("GuiObject") and child.Name:match("^Hotbar%-%d+$") then
			return child.AbsoluteSize.X
		end
	end
	return math.max(0, hotbar.AbsoluteSize.Y - 16)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Shared.getMaxSlots(store: typeof(ClientStore)): number
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return State.getMaxHotbarSlots(settings)
end

function Shared.isBackpackEnabled(store: typeof(ClientStore)): boolean
	local s: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return s == nil or s.BackpackEnabled ~= false
end

function Shared.hasDestItem(store: typeof(ClientStore), target: CoreTypes.SlotRef): boolean
	if target.Type == "Hotbar" then
		local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
		return hotbar[target.Slot] ~= nil
	else
		local storage: { string } = Fusion.peek(store.Storage)
		return storage[target.Slot] ~= nil
	end
end

function Shared.handleSwap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): boolean
	local res = ClientController.Swap(from, to)
	if not res.ok then
		Log.warn(ClientStore.GetSettings(), "[Layouts/Shared] Swap rejected", res.error and res.error.message or tostring(res))
	end
	return res.ok
end

function Shared.handleMove(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): boolean
	local res = ClientController.Move(from, to)
	if not res.ok then
		Log.warn(ClientStore.GetSettings(), "[Layouts/Shared] Move rejected", res.error and res.error.message or tostring(res))
	end
	return res.ok
end

function Shared.doEquipSlot(store: typeof(ClientStore), visibleIndex: number)
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
	local items: { [string]: CoreTypes.Item } = Fusion.peek(store.Items)
	local hotbarType = if settings then settings.HotbarType else "Static"
	local uuid: string?
	if hotbarType == "Dynamic" then
		-- visibleIndex 1.. is packOrder; map to actual slot uuid
		for slot = 1, Shared.getMaxSlots(store) do
			if Query.packedHotbarOrder(hotbar, items, slot, true) == visibleIndex then
				uuid = hotbar[slot]
				break
			end
		end
	else
		uuid = hotbar[visibleIndex]
	end
	if not uuid then
		if Fusion.peek(store.EquippedItemUUID) ~= nil then
			ClientController.Unequip()
		end
		return
	end
	local equipped: string? = Fusion.peek(store.EquippedItemUUID)
	if equipped == uuid then
		ClientController.Unequip()
	else
		ClientController.Equip(uuid)
	end
end

-- The storage toggle button is a mobile-only affordance: PC toggles with
-- keys (Tab/B) and console with DPadLeft, so the on-screen button shows
-- only on Touch while the backpack is enabled. Mirrors the prefab skins,
-- whose BackpackStuff ships Visible=false for the same reason.
function Shared.bindToggleVisible(scope: Fusion.Scope<typeof(Fusion)>, btn: GuiButton, store: typeof(ClientStore))
	local prefValue: Fusion.Value<EnumItem> = scope:Value(PreferredInput.Get())
	local prefConn = PreferredInput.Changed:Connect(function(newPref: EnumItem)
		prefValue:set(newPref)
	end)
	table.insert(scope, function()
		if prefConn ~= nil then prefConn:Disconnect() end
	end)
	scope:Hydrate(btn) {
		Visible = scope:Computed(function(use: Fusion.Use): boolean
			local s: CoreTypes.Settings? = use(store.Settings)
			local backpackEnabled = s == nil or s.BackpackEnabled ~= false
			if not backpackEnabled then return false end
			return use(prefValue) == Enum.PreferredInput.Touch
		end),
	}
end

-- Code-built skins have no authored responsive geometry. Keep their
-- popup above the hotbar and their mobile toggle above the left slots,
-- using the live safe-area/hotbar rectangles rather than camera math.
-- Prefab skins do not call this path.
function Shared.bindResponsiveUi(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle)
	if skin.ResponsiveUi ~= true then
		return
	end
	local gui = skin.Gui
	local hotbar = skin.HotbarFrame
	if not gui or not hotbar then
		return
	end
	local geometry = trackGeometry(scope, gui, hotbar)

	local popup = skin.BackpackFrame
	if popup then
		local popupWidth = if popup.Size.X.Offset > 0 then popup.Size.X.Offset else POPUP_FALLBACK_WIDTH
		local popupHeight = if popup.Size.Y.Offset > 0 then popup.Size.Y.Offset else POPUP_FALLBACK_HEIGHT
		local topOverhang = skin.PopupTopOverhang or POPUP_DEFAULT_TOP_OVERHANG
		scope:Hydrate(popup) {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = scope:Computed(function(use: Fusion.Use): UDim2
				use(geometry)
				local guiPosition = gui.AbsolutePosition
				local guiSize = gui.AbsoluteSize
				local hotbarPosition = hotbar.AbsolutePosition
				local reserve = math.max(0, guiPosition.Y + guiSize.Y - hotbarPosition.Y) + POPUP_GAP
				return UDim2.new(0.5, 0, 1, -reserve)
			end),
			Size = scope:Computed(function(use: Fusion.Use): UDim2
				use(geometry)
				local guiPosition = gui.AbsolutePosition
				local guiSize = gui.AbsoluteSize
				local hotbarPosition = hotbar.AbsolutePosition
				local width = math.min(popupWidth, math.max(1, guiSize.X - POPUP_SIDE_MARGIN * 2))
				local available = math.max(1, hotbarPosition.Y - guiPosition.Y - POPUP_GAP - topOverhang)
				return UDim2.fromOffset(width, math.min(popupHeight, available))
			end),
		}
	end

	local toggle = skin.BackpackStuff
	if toggle then
		scope:Hydrate(toggle) {
			AnchorPoint = Vector2.new(0.5, 1),
			Size = scope:Computed(function(use: Fusion.Use): UDim2
				use(geometry)
				local size = math.clamp(getSlotSize(hotbar) * TOGGLE_SCALE, TOGGLE_MIN, TOGGLE_MAX)
				return UDim2.fromOffset(size, size)
			end),
			Position = scope:Computed(function(use: Fusion.Use): UDim2
				use(geometry)
				local guiPosition = gui.AbsolutePosition
				local guiSize = gui.AbsoluteSize
				local hotbarPosition = hotbar.AbsolutePosition
				local size = math.clamp(getSlotSize(hotbar) * TOGGLE_SCALE, TOGGLE_MIN, TOGGLE_MAX)
				local reserve = math.max(0, guiPosition.Y + guiSize.Y - hotbarPosition.Y) + TOGGLE_GAP
				local centerX = hotbarPosition.X + size / 2
				local offsetX = centerX - (guiPosition.X + guiSize.X / 2)
				return UDim2.new(0.5, offsetX, 1, -reserve)
			end),
		}
	end
end

function Shared.ensureDraggingGui(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle): ScreenGui
	local existingDragging = skin.DraggingGui
		or (skin.Gui and (skin.Gui:FindFirstChild("DraggingGui") :: ScreenGui?))
	if existingDragging then
		existingDragging.IgnoreGuiInset = false
		return existingDragging
	end
	local created = Instance.new("ScreenGui")
	created.Name = "DraggingGui"
	created.DisplayOrder = 100
	created.IgnoreGuiInset = false
	created.Parent = skin.Gui and skin.Gui.Parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	table.insert(scope, created)
	return created
end

-----------------------------
-- MAIN --
-----------------------------

return Shared
