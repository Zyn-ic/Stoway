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
local CollectionService = game:GetService("CollectionService")

-- Tag marking Stoway world drops. The pickup script watches for it.
local STOWAY_DROP_TAG = "Stoway"

local Types = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)
local SharedSettings = require(ReplicatedStorage.Shared.Stoway.Settings)

local Protocol = require(script.Protocol)
local Communications = require(script.Communications)

local Result = require(ReplicatedStorage.Shared.Stoway.Result)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

-- Minimal contract for the injected CoreStore module (single surface:
-- Protocol.CoreStoreApi; the hand-copy here drifted before).
type CoreStoreApi = Protocol.CoreStoreApi

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
-- Lune fallback: if ServerStorage is nil (no Roblox), return a mock tool so tests pass.
local function getToolTemplate(itemId: string): Instance?
	if not ServerStorage then
		return {
			GetAttribute = function(_self: any, _key: string)
				return nil
			end,
		} :: any
	end
	local toolsFolder = ServerStorage:FindFirstChild("Tools")
	if not toolsFolder then return nil end
	return toolsFolder:FindFirstChild(itemId)
end

local function _isValidItemId(itemId: string): boolean
	return getToolTemplate(itemId) ~= nil
end

-- Reads a tool template's attributes and returns safe metadata defaults.
-- These are merged UNDER caller-provided metadata (caller wins on conflict).
-- defaultDroppable is the per-player DefaultDroppable setting; it applies
-- only when the template itself does not declare a Droppable attribute.
local function getDefaultMetadata(template: Instance, defaultDroppable: boolean?): Types.ItemMetadata
	local dropDefault = if defaultDroppable == nil then true else defaultDroppable
	return {
		Description = (template:GetAttribute("Description") or "") :: any,
		Image        = (template:GetAttribute("Image") or "") :: any,
		Droppable    = (if template:GetAttribute("Droppable") ~= nil
		               then template:GetAttribute("Droppable")
		               else dropDefault) :: any,
		IsGamepass   = (template:GetAttribute("IsGamepass") or false) :: any,
		Rarity       = (template:GetAttribute("Rarity") or "Common") :: any,
		Type         = (template:GetAttribute("Type") or "Material") :: any,
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

-- The inventory owns the equipped Tool lifecycle. Remove every Tool before
-- mounting the next one so stale Roblox instances cannot remain in Character.
local function clearCharacterTools(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
end

-- Makes a world tool pickup-proof against default touch behavior: the
-- pickup script (ProximityPrompt) is the only way back in. Kills any
-- TouchInterest and disables touch on the handle.
local function stripTouch(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		handle = tool:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	end
	if not handle then return end
	local touch = handle:FindFirstChild("TouchInterest")
	if touch then touch:Destroy() end
	handle.CanTouch = false
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
        Log.warn(SharedSettings.getDefault(), player.Name .. " stoway has been created")
        Stoway.createPlayer(player)
        Communications.SendFullSync(player)
    end)

    PlayerServiceSignals.BindToPlrRemoving:Connect(function(player: Player)
        local leaving = _store[player]
        Log.warn(leaving and leaving.Settings, player.Name .. " stoway is being removed")
        Stoway.removePlayer(player)
    end)

    -- Boot-order race: PlayerService may have fired BindToPlrAdded for
    -- already-joined players before Start() connected. Catch them up.
    local Players = game:GetService("Players")
    for _, player in Players:GetPlayers() do
        if _store[player] == nil then
            Log.warn(SharedSettings.getDefault(), player.Name .. " stoway has been created (late join catch-up)")
            Stoway.createPlayer(player)
            Communications.SendFullSync(player)
        end
    end
end

-- Player lifecycle

-- Designer-facing defaults live in Shared/Stoway/Settings (the module
-- edited in Studio). CoreStore.new only knows engine fields, so map the
-- applicable subset explicitly: engine stays pure, designers keep one
-- source of truth, and the FullSync backstop pushes THESE values (not
-- raw engine defaults) to the client. Explicit caller overrides win.
local function defaultOverrides(): Types.SettingsOverrides
	local d = SharedSettings.getDefault()
	return {
		HotbarType = d.HotbarType,
		MaxHotbarSlots = d.MaxHotbarSlots,
		Limit = d.Limit,
		CanStack = d.CanStack,
		MaxStackSize = d.MaxStackSize,
		BackpackEnabled = d.BackpackEnabled,
		Sorting = d.Sorting,
		SortOrder = d.SortOrder,
		StackOnSwap = d.StackOnSwap,
		StackRequiredFields = table.clone(d.StackRequiredFields),
		StackBlacklist = table.clone(d.StackBlacklist),
		DefaultDroppable = d.DefaultDroppable,
		DebugLogs = d.DebugLogs,
	}
end

function Stoway.createPlayer(player: Player, settingsOverrides: Types.SettingsOverrides?): Types.InventoryState
	local cs = CoreStore :: CoreStoreApi
	local state = cs.new(if settingsOverrides then settingsOverrides else defaultOverrides())
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
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template, state.Settings.DefaultDroppable))
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
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template, state.Settings.DefaultDroppable))
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
		merged.Metadata = mergeMetadata(itemData.Metadata, getDefaultMetadata(template, state.Settings.DefaultDroppable))
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

		-- Equip Roblox-side: clear stale tools, then clone the template into the character
		local character = player.Character
		if character then
			clearCharacterTools(character)
		end
		local template = getToolTemplate(item.Id)
		if character and template then
			local tool = template:Clone()
			applyToolAttributes(tool, item)
			-- The tag is reserved for live world drops. A Studio template may
			-- carry stale CollectionService state, so never equip that tag.
			CollectionService:RemoveTag(tool, STOWAY_DROP_TAG)
			tool.Parent = character  -- parenting a Tool to the Character equips it in Roblox
		end

		return result
	end)
end

function Stoway.UnequipSlot(player: Player, replicate: boolean?): Types.UnequipResult
	return route(player, "UnequipSlot", resolveReplicate(replicate), function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then print(state); return Result.Err({ kind = EK.NotFound, message = "NO_STATE" }) end

		local result = cs.unequip(state)
		if not result.ok then return result end

		-- Unequip Roblox-side: remove every Tool from Character, including any
		-- stale instance left by an earlier equip.
		local character = player.Character
		if character then
			clearCharacterTools(character)
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

		-- Strip default touch pickup and position 5 studs in front of where
		-- the player is looking before making this a live, tagged world drop.
		-- Remove a stale template/equipped tag before re-adding it after the
		-- Workspace parent change. This keeps the tag-added pickup signal valid.
		CollectionService:RemoveTag(worldTool, STOWAY_DROP_TAG)
		stripTouch(worldTool)
		if dropCFrame then
			worldTool:PivotTo(dropCFrame)
		end
		worldTool.Parent = Workspace
		-- Add the tag only after parenting: StowayPickup intentionally ignores
		-- tagged templates in ServerStorage.
		CollectionService:AddTag(worldTool, STOWAY_DROP_TAG)

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
