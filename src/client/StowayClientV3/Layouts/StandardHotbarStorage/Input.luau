--!strict

--@author: yyumchi
--@date: 2026-09-09
--[[@description:
	StandardHotbarStorage input for KBM + Console. Modular per-layout:
	all IAS actions and PreferredInput wiring live here, parented to the
	LayoutScope so LayoutManager.Teardown wipes them atomically.

	Device matrix:
	  - Touch/Mobile: PointerDragService enabled, tap Activated equip,
	    backpack only (Tab+B PC path ignored, BackpackStuff tap).
	  - PC KeyboardAndMouse: drag+tap+direct 1..0 PC binds (sparse),
	    Tab+B backpack toggle + BackpackStuff Activated.
	    Console binds ignored on PC.
	  - Gamepad: drag disabled, tap stays, two console modes:
	    Mode1 Hotbar  -> console combos R1+X etc (equip)
	    Mode2 Inventory -> Y Swap, X Drop (server Drop request), R1+L1 QuickMove,
	                      B Cancel, DPadLeft backpack toggle,
	                      L3 long-press 0.5s toggles modes,
	                      GuiService.SelectedObject + custom
	                      SelectionCursor (slotbutton.SelectionImageObject).

	Sparse: if Binds.HotbarSlots[i]==nil that i gets no PC nor Console
	action even when MaxHotbarSlots covers it.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)

local Binds = require(script.Parent.Binds)
local Shared = require(script.Parent.Parent.Shared)
local ClientStore = require(script.Parent.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Parent.Controller.ClientController)
local PreferredInput = require(script.Parent.Parent.Parent.Interactions.PreferredInput)
local State = require(script.Parent.Parent.Parent.CoreStore.State)
local Query = require(script.Parent.Parent.Parent.CoreStore.Query)
local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)
local PointerDragService = require(script.Parent.Parent.Parent.Interactions.PointerDragService)

local Input = {}

local LONG_PRESS_SEC = 0.5

local function parseSelected(sel: GuiObject?): CoreTypes.SlotRef?
	if not sel then return nil end
	local frame = sel.Parent :: Instance?
	if not frame then return nil end
	local name: string = frame.Name
	local n = name:match("^Hotbar%-(%d+)$")
	local slot = n and tonumber(n)
	if slot then return { Type = "Hotbar", Slot = slot } end
	n = name:match("^Storage%-(%d+)$")
	slot = n and tonumber(n)
	if slot then return { Type = "Storage", Slot = slot } end
	return nil
end

local function getSelectedUUID(store: typeof(ClientStore), ref: CoreTypes.SlotRef?): string?
	if not ref then return nil end
	if ref.Type == "Hotbar" then
		local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
		return hotbar[ref.Slot]
	else
		local storage: { string } = Fusion.peek(store.Storage)
		return storage[ref.Slot]
	end
end

type BindingObject = Binds.BindingAction
type DragService = {
	SetEnabled: (self: DragService, enabled: boolean) -> (),
}

function Input.Mount(
	scope: Fusion.Scope<typeof(Fusion)>,
	skin: CoreTypes.SkinHandle,
	store: typeof(ClientStore),
	dragService: PointerDragService.Service?
)
	local actions: { BindingObject } = {}
	local inventoryActions: { BindingObject } = {}
	local pendingThreads: { thread } = {}

	local backpackAction: BindingObject? = nil
	local switchAction: BindingObject? = nil
	local switchHoldThread: thread? = nil

	local consoleMode: string = "Hotbar" -- "Hotbar" | "Inventory"
	local selectedRef: CoreTypes.SlotRef? = nil

	local function cleanupActions()
		for _, a in actions do
			pcall(function() a:Destroy() end)
		end
		table.clear(actions)
		for _, a in inventoryActions do
			pcall(function() a:Destroy() end)
		end
		table.clear(inventoryActions)

		-- No early return: PC/touch builds never set switchAction, and
		-- the actions below still need cleanup on every rebuild.
		if backpackAction ~= nil then
			backpackAction:Destroy(); backpackAction = nil
		end
		if switchAction ~= nil then
			switchAction:Destroy(); switchAction = nil
		end

		if switchHoldThread ~= nil then task.cancel(switchHoldThread); switchHoldThread = nil end

		for _, th in pendingThreads do task.cancel(th) end
		table.clear(pendingThreads)
		-- contexts
		pcall(function() IllusionIAS.removeContext("StowayGlobal") end)
		pcall(function() IllusionIAS.removeContext("StowayHotbar") end)
		pcall(function() IllusionIAS.removeContext("StowayInventory") end)
	end
	table.insert(scope, cleanupActions)

	PreferredInput.Init(scope)

	-- BackpackStuff tap (works on every input type)
	if skin.BackpackStuff then
		local btn = skin.BackpackStuff
		-- Mobile-only visibility: the prefab ships Visible=false and PC
		-- toggles with keys, so without this mobile has no way to open it.
		Shared.bindToggleVisible(scope, btn, store)
		local conn = btn.Activated:Connect(function()
			if not Shared.isBackpackEnabled(store) then return end
			local bf = skin.BackpackFrame
			if bf then bf.Visible = not bf.Visible end
		end)
		table.insert(scope, conn)
		table.insert(scope, function() if conn then conn:Disconnect() end end)
	end

	-- Apply SelectionCursor template to future slots. Actual per-slot assignment
	-- happens in HotbarView/StorageView via skin param; keep a helper here for
	-- dynamic cursor changes.
	local function applySelectionObjects()
		local cursor = skin.SelectionCursorTemplate
		if not cursor then return end
		local hotbarFrame = skin.HotbarFrame
		local scrolling = skin.ScrollingFrame
		local function applyTo(parent: Instance?)
			if not parent then return end
			for _, slotFrame in parent:GetChildren() do
				if slotFrame:IsA("Frame") then
					local btn = slotFrame:FindFirstChild("slotbutton")
					if btn and btn:IsA("GuiButton") then btn.SelectionImageObject = cursor end
				end
			end
		end
		applyTo(hotbarFrame)
		applyTo(scrolling)
	end
	local function toggleBackpackVisible()
		if not Shared.isBackpackEnabled(store) then return end
		local bf = skin.BackpackFrame
		if bf then bf.Visible = not bf.Visible end
	end

	local function enterInventoryMode()
		if consoleMode == "Inventory" then return end
		consoleMode = "Inventory"
		pcall(function() IllusionIAS.enableContext("StowayHotbar", false) end)
		pcall(function() IllusionIAS.enableContext("StowayInventory", true) end)
		if dragService ~= nil then dragService:SetEnabled(false) end
		local hotbarFrame = skin.HotbarFrame
		local scrolling = skin.ScrollingFrame
		if hotbarFrame then hotbarFrame.SelectionGroup = true end
		if scrolling then scrolling.SelectionGroup = true end
		GuiService.GuiNavigationEnabled = true
		GuiService.SelectedObject = nil
		task.defer(function()
			-- pick first slotbutton that actually holds an item: selecting
			-- an empty hotbar slot shows no mode indicator, so fall through
			-- to storage. Nothing selected at all when both are empty.
			local function firstFilled(parent: Instance?): GuiButton?
				if not parent then return nil end
				for _, child in parent:GetChildren() do
					if child:IsA("Frame") and child.Visible then
						local btn = child:FindFirstChild("slotbutton") :: GuiButton?
						if btn and btn.Visible and btn.Selectable ~= false then
							local ref = parseSelected(btn)
							if ref and getSelectedUUID(store, ref) ~= nil then
								return btn
							end
						end
					end
				end
				return nil
			end
			local pick = firstFilled(skin.HotbarFrame)
			if pick == nil and scrolling then
				pick = firstFilled(scrolling)
			end
			if pick ~= nil then
				GuiService.SelectedObject = pick
			end
		end)
	end

	local function enterHotbarMode()
		if consoleMode == "Hotbar" then return end
		consoleMode = "Hotbar"
		selectedRef = nil
		pcall(function() IllusionIAS.enableContext("StowayInventory", false) end)
		pcall(function() IllusionIAS.enableContext("StowayHotbar", true) end)
		if skin.HotbarFrame ~= nil then skin.HotbarFrame.SelectionGroup = false end
		if skin.ScrollingFrame then skin.ScrollingFrame.SelectionGroup = false end
		GuiService.SelectedObject = nil
		GuiService.GuiNavigationEnabled = false
	end

	local function buildForPreferred(pref: EnumItem)
		cleanupActions()
		applySelectionObjects()
		local isGamepad = pref == Enum.PreferredInput.Gamepad
		local isTouch = pref == Enum.PreferredInput.Touch

		-- Drag off on gamepad; tap + binds stay.
		if dragService ~= nil then
			dragService:SetEnabled(not isGamepad)
		end

		if isGamepad then
			-- contexts
			IllusionIAS.newContext("StowayGlobal")
			IllusionIAS.newContext("StowayHotbar")
			IllusionIAS.newContext("StowayInventory")
			-- Global backpack (gamepad DPadLeft)
			do
				local cfg = Binds.Global.Backpack
				if Shared.isBackpackEnabled(store) then
					local a: BindingObject = IllusionIAS.new("StowayBackpack")
					Binds.ApplyToAction(a, cfg, "Console")
					a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
						if not pressed then return end
						toggleBackpackVisible()
					end)
					IllusionIAS.addContext("StowayGlobal", a)
					backpackAction = a
					table.insert(actions, a)
				end
			end
			-- SwitchMode long-press L3
			do
				local cfg = Binds.Global.SwitchMode
				local a: BindingObject = IllusionIAS.new("StowaySwitchMode")
				Binds.ApplyToAction(a, cfg, "Console")
				a.Started:Connect(function()
					if switchHoldThread then task.cancel(switchHoldThread) end
					switchHoldThread = task.delay(LONG_PRESS_SEC, function()
						switchHoldThread = nil
						if consoleMode == "Hotbar" then enterInventoryMode() else enterHotbarMode() end
					end)
				end)
				a.Ended:Connect(function()
					if switchHoldThread then task.cancel(switchHoldThread); switchHoldThread = nil end
				end)
				IllusionIAS.addContext("StowayGlobal", a)
				switchAction = a
				table.insert(actions, a)
			end
			-- Hotbar direct binds (console combos)
			do
				local maxSlots = Shared.getMaxSlots(store)
				for i = 1, maxSlots do
					local cfg = Binds.HotbarSlots[i]
					if cfg == nil then continue end
					if cfg.Console == nil then continue end
					local a: BindingObject = IllusionIAS.new("StowaySlot" .. tostring(i))
					Binds.ApplyToAction(a, cfg, "Console")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					if consoleMode ~= "Hotbar" then return end
					if i > Shared.getMaxSlots(store) then return end
					Shared.doEquipSlot(store, i)
				end)
					IllusionIAS.addContext("StowayHotbar", a)
					table.insert(actions, a)
				end
			end
			-- Inventory actions (Y/X/R1+L1/B) – only while Inventory; gate on pressed
			do
				local inv = Binds.Global.InventoryActions
				local function mk(name: string, cfg: Binds.BindConfig?, fn: () -> ())
					local a: BindingObject = IllusionIAS.new(name)
					Binds.ApplyToAction(a, cfg, "Console")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
						if not pressed then return end
						fn()
					end)
					IllusionIAS.addContext("StowayInventory", a)
					table.insert(inventoryActions, a)
				end
				mk("StowaySwap", inv.Swap, function()
					local sel = GuiService.SelectedObject :: GuiObject?
					local cur = parseSelected(sel)
					if not cur then return end
					if not selectedRef then
						-- select source if it has item
						if getSelectedUUID(store, cur) then selectedRef = cur end
						return
					end
					-- second press -> swap source<->target
					local from = selectedRef; local to = cur
					if from and to and (from.Type ~= to.Type or from.Slot ~= to.Slot) then
						ClientController.Swap(from, to)
					end
					selectedRef = nil
				end)
			mk("StowayDrop", inv.Drop, function()
				local sel = GuiService.SelectedObject :: GuiObject?
				local cur = parseSelected(sel)
				local uuid = getSelectedUUID(store, cur)
				if uuid then ClientController.RequestDrop(uuid) end
				selectedRef = nil
			end)
				mk("StowayQuickMove", inv.QuickMove, function()
					local sel = GuiService.SelectedObject :: GuiObject?
					local cur = parseSelected(sel)
					local uuid = getSelectedUUID(store, cur)
					if not cur or not uuid then return end
					if cur.Type == "Hotbar" then
						if not Shared.isBackpackEnabled(store) then return end
						local storage: { string } = Fusion.peek(store.Storage)
						local dest = #storage + 1
						local to: CoreTypes.SlotRef = { Type = "Storage", Slot = dest }
						ClientController.Move(cur, to)
					else
						local hotbar: { [number]: string? } = Fusion.peek(store.Hotbar)
						local maxSlots2 = Shared.getMaxSlots(store)
						local dest: number? = nil
						for s = 1, maxSlots2 do if hotbar[s] == nil then dest = s; break end end
						if dest ~= nil then
							local to: CoreTypes.SlotRef = { Type = "Hotbar", Slot = dest }
							ClientController.Swap(cur, to)
						end
					end
					selectedRef = nil
				end)
				mk("StowayCancel", inv.Cancel, function()
					if selectedRef ~= nil then selectedRef = nil; return end
					-- if no source, keep mode but clear selection
					GuiService.SelectedObject = nil
				end)
			end
			-- Start in Hotbar mode.
			consoleMode = "Hotbar"
			IllusionIAS.enableContext("StowayHotbar", true)
			IllusionIAS.enableContext("StowayInventory", false)
			if skin.HotbarFrame then skin.HotbarFrame.SelectionGroup = false end
			if skin.ScrollingFrame then skin.ScrollingFrame.SelectionGroup = false end
			GuiService.GuiNavigationEnabled = false
			GuiService.SelectedObject = nil
		elseif isTouch then
			-- Touch: tap handled by the unconditional btn.Activated connection
			-- wired before buildForPreferred (raw GuiButton.Activated fires on
			-- tap, no hold). No IAS UIButton action needed here.
			GuiService.GuiNavigationEnabled = false
			GuiService.SelectedObject = nil
			if skin.HotbarFrame then skin.HotbarFrame.SelectionGroup = false end
			if skin.ScrollingFrame then skin.ScrollingFrame.SelectionGroup = false end
		else
			-- KeyboardAndMouse PC: direct 1..0 + Tab+B
			IllusionIAS.newContext("StowayGlobal")
			IllusionIAS.newContext("StowayHotbar")
			if Shared.isBackpackEnabled(store) then
				local cfg = Binds.Global.Backpack
				local a: BindingObject = IllusionIAS.new("StowayBackpack")
				Binds.ApplyToAction(a, cfg, "PC")
				a.Activated:Connect(function(_active: IllusionIAS.variant, pressed: boolean?)
					if not pressed then return end
					toggleBackpackVisible()
				end)
				IllusionIAS.addContext("StowayGlobal", a)
				backpackAction = a
				table.insert(actions, a)
				-- Also allow console backpack DPadLeft? Not on PC per spec, keep PC only.
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
				IllusionIAS.addContext("StowayHotbar", a)
				table.insert(actions, a)
			end
			GuiService.GuiNavigationEnabled = false
			GuiService.SelectedObject = nil
			if skin.HotbarFrame then skin.HotbarFrame.SelectionGroup = false end
			if skin.ScrollingFrame then skin.ScrollingFrame.SelectionGroup = false end
		end
	end

	-- Rebuild binds when MaxHotbarSlots or BackpackEnabled changes (settings replicate now):
	-- actions for slots beyond a shrunk max would otherwise linger and keep
	-- equipping hidden slots, and backpack binds must sync dynamically.
	local liveBindsTrigger = scope:Computed(function(use: Fusion.Use): string
		local settings: CoreTypes.Settings? = use(store.Settings)
		local maxSlots = State.getMaxHotbarSlots(settings)
		local backpack = settings == nil or settings.BackpackEnabled ~= false
		return `{maxSlots}:{backpack}`
	end)
	scope:Observer(liveBindsTrigger):onChange(function()
		buildForPreferred(PreferredInput.Get())
	end)

	-- initial
	buildForPreferred(PreferredInput.Get())

	local prefConn = PreferredInput.Changed:Connect(function(newPref: EnumItem)
		buildForPreferred(newPref)
		applySelectionObjects()
	end)
	table.insert(scope, function()
		if prefConn ~= nil then prefConn:Disconnect() end
	end)

	-- also apply cursor after views built (defer one frame)
	task.defer(applySelectionObjects)
end

return Input
