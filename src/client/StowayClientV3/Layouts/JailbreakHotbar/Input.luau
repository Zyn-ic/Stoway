--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	JailbreakHotbar input. Lean by design: per-device binds rebuilt on
	PreferredInput change (PC number row, console R1/L1 combos, touch
	tap-to-equip via SlotView + BackpackStuff UIButton). Storage popup
	toggle: BackpackStuff button (mobile-only), Tab/B, DPadLeft.
	Sweep/paint-swap binds arrive in the logic pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)

local Binds = require(script.Parent.Binds)
local Shared = require(script.Parent.Parent.Shared)
local PreferredInput = require(script.Parent.Parent.Parent.Interactions.PreferredInput)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Parent.Controller.ClientController)
local State = require(script.Parent.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)

local Input = {}

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

	PreferredInput.Init(scope)

	local function toggleStorage()
		if not Shared.isBackpackEnabled(store) then return end
		storageOpen:set(not Fusion.peek(storageOpen))
	end

	if skin.BackpackStuff then
		local btn = skin.BackpackStuff
		-- Mobile-only visibility lives in Shared; the bind handlers below
		-- gate the same way so a settings flip can't leak through.
		Shared.bindToggleVisible(scope, btn, store)
		local conn = btn.Activated:Connect(toggleStorage)
		table.insert(scope, conn)
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end

	local function buildForPreferred(pref: EnumItem)
		cleanupActions()
		IllusionIAS.newContext("StowayJailbreak")
		local isGamepad = pref == Enum.PreferredInput.Gamepad
		local isTouch = pref == Enum.PreferredInput.Touch

		if isTouch then
			-- Touch: tap handled by the unconditional btn.Activated connection
			-- above (raw GuiButton.Activated fires on tap, no hold). No IAS
			-- UIButton action needed; skip to avoid any hold-to-fire behavior.
		elseif isGamepad then
			-- Console combos only; PC number row stays off.
			if Shared.isBackpackEnabled(store) then
				local a: BindingObject = IllusionIAS.new("StowayBackpack")
				Binds.ApplyToAction(a, Binds.Global.Backpack, "Console")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					toggleStorage()
				end)
				IllusionIAS.addContext("StowayJailbreak", a)
				table.insert(actions, a)
			end
			local maxSlots = Shared.getMaxSlots(store)
			for i = 1, maxSlots do
				local cfg = Binds.HotbarSlots[i]
				if cfg == nil then continue end
				if cfg.Console == nil then continue end
				local a: BindingObject = IllusionIAS.new("StowaySlot" .. tostring(i))
				Binds.ApplyToAction(a, cfg, "Console")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					if i > Shared.getMaxSlots(store) then return end
					Shared.doEquipSlot(store, i)
				end)
				IllusionIAS.addContext("StowayJailbreak", a)
				table.insert(actions, a)
			end
		else
			-- KeyboardAndMouse PC: direct 1..0 + Tab/B. Console combos off.
			if Shared.isBackpackEnabled(store) then
				local a: BindingObject = IllusionIAS.new("StowayBackpack")
				Binds.ApplyToAction(a, Binds.Global.Backpack, "PC")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					toggleStorage()
				end)
				IllusionIAS.addContext("StowayJailbreak", a)
				table.insert(actions, a)
			end
			local maxSlots = Shared.getMaxSlots(store)
			for i = 1, maxSlots do
				local cfg = Binds.HotbarSlots[i]
				if cfg == nil then continue end
				if cfg.PC == nil then continue end
				local a: BindingObject = IllusionIAS.new("StowaySlot" .. tostring(i))
				Binds.ApplyToAction(a, cfg, "PC")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					if i > Shared.getMaxSlots(store) then return end
					Shared.doEquipSlot(store, i)
				end)
				IllusionIAS.addContext("StowayJailbreak", a)
				table.insert(actions, a)
			end
		end
	end

	-- Rebuild binds when MaxHotbarSlots or BackpackEnabled changes so shrunk
	-- slots lose their binds and backpack binds update dynamically.
	local liveBindsTrigger = scope:Computed(function(use: Fusion.Use): string
		local settings: CoreTypes.Settings? = use(store.Settings)
		local maxSlots = State.getMaxHotbarSlots(settings)
		local backpack = settings == nil or settings.BackpackEnabled ~= false
		return `{maxSlots}:{backpack}`
	end)
	scope:Observer(liveBindsTrigger):onChange(function()
		buildForPreferred(PreferredInput.Get())
	end)

	-- initial + per-device rebuilds (same switching as Standard).
	buildForPreferred(PreferredInput.Get())

	local prefConn = PreferredInput.Changed:Connect(function(newPref: EnumItem)
		buildForPreferred(newPref)
	end)
	table.insert(scope, function()
		if prefConn ~= nil then prefConn:Disconnect() end
	end)
end

return Input
