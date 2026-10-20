--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	JailbreakHotbar layout. Circular bottom hotbar + centered storage
	popup. Paint-to-move sweep (no ghost): press an item, draw across
	slots, each crossing swaps/moves live; release ends the stroke.
	Tap (no crossing) equips.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local ClientEvents = require(script.Parent.Parent.Controller.ClientEvents)
local PointerDragService = require(script.Parent.Parent.Interactions.PointerDragService)

local HotbarView = require(script.HotbarView)
local StorageView = require(script.StorageView)
local LayoutInput = require(script.Input)
local Shared = require(script.Parent.Shared)

local JailbreakHotbar = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local POP_UP = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_DOWN = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_SCALE = 1.22

-- Little jump on swap: punch the slot's UIScale up and back. Plain
-- TweenService (no Fusion objects per event, nothing to leak); the
-- Parent check covers teardown mid-flight.
local function popSlot(container: Instance?, slotType: CoreTypes.SlotType, slot: number)
	if not container then return end
	local frame = container:FindFirstChild(slotType .. "-" .. tostring(slot)) :: Frame?
	local uiScale = frame and frame:FindFirstChildOfClass("UIScale") :: UIScale?
	if not uiScale then return end
	uiScale.Scale = 1
	TweenService:Create(uiScale, POP_UP, { Scale = POP_SCALE }):Play()
	task.delay(0.12, function()
		if uiScale.Parent then
			TweenService:Create(uiScale, POP_DOWN, { Scale = 1 }):Play()
		end
	end)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function JailbreakHotbar.Mount(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	-- Popup visibility is layout-local: hotbar-only mode keeps no
	-- persistent storage panel, the toggle opens the centered popup.
	local storageOpen: Fusion.Value<boolean> = scope:Value(false)

	local draggingGui = Shared.ensureDraggingGui(scope, skin)

	-- Per-crossing commit for the sweep. Occupied -> Swap, empty -> Move
	-- (Static falls back to Swap on DESTINATION_UNAVAILABLE, same rule as
	-- Standard). Returns whether anything applied: only applied crossings
	-- advance the ripple. Release-outside never reaches here (cancel).
	local function commitCrossing(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef?): boolean
		if not to then return false end
		if from.Type == to.Type and from.Slot == to.Slot then return false end
		local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
		local backpackEnabled = settings == nil or settings.BackpackEnabled ~= false
		if not backpackEnabled then
			if from.Type == "Storage" or (to and to.Type == "Storage") then return false end
		end
		local hotbarType: CoreTypes.HotbarType = if settings then settings.HotbarType else "Static"
		if Shared.hasDestItem(store, to) then
			return Shared.handleSwap(from, to)
		end
		local res = ClientController.Move(from, to)
		if not res.ok then
			Log.warn(store.GetSettings(), "[JailbreakHotbar] Move rejected", res.error and res.error.message or tostring(res))
			if res.error and res.error.message == "DESTINATION_UNAVAILABLE" then
				if hotbarType == "Static" then return Shared.handleSwap(from, to) end
			end
			return false
		end
		return true
	end

	local dragService = PointerDragService.new(
		scope,
		draggingGui,
		commitCrossing,
		skin.SlotTemplate,
		skin.BackpackFrame,
		skin.HotbarFrame,
		skin.GhostHidden,
		skin.Hooks
	)
	-- Sweep mode: arm on threshold (no ghost), commit per crossing.
	dragService:SetSweepEnabled(true)
	-- Sweeps start on filled slots only; empty presses fall to tap.
	dragService:SetSweepCanBegin(function(ref: CoreTypes.SlotRef): boolean
		return Shared.hasDestItem(store, ref)
	end)

	-- Skin hooks: Jailbreak (code-built) carries none, so this is nil
	-- there; Persona ships its own Hooks table on the handle. Set here so
	-- the controller's state hooks (Equip/Unequip/Add/Remove/Swap) fire.
	-- Teardown clears it again.
	ClientController.SetHooks(skin.Hooks)

	-- Swap-pop: both endpoints jump on every committed swap (each ripple
	-- crossing included). Scoped to the mount; teardown disconnects.
	local swapConn = ClientEvents.Swapped:Connect(function(
		fromType: CoreTypes.SlotType,
		fromSlot: number,
		toType: CoreTypes.SlotType,
		toSlot: number
	)
		local function containerFor(slotType: CoreTypes.SlotType): Instance?
			if slotType == "Hotbar" then
				return skin.HotbarFrame
			end
			return skin.ScrollingFrame
		end
		popSlot(containerFor(fromType), fromType, fromSlot)
		popSlot(containerFor(toType), toType, toSlot)
	end)
	table.insert(scope, function()
		if swapConn and swapConn.Disconnect then swapConn:Disconnect() end
	end)

	HotbarView.Create(scope, skin, store, dragService)
	StorageView.Create(scope, skin, store, storageOpen, dragService)
	LayoutInput.Mount(scope, skin, store, storageOpen)
end

-----------------------------
-- MAIN --
-----------------------------

return JailbreakHotbar
