--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Interactive manual test runner for CoreStore using Lune stdio/fs/serde
	Run with: lune run src/server/tests/manual_test
]]
-----------------------------
-- SERVICES --
-----------------------------

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local CoreStore = require("../CoreStore")

-----------------------------
-- VARIABLES --
-----------------------------

local state = CoreStore.new()
local running = true
local saveDir = "saves"

-----------------------------
-- CONSTANTS --
-----------------------------

local VERSION = "0.1.0"

-----------------------------
-- HANDLERS --
-----------------------------

local function header(text: string)
	print(`\n\27[1;36m{text}\27[0m`)
end

local function success(text: string)
	print(`  \27[32m{text}\27[0m`)
end

local function error(text: string)
	print(`  \27[31m{text}\27[0m`)
end

local function info(text: string)
	print(`  \27[33m{text}\27[0m`)
end

local function separator()
	print("───────────────────────────────────────────────────────────────")
end

local function displayInventory()
	header("INVENTORY")
	separator()
	print(`  Weight: {state.Weight} / {state.Settings.Limit} (0 = Infinite)`)
	print(`  CanStack: {state.Settings.CanStack} | MaxStack: {state.Settings.MaxStackSize}`)
	print(`  Equipped: {state.EquippedItemUUID or "None"}`)
	separator()

	header("HOTBAR")
	for i = 1, state.Settings.MaxHotbarSlots do
		local uuid = state.Hotbar[i]
		if uuid then
			local item = state.Items[uuid]
			if item then
				print(`  [{i}] {item.Id} x{item.Amount} (UUID: {uuid})`)
			else
				print(`  [{i}] \27[31m(ORPHAN: {uuid})\27[0m`)
			end
		else
			print(`  [{i}] (empty)`)
		end
	end

	header("STORAGE")
	if #state.Storage == 0 then
		print("  (empty)")
	else
		for i, uuid in ipairs(state.Storage) do
			local item = state.Items[uuid]
			if item then
				print(`  [{i}] {item.Id} x{item.Amount} (UUID: {uuid})`)
			else
				print(`  [{i}] \27[31m(ORPHAN: {uuid})\27[0m`)
			end
		end
	end
	separator()
end

local function displayHelp()
	header("COMMANDS")
	separator()
	print("  inv                   - Display inventory state")
	print("  add <id> [amount]     - Add item (auto placement)")
	print("  addback <id> [amount] - Add item to backpack only")
	print("  addhot <id> [slot] [amount] - Add item to hotbar slot")
	print("  remove <uuid> [amount]- Remove item by UUID")
	print("  find <id>             - Find all items by ID")
	print("  get <uuid>            - Get item by UUID")
	print("  all                   - List all items")
	separator()
	print("  settings              - Show current settings")
	print("  set_limit <n>         - Set weight limit (0 = infinite)")
	print("  set_stack <on|off>    - Toggle stacking")
	print("  set_maxstack <n>      - Set max stack size")
	print("  set_hotbar <n>        - Set max hotbar slots")
	separator()
	print("  save [filename]       - Save state to JSON file")
	print("  load [filename]       - Load state from JSON file")
	print("  state                 - Dump raw state table")
	separator()
	print("  clear                 - Clear inventory")
	print("  help                  - Show this help")
	print("  exit                  - Quit")
	separator()
end

local function ensureSaveDir()
	if not fs.isDir(saveDir) then
		fs.writeDir(saveDir)
	end
end

local function parseArgs(input: string): { string }
	local args = {}
	for word in input:gmatch("%S+") do
		table.insert(args, word)
	end
	return args
end

-----------------------------
-- COMMAND HANDLERS --
-----------------------------

local commands: { [string]: (args: { string }) -> () } = {}

commands["help"] = function(_)
	displayHelp()
end

commands["inv"] = function(_)
	displayInventory()
end

commands["exit"] = function(_)
	running = false
	print("Bye!")
end

commands["add"] = function(args)
	local itemId = args[2]
	if not itemId then
		info("Usage: add <itemId> [amount]")
		return
	end
	local amount = tonumber(args[3]) or 1
	local result = CoreStore.add(state, { Id = itemId, Amount = amount })
	if result.success then
		success(`Added {result.addedAmount}x {itemId}`)
		if result.addedItems then
			for _, added in result.addedItems do
				print(`    -> {added.slotType} slot {added.slot} (UUID: {added.uuid})`)
			end
		end
		if result.overflow and result.overflow > 0 then
			info(`  Overflow: {result.overflow}`)
		end
	else
		error(`Failed: {result.reason or "UNKNOWN"}`)
	end
end

commands["addback"] = function(args)
	local itemId = args[2]
	if not itemId then
		info("Usage: addback <itemId> [amount]")
		return
	end
	local amount = tonumber(args[3]) or 1
	local result = CoreStore.addToBackpack(state, { Id = itemId, Amount = amount })
	if result.success then
		success(`Added {result.addedAmount}x {itemId} to backpack`)
	else
		error(`Failed: {result.reason or "UNKNOWN"}`)
	end
end

commands["addhot"] = function(args)
	local itemId = args[2]
	if not itemId then
		info("Usage: addhot <itemId> [slot] [amount]")
		return
	end
	local slot = tonumber(args[3])
	local amount = tonumber(args[4]) or 1
	local result = CoreStore.addToHotbar(state, { Id = itemId, Amount = amount }, slot)
	if result.success then
		success(`Added {result.addedAmount}x {itemId} to hotbar`)
		if result.addedItems then
			for _, added in result.addedItems do
				print(`    -> slot {added.slot} (UUID: {added.uuid})`)
			end
		end
	else
		error(`Failed: {result.reason or "UNKNOWN"}`)
	end
end

commands["remove"] = function(args)
	local uuid = args[2]
	if not uuid then
		info("Usage: remove <uuid> [amount]")
		return
	end
	local amount = tonumber(args[3])
	local result = CoreStore.remove(state, uuid, amount)
	if result.success then
		if result.removedItem then
			success(`Removed {result.removedItem.Amount}x {result.removedItem.Id}`)
		else
			success("Removed item")
		end
		if result.remaining and result.remaining > 0 then
			info(`  Remaining: {result.remaining}`)
		end
	else
		error(`Failed: {result.reason or "UNKNOWN"}`)
	end
end

commands["find"] = function(args)
	local itemId = args[2]
	if not itemId then
		info("Usage: find <itemId>")
		return
	end
	local items = CoreStore.find(state, itemId)
	if #items == 0 then
		info(`No items found with ID: {itemId}`)
		return
	end
	header(`FOUND {#items}x {itemId}`)
	for _, item in items do
		local loc = state.LocationByUUID[item.UUID]
		local locStr = if loc then `{loc.Type}[{loc.Slot}]` else "unplaced"
		print(`  UUID: {item.UUID} | Amount: {item.Amount} | Location: {locStr}`)
	end
end

commands["get"] = function(args)
	local uuid = args[2]
	if not uuid then
		info("Usage: get <uuid>")
		return
	end
	local item = CoreStore.getItem(state, uuid)
	if not item then
		info(`Item not found: {uuid}`)
		return
	end
	header("ITEM")
	print(`  UUID:     {item.UUID}`)
	print(`  Id:       {item.Id}`)
	print(`  Amount:   {item.Amount}`)
	print(`  Metadata: {serde.encode("json", item.Metadata, { pretty = true })}`)
	local loc = state.LocationByUUID[item.UUID]
	if loc then
		print(`  Location: {loc.Type} slot {loc.Slot}`)
	else
		print(`  Location: unplaced`)
	end
end

commands["all"] = function(_)
	local items = CoreStore.getAllItems(state)
	if #items == 0 then
		info("Inventory is empty")
		return
	end
	header(`ALL ITEMS ({#items})`)
	for _, item in items do
		local loc = state.LocationByUUID[item.UUID]
		local locStr = if loc then `{loc.Type}[{loc.Slot}]` else "unplaced"
		print(`  {item.Id} x{item.Amount} | UUID: {item.UUID} | {locStr}`)
	end
end

commands["settings"] = function(_)
	header("SETTINGS")
	print(`  HotbarType:          {state.Settings.HotbarType}`)
	print(`  MaxHotbarSlots:      {state.Settings.MaxHotbarSlots}`)
	print(`  Limit:               {state.Settings.Limit} (0 = Infinite)`)
	print(`  CanStack:            {state.Settings.CanStack}`)
	print(`  MaxStackSize:        {state.Settings.MaxStackSize}`)
	print(`  BackpackEnabled:     {state.Settings.BackpackEnabled}`)
	print(`  Sorting:             {state.Settings.Sorting}`)
	print(`  SortOrder:           {state.Settings.SortOrder}`)
	print(`  DefaultDroppable:    {state.Settings.DefaultDroppable}`)
end

commands["set_limit"] = function(args)
	local n = tonumber(args[2])
	if not n then
		info("Usage: set_limit <number>")
		return
	end
	state.Settings.Limit = n
	success(`Limit set to {n} (0 = Infinite)`)
end

commands["set_stack"] = function(args)
	local val = args[2]
	if val == "on" then
		state.Settings.CanStack = true
		success("CanStack: true")
	elseif val == "off" then
		state.Settings.CanStack = false
		success("CanStack: false")
	else
		info("Usage: set_stack <on|off>")
	end
end

commands["set_maxstack"] = function(args)
	local n = tonumber(args[2])
	if not n then
		info("Usage: set_maxstack <number>")
		return
	end
	state.Settings.MaxStackSize = n
	success(`MaxStackSize set to {n}`)
end

commands["set_hotbar"] = function(args)
	local n = tonumber(args[2])
	if not n then
		info("Usage: set_hotbar <number>")
		return
	end
	state.Settings.MaxHotbarSlots = n
	success(`MaxHotbarSlots set to {n}`)
end

commands["clear"] = function(_)
	local uuids = {}
	for uuid, _ in pairs(state.Items) do
		table.insert(uuids, uuid)
	end
	for _, uuid in uuids do
		CoreStore.remove(state, uuid)
	end
	success("Inventory cleared")
end

commands["save"] = function(args)
	local filename = args[2] or "inventory.json"
	ensureSaveDir()
	local path = `{saveDir}/{filename}`
	local data = serde.encode("json", state, { pretty = true })
	fs.writeFile(path, data)
	success(`Saved to {path}`)
end

commands["load"] = function(args)
	local filename = args[2] or "inventory.json"
	local path = `{saveDir}/{filename}`
	if not fs.isFile(path) then
		error(`File not found: {path}`)
		return
	end
	local data = fs.readFile(path)
	local loaded = serde.decode("json", data)
	state = loaded
	success(`Loaded from {path}`)
end

commands["state"] = function(_)
	header("RAW STATE")
	print(serde.encode("json", state, { pretty = true }))
end

-----------------------------
-- MAIN --
-----------------------------

print(`\27[1;35mCoreStore Manual Test Runner v{VERSION}\27[0m`)
print("Type 'help' for commands, 'exit' to quit.\n")

while running do
	local input = stdio.prompt("text", ">")
	if not input or input == "" then
		continue
	end

	local args = parseArgs(input)
	local cmd = string.lower(args[1])

	if commands[cmd] then
		local ok, err = pcall(commands[cmd], args)
		if not ok then
			error(`Command error: {err}`)
		end
	else
		info(`Unknown command: {cmd} (type 'help')`)
	end
end
