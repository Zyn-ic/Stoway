--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	JailbreakHotbar input. Lean by design: direct 1..10 equip binds
	(PC + console) and the storage popup toggle (BackpackStuff button,
	Tab/B, DPadLeft). Tap-to-equip on slots is owned by SlotView.
	Sweep/paint-swap binds arrive in the logic pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)

local Binds = require(script.Parent.Binds)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Parent.Controller.ClientController)
local State = require(script.Parent.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)

local Input = {}

local function getMaxSlots(store: typeof(ClientStore)): number
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return State.getMaxHotbarSlots(settings)
end

local function isBackpackEnabled(store: typeof(ClientStore)): boolean
	local s: CoreTypes.Settings? = Fusion.peek(store.Settings)
	return s == nil or s.BackpackEnabled ~= false
end

local function doEquipSlot(store: typeof(ClientStore), visibleIndex: number)
	local settings: CoreTypes.Settings? = Fusion.peek(store.Settings)
	local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
	local items: { [string]: CoreTypes.Item } = Fusion.peek(store.Items)
	local hotbarType = if settings then settings.HotbarType else "Static"
	local uuid: string?
	if hotbarType == "Dynamic" then
		-- visibleIndex 1.. is packOrder; map to actual slot uuid
		for slot = 1, getMaxSlots(store) do
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

type BindingObject = Binds.BindingAction

function Input.Mount(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	storageOpen: Fusion.Value<boolean>
)
	local actions: { BindingObject } = {}

	local function cleanupActions()
		for _, a in actions do
			pcall(function() a:Destroy() end)
		end
		table.clear(actions)
		pcall(function() IllusionIAS.removeContext("StowayJailbreak") end)
	end
	table.insert(scope, cleanupActions)

	local function toggleStorage()
		if not isBackpackEnabled(store) then return end
		storageOpen:set(not Fusion.peek(storageOpen))
	end

	if skin.BackpackStuff then
		local btn = skin.BackpackStuff
		-- Hotbar-only mode hides the toggle outright; the bind handler
		-- below gates the same way so a settings flip can't leak through.
		scope:Hydrate(btn) {
			Visible = scope:Computed(function(use: Fusion.Use): boolean
				local s: CoreTypes.Settings? = use(store.Settings)
				return s == nil or s.BackpackEnabled ~= false
			end),
		}
		local conn = btn.Activated:Connect(toggleStorage)
		table.insert(scope, conn)
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end

	local function buildBinds()
		cleanupActions()
		IllusionIAS.newContext("StowayJailbreak")

		do
			local a: BindingObject = IllusionIAS.new("StowayBackpack")
			Binds.ApplyToAction(a, Binds.Global.Backpack)
			a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
				if not pressed then return end
				toggleStorage()
			end)
			IllusionIAS.addContext("StowayJailbreak", a)
			table.insert(actions, a)
		end

		local maxSlots = getMaxSlots(store)
		for i = 1, maxSlots do
			local cfg = Binds.HotbarSlots[i]
			if cfg == nil then continue end
			local a: BindingObject = IllusionIAS.new("StowaySlot" .. tostring(i))
			Binds.ApplyToAction(a, cfg)
			a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
				if not pressed then return end
				if i > getMaxSlots(store) then return end
				doEquipSlot(store, i)
			end)
			IllusionIAS.addContext("StowayJailbreak", a)
			table.insert(actions, a)
		end
	end

	-- Rebuild binds when MaxHotbarSlots changes so shrunk slots lose
	-- their binds instead of equipping hidden slots.
	local liveMaxSlots = scope:Computed(function(use: Fusion.Use): number
		local settings: CoreTypes.Settings? = use(store.Settings)
		return State.getMaxHotbarSlots(settings)
	end)
	scope:Observer(liveMaxSlots):onChange(buildBinds)

	buildBinds()
end

return Input
