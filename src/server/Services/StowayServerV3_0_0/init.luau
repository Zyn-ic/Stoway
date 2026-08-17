--!strict

--@author: yyumchi
--@date: 2026-07-06
--[[@description:
	StowayServerV3_0_0 — orchestration layer.
	Connects CoreStore to Roblox-specific layers (Network, World, Client).
	Handles player lifecycle, operation routing, anti-exploit, result dispatching.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Types = require(script.CoreStore.Types)
local Protocol = require(script.Protocol)
local Result = require(ReplicatedStorage.Shared.Types.Result)

-- Minimal contract for the injected CoreStore module.
type CoreStoreApi = {
	new: (Types.SettingsOverrides?) -> Types.InventoryState,
	add: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToBackpack: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToHotbar: (Types.InventoryState, Types.ItemInput, number?) -> Types.AddResult,
	remove: (Types.InventoryState, string, number?) -> Types.RemoveResult,
	swap: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.SwapResult,
	swapStack: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.SwapResult,
	move: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.MoveResult,
	split: (Types.InventoryState, string, number, Types.SlotRef?) -> Types.SplitResult,
	equip: (Types.InventoryState, string) -> Types.EquipResult,
	unequip: (Types.InventoryState) -> Types.UnequipResult,
	updateMetadata: (Types.InventoryState, string, { [string]: any }) -> Types.MetadataUpdateResult,
	sort: (Types.InventoryState) -> Types.SortResult,
}

type Adapter = Protocol.Adapter

local CoreStore: CoreStoreApi? = nil
-- Replication is opt-in: nil (omitted) means no replication.
-- Pass `true` explicitly to echo a server-side change to a client.
local function resolveReplicate(replicate: boolean?): boolean
	return if replicate == nil then false else replicate
end

local _store: { [Player]: Types.InventoryState } = {}
local _locks: { [Player]: number } = {}
local _adapters: { Adapter } = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local LOCK_TIMEOUT = 3

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function lockPlayer(player: Player): boolean
	local existing = _locks[player]
	if existing then
		local elapsed = os.clock() - existing
		if elapsed < LOCK_TIMEOUT then
			return false
		end
	end
	_locks[player] = os.clock()
	return true
end

local function unlockPlayer(player: Player)
	_locks[player] = nil
end

-- Returns the tool template Instance from ServerStorage.Tools, or nil.
local function getToolTemplate(itemId: string): Instance?
	local toolsFolder = ServerStorage:FindFirstChild("Tools")
	if not toolsFolder then return nil end
	return toolsFolder:FindFirstChild(itemId)
end

local function _isValidItemId(itemId: string): boolean
	return getToolTemplate(itemId) ~= nil
end

-- Reads a tool template's attributes and returns safe metadata defaults.
-- These are merged UNDER caller-provided metadata (caller wins on conflict).
local function getDefaultMetadata(template: Instance): Types.ItemMetadata
	return {
		Description = (template:GetAttribute("Description") or "") :: any,
		Image        = (template:GetAttribute("Image") or "") :: any,
		Droppable    = (if template:GetAttribute("Droppable") ~= nil
		               then template:GetAttribute("Droppable")
		               else true) :: any,
		IsGamepass   = (template:GetAttribute("IsGamepass") or false) :: any,
		Rarity       = (template:GetAttribute("Rarity") or "Common") :: any,
		Type         = (template:GetAttribute("Type") or "material") :: any,
	}
end

-- Merges defaults under provided; provided values take priority.
local function mergeMetadata(provided: Types.ItemMetadata?, defaults: Types.ItemMetadata): Types.ItemMetadata
	local merged: { [string]: any } = {}
	for k, v in defaults :: { [string]: any } do
		merged[k] = v
	end
	if provided then
		for k, v in provided :: { [string]: any } do
			merged[k] = v
		end
	end
	return merged :: Types.ItemMetadata
end

-- Stamps all item fields as Instance attributes onto a Tool.
local function applyToolAttributes(tool: Instance, item: Types.Item)
	tool:SetAttribute("UUID",   item.UUID)
	tool:SetAttribute("Amount", item.Amount)
	tool:SetAttribute("Id",     item.Id)
	for key, value in item.Metadata :: { [string]: any } do
		tool:SetAttribute(key, value)
	end
end

-- Returns a CFrame 5 studs in front of where the player's character is looking.
local function getDropCFrame(player: Player): CFrame?
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end
	return hrp.CFrame * CFrame.new(0, 0, -5)
end

local function dispatch(player: Player, signal: Protocol.Signal)
	for _, adapter in _adapters do
		adapter(player, signal)
	end
end

-- fn receives the (non-nil) CoreStore so it never touches the nullable module field.
local function route(player: Player, operation: Protocol.Operation, replicate: boolean, fn: (cs: CoreStoreApi) -> any): any
	if not lockPlayer(player) then
		return Result.Err({ kind = Result.ErrorKind.NotAvailable, message = "OPERATION_IN_PROGRESS" })
	end

	assert(CoreStore, "CoreStore not initialized")
	local ok, result = pcall(fn, CoreStore)

	if not ok then
		unlockPlayer(player)
		assert(false, `OPERATION_FAILED: {result}`)
	end

	-- Cast is intentional: 'result' is 'any' after pcall, and 'operation' is the
	-- tagged-union discriminant literal this module constructs with the correct
	-- per-operation result type.
	local signal = ({ operation = operation, replicate = replicate, result = result }) :: Protocol.Signal
	dispatch(player, signal)
	unlockPlayer(player)
	return result
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Stoway.Init(CS: CoreStoreApi)
	CoreStore = CS
end

function Stoway.Start()
	local ServerScriptService = game:GetService("ServerScriptService")
	local PlayerServiceSignals = require(ServerScriptService.Libraries.PlayerServiceSignals)

	PlayerServiceSignals.BindToPlrAdded:Connect(function(player: Player)
        warn(player.Name .. " stoway has been created")
        Stoway.createPlayer(player)
    end)

    PlayerServiceSignals.BindToPlrRemoving:Connect(function(player: Player)
        warn(player.Name .. " stoway is being removed")
        Stoway.removePlayer(player)
    end)
end

-- Player lifecycle

function Stoway.createPlayer(player: Player, settingsOverrides: Types.SettingsOverrides?): Types.InventoryState
	local cs = CoreStore :: CoreStoreApi
	local state = cs.new(settingsOverrides)
	_store[player] = state
	return state
end

function Stoway.get(player: Player): Types.InventoryState?
	return _store[player]
end

function Stoway.removePlayer(player: Player): Types.InventoryState?
	unlockPlayer(player)
	local state = _store[player]
	_store[player] = nil
	return state
end

function Stoway.getAll(): { [Player]: Types.InventoryState }
	return _store
end

-- Adapter registration

function Stoway.registerAdapter(adapter: Adapter)
	table.insert(_adapters, adapter)
end

-- Operation routes

local EK = Result.ErrorKind

function Stoway.AddItem(player: Player, itemData: Types.ItemInput, options: Types.AddOptions?, replicate: boolean?): Types.AddResult
	return route(player, "AddItem", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		local template = if itemData.Id then getToolTemplate(itemData.Id) else nil
		if not template then
			return Result.Err({ kind = EK.InvalidArgument, message = "ITEM_NOT_IN_TOOLS_FOLDER" })
		end

		local merged: Types.ItemInput = table.clone(itemData)
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template))
		return cs.add(state, merged, options)
	end)
end

function Stoway.AddToBackpack(player: Player, itemData: Types.ItemInput, options: Types.AddOptions?, replicate: boolean?): Types.AddResult
	return route(player, "AddToBackpack", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		local template = if itemData.Id then getToolTemplate(itemData.Id) else nil
		if not template then
			return Result.Err({ kind = EK.InvalidArgument, message = "ITEM_NOT_IN_TOOLS_FOLDER" })
		end

		local merged: Types.ItemInput = table.clone(itemData)
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template))
		return cs.addToBackpack(state, merged, options)
	end)
end

function Stoway.AddToHotbar(player: Player, itemData: Types.ItemInput, slot: number?, replicate: boolean?): Types.AddResult
	return route(player, "AddToHotbar", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		local template = if itemData.Id then getToolTemplate(itemData.Id) else nil
		if not template then
			return Result.Err({ kind = EK.InvalidArgument, message = "ITEM_NOT_IN_TOOLS_FOLDER" })
		end

		local merged: Types.ItemInput = table.clone(itemData)
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template))
		return cs.addToHotbar(state, merged, slot)
	end)
end

function Stoway.RemoveItem(player: Player, uuid: string, amount: number?, replicate: boolean?): Types.RemoveResult
	return route(player, "RemoveItem", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.remove(state, uuid, amount)
	end)
end

function Stoway.SwapSlots(player: Player, fromRef: Types.SlotRef, toRef: Types.SlotRef, replicate: boolean?): Types.SwapResult
	return route(player, "SwapSlots", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.swap(state, fromRef, toRef)
	end)
end

function Stoway.SwapStack(player: Player, fromRef: Types.SlotRef, toRef: Types.SlotRef, replicate: boolean?): Types.SwapResult
	return route(player, "SwapStack", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.swapStack(state, fromRef, toRef)
	end)
end

function Stoway.Move(player: Player, fromRef: Types.SlotRef, toRef: Types.SlotRef, replicate: boolean?): Types.MoveResult
	return route(player, "Move", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.move(state, fromRef, toRef)
	end)
end

function Stoway.Split(player: Player, uuid: string, amount: number, destination: Types.SlotRef?, replicate: boolean?): Types.SplitResult
	return route(player, "Split", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.split(state, uuid, amount, destination)
	end)
end

function Stoway.EquipSlot(player: Player, uuid: string, replicate: boolean?): Types.EquipResult
	return route(player, "EquipSlot", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		local item = state.Items[uuid]
		if not item then
			return Result.Err({ kind = EK.NotFound, message = "ITEM_NOT_FOUND" })
		end

		-- Update CoreStore state first
		local result = cs.equip(state, uuid)
		if not result.ok then return result end

		-- Equip Roblox-side: clone tool template into the character
		local character = player.Character
		local template = getToolTemplate(item.Id)
		if character and template then
			-- Destroy any stale duplicate with this UUID already in character (idempotency)
			for _, child in character:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("UUID") == uuid then
					child:Destroy()
					break
				end
			end
			local tool = template:Clone()
			applyToolAttributes(tool, item)
			tool.Parent = character  -- parenting a Tool to the Character equips it in Roblox
		end

		return result
	end)
end

function Stoway.UnequipSlot(player: Player, replicate: boolean?): Types.UnequipResult
	return route(player, "UnequipSlot", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then print(state); return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		-- Snapshot UUID before CoreStore clears it
		local equippedUUID = state.EquippedItemUUID

		local result = cs.unequip(state)
		if not result.ok then return result end

		-- Unequip Roblox-side: move the tool from Character to Backpack
		if equippedUUID then
			local character = player.Character
			if character then
				for _, child in character:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("UUID") == equippedUUID then
						child:Destroy()
						break
					end
				end
			end
		end

		return result
	end)
end

function Stoway.UpdateMetadata(player: Player, uuid: string, updates: { [string]: any }, replicate: boolean?): Types.MetadataUpdateResult
	return route(player, "UpdateMetadata", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.updateMetadata(state, uuid, updates)
	end)
end

function Stoway.Sort(player: Player, replicate: boolean?): Types.SortResult
	return route(player, "Sort", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end
		return cs.sort(state)
	end)
end

function Stoway.Drop(player: Player, uuid: string, amount: number?, replicate: boolean?): Types.DropResult
	return route(player, "Drop", resolveReplicate(replicate), function(cs: CoreStoreApi): Types.DropResult
		local state = _store[player]
		if not state then
			return Result.Err({ kind = EK.NotFound, message = "NO_STATE" })
		end

		local item = state.Items[uuid]
		if not item then
			return Result.Err({ kind = EK.NotFound, message = "ITEM_NOT_FOUND" })
		end

		if item.Metadata.Droppable == false then
			return Result.Err({ kind = EK.PermissionDenied, message = "NOT_DROPPABLE" })
		end

		local template = getToolTemplate(item.Id)
		if not template then
			return Result.Err({ kind = EK.InvalidArgument, message = "ITEM_NOT_IN_TOOLS_FOLDER" })
		end

		local isEquipped   = state.EquippedItemUUID == uuid
		local dropAmount   = math.min(amount or item.Amount, item.Amount)
		local isFullDrop   = dropAmount >= item.Amount
		local dropCFrame   = getDropCFrame(player)

		-- Find the equipped tool instance in the character now, before state mutates
		local equippedToolInChar: Tool? = nil
		if isEquipped then
			local character = player.Character
			if character then
				for _, child in character:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("UUID") == uuid then
						equippedToolInChar = child :: Tool
						break
					end
				end
			end
		end

		-- Unequip from CoreStore state only on a full drop of the equipped item
		if isEquipped and isFullDrop then
			cs.unequip(state)
		end

		-- Remove from inventory
		local removeResult = cs.remove(state, uuid, amount)
		if not removeResult.ok then
			return removeResult
		end

		-- Build a snapshot of the dropped item (removedItem is nil for partial removes)
		local droppedSnapshot: Types.Item = removeResult.value.removedItem or {
			UUID     = uuid,
			Id       = item.Id,
			Amount   = dropAmount,
			Metadata = item.Metadata,
		}

		-- Choose which tool instance goes into the world
		local worldTool: Tool
		if equippedToolInChar and isFullDrop then
			-- Equipped + full drop:
			-- Move to Backpack first (visually unequips from the hand), then we reparent to Workspace
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack then
				equippedToolInChar.Parent = backpack
			end
			equippedToolInChar:SetAttribute("Amount", droppedSnapshot.Amount)
			worldTool = equippedToolInChar
		else
			-- Not equipped, or partial drop: clone a fresh copy for the world
			local cloned = template:Clone() :: Tool
			applyToolAttributes(cloned, droppedSnapshot)
			-- If partial drop on equipped item, update the still-equipped tool's Amount attribute
			if equippedToolInChar then
				equippedToolInChar:SetAttribute("Amount", removeResult.value.remaining or 0)
			end
			worldTool = cloned
		end

		-- Position 5 studs in front of where the player is looking, then place in Workspace
		if dropCFrame then
			worldTool:PivotTo(dropCFrame)
		end
		worldTool.Parent = Workspace

		return Result.Ok({
			removedItem = droppedSnapshot,
			remaining   = removeResult.value.remaining,
			tool        = worldTool,
		})
	end)
end
-----------------------------
--MAIN--
-----------------------------

return Stoway
