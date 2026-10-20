--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Conch debug console commands for StowayServerV3_0_0. Replaces the
	legacy chat commands (deleted): same Stoway facade calls, typed
	arguments with autocomplete, output via conch.log back into the
	console UI. All commands act on the CALLER (no player targeting).

	Boot owner for the server conch lifecycle: RegisterAll runs
	lifecycle -> role -> registers -> grants, in that order, once.
	Dev-only: every joining player gets the debug role.
]]
-----------------------------
-- DEPENDENCIES --
-----------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreStore = require(ReplicatedStorage.Shared.Stoway.CoreStore)
local Types = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)
local SharedSettings = require(ReplicatedStorage.Shared.Stoway.Settings)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

-- Untyped boundary (intentional): the Conch package ships without Luau
-- declarations, so one any-binding covers the whole seam. Everything
-- past it (handlers, state access, validation) stays fully typed.
local conch: any = require(ReplicatedStorage.Packages.conch)

-----------------------------
-- VARIABLES --
-----------------------------

-- Single surface: Protocol.StowayApi (this copy was missing SwapStack).
local Protocol = require(script.Parent.Parent.Protocol)
type StowayApi = Protocol.StowayApi

-- Single debug role/permission (dev console parity with legacy chat:
-- everyone who joins can use it). Lock down by granting selectively.
local DEBUG_ROLE = "stoway-debug"
local DEBUG_PERM = "stoway-debug"

local ConchCommands = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- The calling player behind this command invocation. Conch does not
-- pass the caller positionally; executor.player is false for console
-- users, so narrow before touching player-scoped state.
local function caller(): Player?
	local ctx: any = conch.get_command_context()
	local exec: any = ctx and ctx.executor
	local p: any = exec and exec.player
	if typeof(p) == "Instance" and p:IsA("Player") then
		return p :: Player
	end
	return nil
end

local function withCaller(stoway: StowayApi, fn: (Player) -> ())
	local player = caller()
	if not player then
		conch.log("error", "No player behind this command.")
		return
	end
	if not stoway.get(player) then
		conch.log("error", ("No inventory state for %s."):format(player.Name))
		return
	end
	fn(player)
end

-- Literal branches (not a cast table): the old solver matches fresh
-- literals exactly, so each arm returns a precise SlotRef shape.
local function makeSlotRef(rawType: unknown, rawSlot: unknown): Types.SlotRef?
	local slot = if typeof(rawSlot) == "number" then rawSlot :: number else nil
	if not slot or slot < 1 or slot ~= math.floor(slot) then
		return nil
	end
	if typeof(rawType) ~= "string" then return nil end
	local normalized = (rawType :: string):sub(1, 1):upper() .. (rawType :: string):sub(2):lower()
	if normalized == "Hotbar" then
		return { Type = "Hotbar", Slot = slot }
	elseif normalized == "Storage" then
		return { Type = "Storage", Slot = slot }
	end
	return nil
end

local function asCount(raw: unknown, default: number): number
	if typeof(raw) == "number" then
		return raw :: number
	end
	return default
end

local SLOT_TYPES = { "Hotbar", "Storage" }
local UUID_QUOTE_HINT = "quotes required, UUIDs contain dots"

-- static_enum_from_array is curried: it returns a registrator that still
-- needs (name, desc). Forgetting the second call hands register a
-- function, which dies in analysis ("index function with 'kind'").
local function slotTypeArg(name: string, desc: string): any
	return conch.args.static_enum_from_array(SLOT_TYPES)(name, desc)
end

-- Conch's language parser treats an unquoted dot as syntax, and generated
-- UUIDs include an os.clock() decimal. Quote every UUID argument or the
-- token is silently truncated at the dot.
local function uuidArg(): any
	return conch.args.string("uuid", "Item UUID in quotes")
end

local function normalizeSkin(raw: unknown): string?
	if typeof(raw) ~= "string" then return nil end
	local normalized = (raw :: string):sub(1, 1):upper() .. (raw :: string):sub(2):lower()
	if normalized == "Default" or normalized == "Modern" or normalized == "Metal" or normalized == "Jailbreak" or normalized == "Persona" then
		return normalized
	end
	return nil
end

local function normalizeLayout(raw: unknown): string?
	if raw == "StandardHotbarStorage" or raw == "JailbreakHotbar" then
		return raw :: string
	end
	return nil
end

local function sendLayout(player: Player, layout: string, skin: string)
	Remotes.LayoutChanged:FireClient(player, {
		layout = layout,
		skin = skin,
	})
	conch.log("success", ("UI layout changed to %s / %s"):format(layout, skin))
end

local function normalizeTeam(raw: unknown): string?
	if typeof(raw) ~= "string" then return nil end
	local lowered = string.lower(raw :: string)
	if lowered == "criminal" then
		return "Criminal"
	elseif lowered == "cop" or lowered == "police" then
		return "Police"
	elseif lowered == "prison" or lowered == "prisoner" then
		return "Prisoner"
	end
	return nil
end

local function logAddResult(label: string, target: string, result: any)
	conch.log("info", ("[%s] %s"):format(label, target))
	if result.ok then
		conch.log("success", "  Success: true")
		conch.log("info", ("  Added: %s"):format(tostring(result.value.addedAmount or 0)))
		conch.log("info", ("  Overflow: %s"):format(tostring(result.value.overflow or 0)))
	else
		conch.log("error", "  Success: false")
		conch.log("error", ("  Reason: %s"):format(result.error.message))
	end
end

-- Prints UUIDs pre-quoted so `inv` output can be copied straight into
-- remove/drop/split/equip without hitting the console's dot tokenizer.
local function quoteUUID(uuid: string?): string
	if uuid == nil or uuid == "" then return "None" end
	return `"{uuid}"`
end

-- A dotless UUID is almost always an unquoted UUID the parser cut at the
-- os.clock() decimal. Point the user at the quoted form instead of leaving
-- them with a bare ITEM_NOT_FOUND.
local function maybeHintUuid(uuid: string, reason: string)
	if reason == "ITEM_NOT_FOUND" and not string.find(uuid, ".", 1, true) then
		conch.log("info", "  Hint: UUIDs contain dots; copy the quoted UUID from inv.")
	end
end

-----------------------------
-- COMMANDS --
-----------------------------

local function registerAll(stoway: StowayApi)
	local P = { DEBUG_PERM }

	conch.register("inv", {
		description = "Display your inventory state",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				conch.log("info", ("INVENTORY for %s"):format(player.Name))
				conch.log("info", ("Weight: %d / %d (0 = Infinite)"):format(state.Weight, state.Settings.Limit))
				conch.log("info", ("CanStack: %s | MaxStack: %d"):format(tostring(state.Settings.CanStack), state.Settings.MaxStackSize))
				conch.log("info", ("HotbarType: %s | Sorting: %s"):format(state.Settings.HotbarType, tostring(state.Settings.Sorting)))
				conch.log("info", ("Equipped UUID: %s"):format(quoteUUID(state.EquippedItemUUID)))
				conch.log("info", ("HOTBAR (max %d):"):format(state.Settings.MaxHotbarSlots))
				for i = 1, state.Settings.MaxHotbarSlots do
					local uuid = state.Hotbar[i]
					if uuid then
						local item = state.Items[uuid]
						if item then
							conch.log("info", ("  [%d] %s x%d (UUID: %s)"):format(i, item.Id, item.Amount, quoteUUID(uuid)))
						else
							conch.log("warn", ("  [%d] (ORPHAN UUID: %s)"):format(i, quoteUUID(uuid)))
						end
					else
						conch.log("info", ("  [%d] (empty)"):format(i))
					end
				end
				conch.log("info", ("STORAGE: #%d"):format(#state.Storage))
				for i, uuid in ipairs(state.Storage) do
					local item = state.Items[uuid]
					if item then
						conch.log("info", ("  [%d] %s x%d (UUID: %s)"):format(i, item.Id, item.Amount, quoteUUID(uuid)))
					else
						conch.log("warn", ("  [%d] (ORPHAN UUID: %s)"):format(i, quoteUUID(uuid)))
					end
				end
			end)
		end,
	})

	conch.register("add", {
		description = "Add item (auto placement): add <id> [amount]",
		permissions = P,
		arguments = function()
			return conch.args.string("id", "Item id"),
				conch.args.opt(conch.args.number("amount", "How many"))
		end,
		callback = function(itemId: string, amount: number?)
			withCaller(stoway, function(player: Player)
				if not itemId or itemId == "" then
					conch.log("error", "Usage: add <id> [amount]")
					return
				end
				local n = asCount(amount, 1)
				local result = stoway.AddItem(player, { Id = itemId, Amount = n }, nil, true)
				logAddResult("Add", ("%s x%d"):format(itemId, n), result)
			end)
		end,
	})

	conch.register("addback", {
		description = "Add directly to backpack: addback <id> [amount]",
		permissions = P,
		arguments = function()
			return conch.args.string("id", "Item id"),
				conch.args.opt(conch.args.number("amount", "How many"))
		end,
		callback = function(itemId: string, amount: number?)
			withCaller(stoway, function(player: Player)
				if not itemId or itemId == "" then
					conch.log("error", "Usage: addback <id> [amount]")
					return
				end
				local n = asCount(amount, 1)
				local result = stoway.AddToBackpack(player, { Id = itemId, Amount = n }, nil, true)
				logAddResult("AddToBackpack", ("%s x%d"):format(itemId, n), result)
			end)
		end,
	})

	conch.register("addhot", {
		description = "Add directly to hotbar: addhot <id> [amount] [slot]",
		permissions = P,
		arguments = function()
			return conch.args.string("id", "Item id"),
				conch.args.opt(conch.args.number("amount", "How many")),
				conch.args.opt(conch.args.number("slot", "Preferred slot"))
		end,
		callback = function(itemId: string, amount: number?, slot: number?)
			withCaller(stoway, function(player: Player)
				if not itemId or itemId == "" then
					conch.log("error", "Usage: addhot <id> [amount] [slot]")
					return
				end
				local n = asCount(amount, 1)
				local s: number? = if typeof(slot) == "number" then slot :: number else nil
				local result = stoway.AddToHotbar(player, { Id = itemId, Amount = n }, s, true)
				logAddResult("AddToHotbar", ("%s x%d%s"):format(itemId, n, if s then (" @slot " .. s) else ""), result)
			end)
		end,
	})

	conch.register("remove", {
		description = "Remove item by UUID (quote it!): remove \"uuid\" [amount]",
		permissions = P,
		arguments = function()
			return uuidArg(), conch.args.opt(conch.args.number("amount", "How many"))
		end,
		callback = function(uuid: string, amount: number?)
			withCaller(stoway, function(player: Player)
				if not uuid or uuid == "" then
					conch.log("error", `Usage: remove "uuid" [amount] ({UUID_QUOTE_HINT})`)
					return
				end
				local a: number? = if typeof(amount) == "number" then amount :: number else nil
				local result = stoway.RemoveItem(player, uuid, a, true)
				conch.log("info", ("[Remove] %s"):format(quoteUUID(uuid)))
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  Remaining: %s"):format(tostring(result.value.remaining or 0)))
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
					maybeHintUuid(uuid, result.error.message)
				end
			end)
		end,
	})

	conch.register("drop", {
		description = "Drop item into the world (quote UUID): drop \"uuid\" [amount]",
		permissions = P,
		arguments = function()
			return uuidArg(), conch.args.opt(conch.args.number("amount", "How many"))
		end,
		callback = function(uuid: string, amount: number?)
			withCaller(stoway, function(player: Player)
				if not uuid or uuid == "" then
					conch.log("error", `Usage: drop "uuid" [amount] ({UUID_QUOTE_HINT})`)
					return
				end
				local a: number? = if typeof(amount) == "number" then amount :: number else nil
				local result = stoway.Drop(player, uuid, a, true)
				conch.log("info", ("[Drop] %s"):format(quoteUUID(uuid)))
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  Dropped: %s"):format(tostring(result.value.removedItem.Amount or 0)))
					conch.log("info", ("  Remaining: %s"):format(tostring(result.value.remaining or 0)))
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
					maybeHintUuid(uuid, result.error.message)
				end
			end)
		end,
	})

	conch.register("swap", {
		description = "Swap two slots: swap <type> <slot> <type> <slot>",
		permissions = P,
		arguments = function()
			return slotTypeArg("from-type", "Hotbar or Storage"),
				conch.args.number("from-slot", "Source slot"),
				slotTypeArg("to-type", "Hotbar or Storage"),
				conch.args.number("to-slot", "Target slot")
		end,
		callback = function(fromType: string, fromSlot: number, toType: string, toSlot: number)
			withCaller(stoway, function(player: Player)
				local from = makeSlotRef(fromType, fromSlot)
				local to = makeSlotRef(toType, toSlot)
				if not (from and to) then
					conch.log("error", "Usage: swap <Hotbar|Storage> <slot> <Hotbar|Storage> <slot>")
					return
				end
				local result = stoway.SwapSlots(player, from, to, true)
				conch.log("info", ("[Swap] %s %d -> %s %d"):format(from.Type, from.Slot, to.Type, to.Slot))
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  HotbarCompacted: %s"):format(tostring(result.value.hotbarCompacted or false)))
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
				end
			end)
		end,
	})

	conch.register("move", {
		description = "Move item to slot (never stacks): move <type> <slot> <type> <slot>",
		permissions = P,
		arguments = function()
			return slotTypeArg("from-type", "Hotbar or Storage"),
				conch.args.number("from-slot", "Source slot"),
				slotTypeArg("to-type", "Hotbar or Storage"),
				conch.args.number("to-slot", "Target slot")
		end,
		callback = function(fromType: string, fromSlot: number, toType: string, toSlot: number)
			withCaller(stoway, function(player: Player)
				local from = makeSlotRef(fromType, fromSlot)
				local to = makeSlotRef(toType, toSlot)
				if not (from and to) then
					conch.log("error", "Usage: move <Hotbar|Storage> <slot> <Hotbar|Storage> <slot>")
					return
				end
				local result = stoway.Move(player, from, to, true)
				conch.log("info", ("[Move] %s %d -> %s %d"):format(from.Type, from.Slot, to.Type, to.Slot))
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  HotbarCompacted: %s"):format(tostring(result.value.hotbarCompacted or false)))
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
				end
			end)
		end,
	})

	conch.register("split", {
		description = "Split a stack (quote UUID): split \"uuid\" <amount> [type] [slot]",
		permissions = P,
		arguments = function()
			return uuidArg(),
				conch.args.number("amount", "How many"),
				conch.args.opt(slotTypeArg("dest-type", "Hotbar or Storage")),
				conch.args.opt(conch.args.number("dest-slot", "Target slot"))
		end,
		callback = function(uuid: string, amount: number, destType: unknown, destSlot: unknown)
			withCaller(stoway, function(player: Player)
				if not uuid or uuid == "" or typeof(amount) ~= "number" then
					conch.log("error", `Usage: split "uuid" <amount> [Hotbar|Storage] [slot] ({UUID_QUOTE_HINT})`)
					return
				end
				local destination: Types.SlotRef? = nil
				if destType ~= nil then
					destination = makeSlotRef(destType, destSlot)
					if not destination then
						conch.log("error", `Usage: split "uuid" <amount> [Hotbar|Storage] [slot] ({UUID_QUOTE_HINT})`)
						return
					end
				end
				local result = stoway.Split(player, uuid, amount :: number, destination, true)
				conch.log("info", ("[Split] %s x%d"):format(quoteUUID(uuid), amount))
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  New UUID: %s"):format(quoteUUID(tostring(result.value.newUUID or ""))))
					conch.log("info", ("  New Amount: %s"):format(tostring(result.value.newAmount or 0)))
					if result.value.newSlotType and result.value.newSlot then
						conch.log("info", ("  Destination: %s %s"):format(tostring(result.value.newSlotType), tostring(result.value.newSlot)))
					end
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
					maybeHintUuid(uuid, result.error.message)
				end
			end)
		end,
	})

	-- Shared equip reporter. UUIDs carry a dot from os.clock(), so the console
	-- language truncates them unquoted: equip "full-uuid". Prefer equip-slot.
	local function reportEquip(stoway: StowayApi, player: Player, uuid: string)
		local result = stoway.EquipSlot(player, uuid, true)
		conch.log("info", ("[Equip] %s"):format(quoteUUID(uuid)))
		if result.ok then
			conch.log("success", "  Success: true")
			conch.log("info", ("  Equipped UUID: %s"):format(quoteUUID(tostring(result.value.uuid or ""))))
			conch.log("info", ("  Previous: %s"):format(quoteUUID(tostring(result.value.previousUUID or ""))))
		else
			conch.log("error", "  Success: false")
			conch.log("error", ("  Reason: %s"):format(result.error.message))
			maybeHintUuid(uuid, result.error.message)
		end
	end

	conch.register("equip", {
		description = "Equip item by UUID (quote it!): equip \"uuid\"",
		permissions = P,
		arguments = function()
			return uuidArg()
		end,
		callback = function(uuid: string)
			withCaller(stoway, function(player: Player)
				if not uuid or uuid == "" then
					conch.log("error", `Usage: equip "uuid" ({UUID_QUOTE_HINT})`)
					return
				end
				reportEquip(stoway, player, uuid)
			end)
		end,
	})

	conch.register("equip-slot", {
		description = "Equip the item in a slot: equip-slot <type> <slot>",
		permissions = P,
		arguments = function()
			return slotTypeArg("type", "Hotbar or Storage"),
				conch.args.number("slot", "Slot number")
		end,
		callback = function(rawType: unknown, rawSlot: unknown)
			withCaller(stoway, function(player: Player)
				local ref = makeSlotRef(rawType, rawSlot)
				if not ref then
					conch.log("error", "Usage: equip-slot <Hotbar|Storage> <slot>")
					return
				end
				local state = stoway.get(player) :: Types.InventoryState
				local uuid = if ref.Type == "Hotbar"
					then state.Hotbar[ref.Slot]
					else state.Storage[ref.Slot]
				if not uuid then
					conch.log("error", ("[Equip] %s %d is empty"):format(ref.Type, ref.Slot))
					return
				end
				reportEquip(stoway, player, uuid)
			end)
		end,
	})

	conch.register("unequip", {
		description = "Unequip current item",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local result = stoway.UnequipSlot(player, true)
				conch.log("info", "[Unequip]")
				if result.ok then
					conch.log("info", ("  Previous UUID: %s"):format(quoteUUID(tostring(result.value.previousUUID or ""))))
				else
					conch.log("error", ("  Reason: %s"):format(result.error.message))
				end
			end)
		end,
	})

	conch.register("sort", {
		description = "Sort storage",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local result = stoway.Sort(player, true)
				conch.log("info", "[Sort]")
				if result.ok then
					conch.log("success", "  Success: true")
					conch.log("info", ("  Storage Order: %s"):format(result.value.storageOrder and ("#" .. #result.value.storageOrder) or "?"))
				else
					conch.log("error", "  Success: false")
					conch.log("error", ("  Reason: %s"):format(result.error.message))
				end
			end)
		end,
	})

	conch.register("clear-inv", {
		description = "Clear inventory (console `clear` is conch's own)",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player)
				if not state then return end
				local uuids: { string } = {}
				for uuid in state.Items do
					table.insert(uuids, uuid)
				end
				for _, uuid in uuids do
					stoway.RemoveItem(player, uuid, nil, true)
				end
				conch.log("success", ("[Clear] removed %d item(s)"):format(#uuids))
			end)
		end,
	})

	conch.register("toggle-stack", {
		description = "Toggle stacking on/off",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.CanStack = not state.Settings.CanStack
				conch.log("info", ("[Settings] CanStack: %s"):format(tostring(state.Settings.CanStack)))
				Remotes.SettingsChanged:FireClient(player, { CanStack = state.Settings.CanStack })
			end)
		end,
	})

	conch.register("toggle-limit", {
		description = "Toggle limit (0=infinite / 15)",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.Limit = if state.Settings.Limit == 0 then 15 else 0
				conch.log("info", ("[Settings] Limit: %d (0 = Infinite)"):format(state.Settings.Limit))
				Remotes.SettingsChanged:FireClient(player, { Limit = state.Settings.Limit })
			end)
		end,
	})

	conch.register("toggle-backpack", {
		description = "Toggle backpack on/off",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.BackpackEnabled = not state.Settings.BackpackEnabled
				conch.log("info", ("[Settings] BackpackEnabled: %s"):format(tostring(state.Settings.BackpackEnabled)))
				Remotes.SettingsChanged:FireClient(player, { BackpackEnabled = state.Settings.BackpackEnabled })
			end)
		end,
	})

	conch.register("set-backpack", {
		description = "Set backpack enabled: set-backpack <true|false>",
		permissions = P,
		arguments = function()
			return conch.args.boolean("enabled", "Backpack enabled")
		end,
		callback = function(enabled: boolean)
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.BackpackEnabled = enabled
				conch.log("info", ("[Settings] BackpackEnabled: %s"):format(tostring(state.Settings.BackpackEnabled)))
				Remotes.SettingsChanged:FireClient(player, { BackpackEnabled = state.Settings.BackpackEnabled })
			end)
		end,
	})

	conch.register("set-limit", {
		description = "Set weight limit: set-limit <n>",
		permissions = P,
		arguments = function()
			return conch.args.opt(conch.args.number("n", "Weight limit"))
		end,
		callback = function(n: number?)
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				local newLimit = asCount(n, 15)
				state.Settings.Limit = newLimit
				conch.log("info", ("[Settings] Limit set to: %d"):format(newLimit))
				Remotes.SettingsChanged:FireClient(player, { Limit = newLimit })
			end)
		end,
	})

	conch.register("set-max-stack", {
		description = "Set max stack size: set-max-stack <n>",
		permissions = P,
		arguments = function()
			return conch.args.opt(conch.args.number("n", "Max stack size"))
		end,
		callback = function(n: number?)
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				local newMax = asCount(n, 5)
				state.Settings.MaxStackSize = newMax
				conch.log("info", ("[Settings] MaxStackSize set to: %d"):format(newMax))
				Remotes.SettingsChanged:FireClient(player, { MaxStackSize = newMax })
			end)
		end,
	})

	conch.register("set-hotbar-slots", {
		description = "Set hotbar slot count: set-hotbar-slots <n>",
		permissions = P,
		arguments = function()
			return conch.args.opt(conch.args.number("n", "Slot count"))
		end,
		callback = function(n: number?)
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				local newSlots = asCount(n, 9)
				state.Settings.MaxHotbarSlots = newSlots
				conch.log("info", ("[Settings] MaxHotbarSlots set to: %d"):format(newSlots))
				Remotes.SettingsChanged:FireClient(player, { MaxHotbarSlots = newSlots })
			end)
		end,
	})

	conch.register("set-hotbar-type", {
		description = "Switch hotbar type: set-hotbar-type <Static|Dynamic>",
		permissions = P,
		arguments = function()
			return conch.args.static_enum_from_array({ "Static", "Dynamic" })("type", "Static or Dynamic")
		end,
		callback = function(raw: string)
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				if raw == "Static" then
					CoreStore.setHotbarType(state, "Static")
					conch.log("info", "[Settings] HotbarType set to: Static")
					Remotes.SettingsChanged:FireClient(player, { HotbarType = "Static" })
				elseif raw == "Dynamic" then
					CoreStore.setHotbarType(state, "Dynamic")
					conch.log("info", "[Settings] HotbarType set to: Dynamic")
					Remotes.SettingsChanged:FireClient(player, { HotbarType = "Dynamic" })
				else
					conch.log("error", "Usage: set-hotbar-type <Static|Dynamic>")
				end
			end)
		end,
	})

	conch.register("set-skin", {
		description = "Switch the UI skin (Jailbreak and Persona pair with JailbreakHotbar)",
		permissions = P,
		arguments = function()
			return conch.args.static_enum_from_array({ "Default", "Modern", "Metal", "Jailbreak", "Persona" })("skin", "UiSkin")
		end,
		callback = function(raw: unknown)
			withCaller(stoway, function(player: Player)
				local skin = normalizeSkin(raw)
				if not skin then
					conch.log("error", "Usage: set-skin <Default|Modern|Metal|Jailbreak|Persona>")
					return
				end
				local layout = if skin == "Jailbreak" or skin == "Persona" then "JailbreakHotbar" else "StandardHotbarStorage"
				sendLayout(player, layout, skin)
			end)
		end,
	})

	conch.register("set-layout", {
		description = "Switch layout and skin: set-layout <layout> [skin]",
		permissions = P,
		arguments = function()
			return conch.args.static_enum_from_array({ "StandardHotbarStorage", "JailbreakHotbar" })("layout", "Layout engine"),
				conch.args.opt(conch.args.string("skin", "UiSkin (default Default)"))
		end,
		callback = function(rawLayout: unknown, rawSkin: unknown)
			withCaller(stoway, function(player: Player)
				local layout = normalizeLayout(rawLayout)
				local skin = normalizeSkin(if rawSkin == nil then "Default" else rawSkin)
				if not layout or not skin then
					conch.log("error", "Usage: set-layout <StandardHotbarStorage|JailbreakHotbar> [Default|Modern|Metal|Jailbreak|Persona]")
					return
				end
				sendLayout(player, layout, skin)
			end)
		end,
	})

	conch.register("set-team", {
		description = "Tint all slot rings to the team color: set-team <criminal|cop|prison>",
		permissions = P,
		arguments = function()
			return conch.args.static_enum_from_array({ "criminal", "cop", "prison" })("team", "Team")
		end,
		callback = function(raw: unknown)
			withCaller(stoway, function(player: Player)
				local team = normalizeTeam(raw)
				if not team then
					conch.log("error", "Usage: set-team <criminal|cop|prison>")
					return
				end
				local state = stoway.get(player) :: Types.InventoryState
				local count = 0
				for uuid in state.Items do
					local res = stoway.UpdateMetadata(player, uuid, { Team = team }, true)
					if res.ok then count += 1 end
				end
				conch.log("success", ("[Settings] Team set to %s (%d items)"):format(team, count))
			end)
		end,
	})

	conch.register("toggle-sort", {
		description = "Toggle auto-sort on/off",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.Sorting = not state.Settings.Sorting
				conch.log("info", ("[Settings] Sorting: %s"):format(tostring(state.Settings.Sorting)))
				Remotes.SettingsChanged:FireClient(player, { Sorting = state.Settings.Sorting })
			end)
		end,
	})

	conch.register("toggle-debug", {
		description = "Toggle system print/warn logs on/off",
		permissions = P,
		arguments = function() end,
		callback = function()
			withCaller(stoway, function(player: Player)
				local state = stoway.get(player) :: Types.InventoryState
				state.Settings.DebugLogs = not state.Settings.DebugLogs
				conch.log("info", ("[Settings] DebugLogs: %s"):format(tostring(state.Settings.DebugLogs)))
				Remotes.SettingsChanged:FireClient(player, { DebugLogs = state.Settings.DebugLogs })
			end)
		end,
	})

	conch.register("help", {
		description = "List Stoway debug commands",
		permissions = P,
		arguments = function() end,
		callback = function()
			conch.log("info", "STOWAY DEBUG COMMANDS (bare names, no slash)")
			conch.log("info", "inv | add | addback | addhot | remove | drop")
			conch.log("info", "swap | move | split | equip | equip-slot | unequip | sort | clear-inv")
			conch.log("info", "toggle-stack | toggle-limit | toggle-backpack | toggle-sort | toggle-debug")
			conch.log("info", "set-limit | set-max-stack | set-hotbar-slots | set-hotbar-type | set-backpack")
			conch.log("info", "set-skin | set-layout | set-team")
		end,
	})
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Dev console gate: Studio only. Production gets no remotes, no role,
-- no commands. (Per-player allowlist later: grant in `grant` below.)
local function consoleEnabled(): boolean
	return game:GetService("RunService"):IsStudio()
end

-- Server conch owner: lifecycle first (net must exist before roles),
-- then one debug role, then every command, then grants per join.
-- No-op outside Studio (see consoleEnabled).
function ConchCommands.RegisterAll(stoway: StowayApi)
	if not consoleEnabled() then return end
	conch.initiate_default_lifecycle()
	conch.set_role_permissions(DEBUG_ROLE, DEBUG_PERM)
	registerAll(stoway)

	local function grant(player: Player)
		local ok, user = pcall(function()
			return conch.get_user(player)
		end)
		if ok and user ~= nil then
			conch.give_roles(user, DEBUG_ROLE)
			conch.log_to(player, "info", "Stoway debug console ready: press Backquote (`) to open it.")
		end
	end
	Players.PlayerAdded:Connect(grant)
	for _, player in Players:GetPlayers() do
		task.defer(grant, player)
	end
	Log.print(SharedSettings.getDefault(), "[Debug] Conch commands registered - open with Backquote (`)")
end

-----------------------------
-- MAIN --
-----------------------------

return ConchCommands
