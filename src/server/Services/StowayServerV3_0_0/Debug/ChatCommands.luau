--@author: yyumchi
--@date: 2026-08-08
--[[@description:
	Debug chat commands for testing StowayServerV3_0_0.
	Hooks player.Chatted and routes commands through the Stoway facade.
	All output goes to the server console (Output window).
	Adapted from the V1.2 Debug/ChatCommands module to the V3 API.
]]
-----------------------------
-- DEPENDENCIES --
-----------------------------

local CoreStore = require(script.Parent.Parent.CoreStore)
local Types = require(script.Parent.Parent.CoreStore.Types)

-----------------------------
-- VARIABLES --
-----------------------------

type StowayApi = {
	get: (Player) -> Types.InventoryState?,
	createPlayer: (Player, Types.SettingsOverrides?) -> Types.InventoryState,
	removePlayer: (Player) -> Types.InventoryState?,
	AddItem: (Player, Types.ItemInput, Types.AddOptions?, boolean?) -> Types.AddResult,
	AddToBackpack: (Player, Types.ItemInput, Types.AddOptions?, boolean?) -> Types.AddResult,
	AddToHotbar: (Player, Types.ItemInput, number?, boolean?) -> Types.AddResult,
	RemoveItem: (Player, string, number?, boolean?) -> Types.RemoveResult,
	SwapSlots: (Player, Types.SlotRef, Types.SlotRef, boolean?) -> Types.SwapResult,
	Move: (Player, Types.SlotRef, Types.SlotRef, boolean?) -> Types.MoveResult,
	Split: (Player, string, number, Types.SlotRef?, boolean?) -> Types.SplitResult,
	EquipSlot: (Player, string, boolean?) -> Types.EquipResult,
	UnequipSlot: (Player, boolean?) -> Types.UnequipResult,
	UpdateMetadata: (Player, string, { [string]: any }, boolean?) -> Types.MetadataUpdateResult,
	Sort: (Player, boolean?) -> Types.SortResult,
}

local ChatCommands = {}

local registered: { [Player]: boolean } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function requireState(player: Player, stoway: StowayApi): Types.InventoryState?
	local state = stoway.get(player)
	if not state then
		print("[Stoway] no inventory state for", player.Name)
	end
	return state
end

local function toSlotType(raw: string): Types.SlotType?
	local normalized = raw:sub(1, 1):upper() .. raw:sub(2):lower()
	if normalized == "Hotbar" or normalized == "Storage" then
		return normalized
	end
	return nil
end

local function parseSlotRef(args: { string }, start: number): Types.SlotRef?
	local rawType = args[start]
	local slot = tonumber(args[start + 1])
	if not (rawType and slot) then
		return nil
	end
	local slotType = toSlotType(rawType)
	if not slotType then
		return nil
	end
	return { Type = slotType, Slot = slot }
end

local function printBox(title: string)
	print("═══════════════════════════════════════════════════════════════")
	print(title)
	print("───────────────────────────────────────────────────────────────")
end

-- INVENTORY DISPLAY

local function cmdInv(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end

	printBox(("INVENTORY for %s"):format(player.Name))
	print("Weight:", state.Weight, "/", state.Settings.Limit, "(0 = Infinite)")
	print("CanStack:", state.Settings.CanStack, "| MaxStack:", state.Settings.MaxStackSize)
	print("HotbarType:", state.Settings.HotbarType, "| Sorting:", state.Settings.Sorting)
	print("Equipped UUID:", state.EquippedItemUUID or "None")
	print("───────────────────────────────────────────────────────────────")
	print(("HOTBAR (max %d):"):format(state.Settings.MaxHotbarSlots))
	for i = 1, state.Settings.MaxHotbarSlots do
		local uuid = state.Hotbar[i]
		if uuid then
			local item = state.Items[uuid]
			if item then
				print(("  [%d] %s x%d (UUID: %s)"):format(i, item.Id, item.Amount, uuid))
			else
				print(("  [%d] (ORPHAN UUID: %s)"):format(i, uuid))
			end
		else
			print(("  [%d] (empty)"):format(i))
		end
	end
	print(("STORAGE: #%d"):format(#state.Storage))
	for i, uuid in ipairs(state.Storage) do
		local item = state.Items[uuid]
		if item then
			print(("  [%d] %s x%d (UUID: %s)"):format(i, item.Id, item.Amount, uuid))
		else
			print(("  [%d] (ORPHAN UUID: %s)"):format(i, uuid))
		end
	end
	print("═══════════════════════════════════════════════════════════════")
end

-- ADD ITEM

local function cmdAdd(player: Player, stoway: StowayApi, args: { string })
	local itemId = args[2]
	if not itemId then
		print("Usage: /add [itemId] [amount?]")
		return
	end

	local amount = tonumber(args[3]) or 1
	local result = stoway.AddItem(player, { Id = itemId, Amount = amount }, nil, true)
	print(("[Add] %s x%d"):format(itemId, amount))
	print("  Success:", result.success)
	print("  Added:", result.addedAmount or 0)
	print("  Overflow:", result.overflow or 0)
	print("  Reason:", result.reason or "OK")
end

local function cmdAddBack(player: Player, stoway: StowayApi, args: { string })
	local itemId = args[2]
	if not itemId then
		print("Usage: /addback [itemId] [amount?]")
		return
	end

	local amount = tonumber(args[3]) or 1
	local result = stoway.AddToBackpack(player, { Id = itemId, Amount = amount }, nil, true)
	print(("[AddToBackpack] %s x%d"):format(itemId, amount))
	print("  Success:", result.success)
	print("  Added:", result.addedAmount or 0)
	print("  Overflow:", result.overflow or 0)
	print("  Reason:", result.reason or "OK")
end

local function cmdAddHot(player: Player, stoway: StowayApi, args: { string })
	local itemId = args[2]
	if not itemId then
		print("Usage: /addhot [itemId] [amount?] [slot?]")
		return
	end

	local amount = tonumber(args[3]) or 1
	local slot = tonumber(args[4])
	local result = stoway.AddToHotbar(player, { Id = itemId, Amount = amount }, slot, true)
	print(("[AddToHotbar] %s x%d%s"):format(itemId, amount, if slot then (" @slot " .. slot) else ""))
	print("  Success:", result.success)
	print("  Added:", result.addedAmount or 0)
	print("  Overflow:", result.overflow or 0)
	print("  Reason:", result.reason or "OK")
end

-- REMOVE ITEM

local function cmdRemove(player: Player, stoway: StowayApi, args: { string })
	local uuid = args[2]
	if not uuid then
		print("Usage: /remove [uuid] [amount?]")
		return
	end

	local amount = tonumber(args[3])
	local result = stoway.RemoveItem(player, uuid, amount, true)
	print(("[Remove] %s"):format(uuid))
	print("  Success:", result.success)
	print("  Remaining:", result.remaining or 0)
	print("  Reason:", result.reason or "OK")
end

-- SWAP / MOVE

local function cmdSwap(player: Player, stoway: StowayApi, args: { string })
	local from = parseSlotRef(args, 2)
	local to = parseSlotRef(args, 4)

	if not (from and to) then
		print("Usage: /swap [Hotbar/Storage] [slot] [Hotbar/Storage] [slot]")
		return
	end

	local result = stoway.SwapSlots(player, from, to, true)
	print(("[Swap] %s %d -> %s %d"):format(from.Type, from.Slot, to.Type, to.Slot))
	print("  Success:", result.success)
	print("  HotbarCompacted:", result.hotbarCompacted or false)
	print("  Reason:", result.reason or "OK")
end

local function cmdMove(player: Player, stoway: StowayApi, args: { string })
	local from = parseSlotRef(args, 2)
	local to = parseSlotRef(args, 4)

	if not (from and to) then
		print("Usage: /move [Hotbar/Storage] [slot] [Hotbar/Storage] [slot]")
		return
	end

	local result = stoway.Move(player, from, to, true)
	print(("[Move] %s %d -> %s %d"):format(from.Type, from.Slot, to.Type, to.Slot))
	print("  Success:", result.success)
	print("  HotbarCompacted:", result.hotbarCompacted or false)
	print("  Reason:", result.reason or "OK")
end

-- SPLIT

local function cmdSplit(player: Player, stoway: StowayApi, args: { string })
	local uuid = args[2]
	local amount = tonumber(args[3])
	if not (uuid and amount) then
		print("Usage: /split [uuid] [amount] [Hotbar/Storage] [slot]?")
		return
	end

	local destination: Types.SlotRef? = nil
	if args[4] then
		destination = parseSlotRef(args, 4)
	end

	local result = stoway.Split(player, uuid, amount, destination, true)
	print(("[Split] %s x%d"):format(uuid, amount))
	print("  Success:", result.success)
	print("  New UUID:", result.newUUID or "?")
	print("  New Amount:", result.newAmount or 0)
	if result.newSlotType and result.newSlot then
		print("  Destination:", result.newSlotType, result.newSlot)
	end
	print("  Reason:", result.reason or "OK")
end

-- EQUIP / UNEQUIP

local function cmdEquip(player: Player, stoway: StowayApi, args: { string })
	local uuid = args[2]
	if not uuid then
		print("Usage: /equip [uuid]")
		return
	end

	local result = stoway.EquipSlot(player, uuid, true)
	print(("[Equip] %s"):format(uuid))
	print("  Success:", result.success)
	print("  Equipped UUID:", result.uuid or "None")
	print("  Previous:", result.previousUUID or "None")
end

local function cmdUnequip(player: Player, stoway: StowayApi, args: { string })
	local result = stoway.UnequipSlot(player, true)
	print("[Unequip]")
	print("  Previous UUID:", result.previousUUID or "None")
end

-- SORT

local function cmdSort(player: Player, stoway: StowayApi, args: { string })
	local result = stoway.Sort(player, true)
	print("[Sort]")
	print("  Success:", result.success)
	print("  Storage Order:", result.storageOrder and ("#" .. #result.storageOrder) or "?")
end

-- CLEAR

local function cmdClear(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end

	local uuids: { string } = {}
	for uuid in state.Items do
		table.insert(uuids, uuid)
	end
	for _, uuid in uuids do
		stoway.RemoveItem(player, uuid, nil, true)
	end
	print(("[Clear] removed %d item(s)"):format(#uuids))
end

-- SETTINGS (PER-PLAYER)

local function cmdToggleStack(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	state.Settings.CanStack = not state.Settings.CanStack
	print("[Settings] CanStack:", state.Settings.CanStack)
end

local function cmdToggleLimit(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	state.Settings.Limit = if state.Settings.Limit == 0 then 15 else 0
	print("[Settings] Limit:", state.Settings.Limit, "(0 = Infinite)")
end

local function cmdSetLimit(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	local newLimit = tonumber(args[2]) or 15
	state.Settings.Limit = newLimit
	print("[Settings] Limit set to:", newLimit)
end

local function cmdSetMaxStack(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	local newMax = tonumber(args[2]) or 5
	state.Settings.MaxStackSize = newMax
	print("[Settings] MaxStackSize set to:", newMax)
end

local function cmdSetHotbarSlots(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	local newSlots = tonumber(args[2]) or 9
	state.Settings.MaxHotbarSlots = newSlots
	print("[Settings] MaxHotbarSlots set to:", newSlots)
end

local function cmdSetHotbarType(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end

	local raw = args[2]
	if raw == "Static" then
		CoreStore.setHotbarType(state, "Static")
		print("[Settings] HotbarType set to: Static")
	elseif raw == "Dynamic" then
		CoreStore.setHotbarType(state, "Dynamic")
		print("[Settings] HotbarType set to: Dynamic")
	else
		print("Usage: /set_hotbar_type [Static|Dynamic]")
	end
end

local function cmdToggleSort(player: Player, stoway: StowayApi, args: { string })
	local state = requireState(player, stoway)
	if not state then return end
	state.Settings.Sorting = not state.Settings.Sorting
	print("[Settings] Sorting:", state.Settings.Sorting)
end

-- HELP

local function cmdHelp(player: Player, stoway: StowayApi, args: { string })
	print("═══════════════════════════════════════════════════════════════")
	print("STOWAY DEBUG COMMANDS")
	print("───────────────────────────────────────────────────────────────")
	print("/inv                            - Display inventory state")
	print("/add [id] [amount?]             - Add item (auto placement)")
	print("/addback [id] [amount?]         - Add directly to backpack")
	print("/addhot [id] [amount?] [slot?]  - Add directly to hotbar")
	print("/remove [uuid] [amount?]        - Remove item by UUID")
	print("/swap [t1] [s1] [t2] [s2]       - Swap two slots")
	print("/move [t1] [s1] [t2] [s2]       - Move item to slot (never stacks)")
	print("/split [uuid] [amt] [t] [s]?    - Split a stack")
	print("/equip [uuid]                   - Equip item by UUID")
	print("/unequip                        - Unequip current item")
	print("/sort                           - Sort storage")
	print("/clear                          - Clear inventory")
	print("───────────────────────────────────────────────────────────────")
	print("/toggle_stack                   - Toggle stacking on/off")
	print("/toggle_limit                   - Toggle limit (0=infinite / 15)")
	print("/set_limit [n]                  - Set weight limit")
	print("/set_max_stack [n]              - Set max stack size")
	print("/set_hotbar_slots [n]           - Set hotbar slot count")
	print("/set_hotbar_type [Static|Dynamic] - Switch hotbar type (auto-compacts)")
	print("/toggle_sort                    - Toggle auto-sort on/off")
	print("═══════════════════════════════════════════════════════════════")
end

-- DISPATCH

local commands: { [string]: (Player, StowayApi, { string }) -> () } = {
	inv = cmdInv,
	add = cmdAdd,
	addback = cmdAddBack,
	addhot = cmdAddHot,
	remove = cmdRemove,
	swap = cmdSwap,
	move = cmdMove,
	split = cmdSplit,
	equip = cmdEquip,
	unequip = cmdUnequip,
	sort = cmdSort,
	clear = cmdClear,
	toggle_stack = cmdToggleStack,
	toggle_limit = cmdToggleLimit,
	set_limit = cmdSetLimit,
	set_max_stack = cmdSetMaxStack,
	set_hotbar_slots = cmdSetHotbarSlots,
	set_hotbar_type = cmdSetHotbarType,
	toggle_sort = cmdToggleSort,
	help = cmdHelp,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function ChatCommands.Register(player: Player, stoway: StowayApi)
	if registered[player] then
		return
	end
	registered[player] = true

	player.Chatted:Connect(function(msg: string)
		local args = string.split(msg, " ")
		local cmd = string.lower(((args[1] or ""):gsub("^/", "")))
		local handler = commands[cmd]
		if handler then
			handler(player, stoway, args)
		end
	end)

	print(("[Debug] Chat commands registered for %s - Type /help"):format(player.Name))
end

-----------------------------
--MAIN--
-----------------------------

return ChatCommands
