-- src/server/StowayServerV1.2/init.luau
-- Entry point for Inventory System V1.2

local InventoryService = {}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- Core
local InventoryState = require(script.Core.InventoryState)
local SlotManager = require(script.Core.SlotManager)
local LimitChecker = require(script.Core.LimitChecker)

-- Operations
local AddOperation = require(script.Operations.AddOperation)
local RemoveOperation = require(script.Operations.RemoveOperation)
local SwapOperation = require(script.Operations.SwapOperation)
local EquipOperation = require(script.Operations.EquipOperation)
local DropOperation = require(script.Operations.DropOperation)

-- Replication
local Replicator = require(script.Replication.Replicator)

-- Utils
local MetadataParser = require(script.Utils.MetadataParser)
local UUID = require(script.Utils.UUID)
local StackChecker = require(script.Utils.StackChecker)

-- Debug
local ChatCommands = require(script.Debug.ChatCommands)

-- State
local PlayerInventories: { [Player]: InventoryState.InventoryStateType } = {}
local PlayerOperationLock: { [Player]: boolean } = {} -- Anti-exploit lock

--// ═══════════════════════════════════════════════════════════════════════════
--// PRIVATE: Player Lifecycle
--// ═══════════════════════════════════════════════════════════════════════════

local function OnPlayerAdded(player: Player)
	local state = InventoryState.new(player)
	PlayerInventories[player] = state
	
	player.CharacterAdded:Connect(function()
		state.EquippedItemUUID = nil
		Replicator.SendInit(player, state)
	end)
	
	-- Register debug chat commands
	ChatCommands.Register(player, InventoryService)
	
	print("[InventoryService V1.2] Loaded inventory for", player.Name)
end

local function OnPlayerRemoving(player: Player)
	PlayerInventories[player] = nil
	PlayerOperationLock[player] = nil
	print("[InventoryService V1.2] Unloaded inventory for", player.Name)
end

--// ═══════════════════════════════════════════════════════════════════════════
--// PUBLIC API
--// ═══════════════════════════════════════════════════════════════════════════

function InventoryService.GetState(player: Player): any
	return PlayerInventories[player]
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number, metadata: any?)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	if not ServerStorage.Tools:FindFirstChild(itemId) then return { success = false, reason = "ITEM_NOT_FOUND" } end
	
	local result = AddOperation.Execute(state, itemId, amount, metadata)
	
	if result.success and result.addedItems then
		Replicator.SendAdd(player, result.addedItems, state.Items)
	end
	
	return result
end

function InventoryService.RemoveItem(player: Player, uuid: string, amount: number?)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	local slotType, slot = SlotManager.FindSlotByUUID(state, uuid)
	local result = RemoveOperation.Execute(state, uuid, amount)
	
	if result.success and slotType and slot then
		Replicator.SendRemove(player, slotType, slot, uuid)
	end
	
	return result
end

function InventoryService.SwapSlots(player: Player, fromType: string, fromSlot: number, toType: string, toSlot: number)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	local result = SwapOperation.ExecuteRaw(state, fromType, fromSlot, toType, toSlot)
	return result
end

function InventoryService.EquipSlot(player: Player, slotType: string, slot: number)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	local result = EquipOperation.EquipBySlot(state, player, slotType, slot)
	
	if result.success then
		Replicator.SendEquip(player, result.currentUUID)
	end
	
	return result
end

function InventoryService.UnequipSlot(player: Player)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	local result = EquipOperation.Unequip(state, player)
	
	if result.success then
		Replicator.SendEquip(player, nil)
	end
	
	return result
end

function InventoryService.DropItem(player: Player, slotType: string, slot: number)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	local result = DropOperation.Execute(state, player, slotType, slot)
	
	if result.success then
		Replicator.SendInit(player, state)
	end
	
	return result
end

function InventoryService.UpdateMetadata(player: Player, uuid: string, updates: { [string]: any })
	local state = PlayerInventories[player]
	if not state then return false end
	
	local item = state.Items[uuid]
	if not item then return false end
	
	if not item.Metadata then
		item.Metadata = {}
	end
	
	for k, v in pairs(updates) do
		item.Metadata[k] = v
	end
	
	Replicator.SendUpdateMeta(player, uuid, updates)
	return true
end

--// Stack two slots together (for drag-and-drop stacking)
--// Drags item A onto item B -> B absorbs as much as possible, A keeps remainder
function InventoryService.StackTwoSlots(player: Player, fromType: string, fromSlot: number, toType: string, toSlot: number)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	
	-- Check if stacking is enabled
	if not state.Settings.CanStack then
		return { success = false, reason = "STACKING_DISABLED" }
	end
	
	-- Get UUIDs
	local fromUUID = SlotManager.GetUUIDFromSlot(state, fromType, fromSlot)
	local toUUID = SlotManager.GetUUIDFromSlot(state, toType, toSlot)
	
	if not fromUUID or not toUUID then
		return { success = false, reason = "SLOT_EMPTY" }
	end
	
	local fromItem = state.Items[fromUUID]
	local toItem = state.Items[toUUID]
	
	if not fromItem or not toItem then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end
	
	-- Check if items can stack
	if not StackChecker.CanStack(fromItem, toItem) then
		return { success = false, reason = "CANNOT_STACK" }
	end
	
	-- Check if target is already at max
	local maxStack = state.Settings.MaxStackSize
	if toItem.Amount >= maxStack or fromItem.Amount >= maxStack then
		return { success = false, reason = "STACK_FULL" }
	end
	
	-- Calculate transfer
	local space = maxStack - toItem.Amount
	local transfer = math.min(fromItem.Amount, space)
	
	-- Apply transfer
	toItem.Amount += transfer
	fromItem.Amount -= transfer
	
	-- If source is empty, destroy it
	if fromItem.Amount <= 0 then
		RemoveOperation.Execute(state, fromUUID, fromItem.Amount)
	end
	
	-- Replicate
	Replicator.SendInit(player, state)
	
	return { 
		success = true, 
		transferred = transfer, 
		fromRemaining = fromItem.Amount,
		toAmount = toItem.Amount
	}
end

--// Add item directly to backpack (bypasses hotbar-first logic)
function InventoryService.AddToBackpack(player: Player, itemId: string, amount: number?, metadata: any?)
	local state = PlayerInventories[player]
	if not state then return { success = false, reason = "NO_INVENTORY" } end
	if not ServerStorage.Tools:FindFirstChild(itemId) then return { success = false, reason = "ITEM_NOT_FOUND" } end
	
	-- Get metadata
	local baseMeta, defaultAmount = MetadataParser.FromItemId(itemId)
	local finalMetadata = MetadataParser.Merge(baseMeta, metadata)
	local finalAmount = amount or defaultAmount or 1
	
	-- Validate
	if finalAmount <= 0 then
		return { success = false, reason = "INVALID_AMOUNT" }
	end
	
	-- Check limit
	if LimitChecker.IsEnabled(state) then
		local remaining = LimitChecker.GetRemainingCapacity(state)
		if remaining <= 0 then
			return { success = false, reason = "FULL", addedAmount = 0, overflow = finalAmount }
		end
		finalAmount = math.min(finalAmount, remaining)
	end
	
	local addedItems = {}
	local originalAmount = finalAmount
	
	-- Try stacking first (if enabled)
	if state.Settings.CanStack then
		local stacked = StackChecker.TryStack(state, itemId, finalAmount, finalMetadata)
		finalAmount -= stacked
	end
	
	-- Add remaining to storage directly (bypass hotbar)
	while finalAmount > 0 do
		if not LimitChecker.IsEnabled(state) or LimitChecker.GetRemainingCapacity(state) > 0 then
			local uuid = UUID.Generate()
			local newAmount = math.min(finalAmount, state.Settings.MaxStackSize)
			
			local item = {
				UUID = uuid,
				Id = itemId,
				Amount = newAmount,
				Metadata = finalMetadata or {}
			}
			
			-- Add to Items
			state.Items[uuid] = item
			if not state.ItemsByID[itemId] then
				state.ItemsByID[itemId] = {}
			end
			table.insert(state.ItemsByID[itemId], uuid)
			
			-- Add weight
			LimitChecker.AddWeight(state, newAmount)
			
			-- Add to Storage (not Hotbar!)
			SlotManager.AppendStorage(state, uuid)
			local storageIndex = #state.Storage
			table.insert(addedItems, { uuid = uuid, slotType = "Storage", slot = storageIndex })
			
			finalAmount -= newAmount
		else
			break
		end
	end
	
	-- Replicate
	if #addedItems > 0 then
		Replicator.SendAdd(player, addedItems, state.Items)
	end
	
	local addedAmount = originalAmount - finalAmount
	return { 
		success = addedAmount > 0, 
		addedItems = addedItems, 
		addedAmount = addedAmount, 
		overflow = finalAmount,
		reason = finalAmount > 0 and "PARTIAL" or nil
	}
end

--// ═══════════════════════════════════════════════════════════════════════════
--// NETWORK HOOKS (Anti-Exploit: Single Remote + Per-Player Lock)
--// ═══════════════════════════════════════════════════════════════════════════

-- Operation types (must match client)
local Operations = {
	SWAP = "Swap",
	EQUIP = "Equip",
	UNEQUIP = "Unequip",
	REMOVE = "Remove",
	DROP = "Drop",
	STACK = "Stack",
}

-- Operation handlers
local OperationHandlers = {
	[Operations.SWAP] = function(player, args)
		return InventoryService.SwapSlots(player, args.fromType, args.fromSlot, args.toType, args.toSlot)
	end,
	[Operations.EQUIP] = function(player, args)
		return InventoryService.EquipSlot(player, args.slotType or "Hotbar", args.slot)
	end,
	[Operations.UNEQUIP] = function(player, _args)
		return InventoryService.UnequipSlot(player)
	end,
	[Operations.REMOVE] = function(player, args)
		return InventoryService.RemoveItem(player, args.uuid, args.amount)
	end,
	[Operations.DROP] = function(player, args)
		return InventoryService.DropItem(player, args.slotType, args.slot)
	end,
	[Operations.STACK] = function(player, args)
		return InventoryService.StackTwoSlots(player, args.fromType, args.fromSlot, args.toType, args.toSlot)
	end,
}

local function SetupRemotes()
	local remotesFolder = Replicator.GetRemotesFolder()
	
	local function GetOrCreateRemote(name: string, class: string)
		local remote = remotesFolder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(class)
			remote.Name = name
			remote.Parent = remotesFolder
		end
		return remote
	end
	
	-- InitialSync (Client requests full state) - No lock needed, read-only
	local InitialSyncRemote = GetOrCreateRemote("InitialSync", "RemoteFunction")
	InitialSyncRemote.OnServerInvoke = function(player)
		-- Anti-exploit: Check if player is locked
		if PlayerOperationLock[player] then
			return { success = false, reason = "OPERATION_IN_PROGRESS" }
		end
		
		PlayerOperationLock[player] = true

		task.delay(3, function()
			if PlayerOperationLock[player] then
				PlayerOperationLock[player] = nil
			end
		end)

		local state = PlayerInventories[player]
		if state then
			PlayerOperationLock[player] = nil
			return Replicator.SendInit(player, state)
		end
		return nil
	end
	
	-- UNIFIED REMOTE: InventoryAction (All operations go through here)
	local InventoryActionRemote = GetOrCreateRemote("InventoryAction", "RemoteFunction")
	InventoryActionRemote.OnServerInvoke = function(player, operation: string, args: any)
		-- Anti-exploit: Check if player is locked
		if PlayerOperationLock[player] then
			return { success = false, reason = "OPERATION_IN_PROGRESS" }
		end
		
		-- Validate operation
		local handler = OperationHandlers[operation]
		if not handler then
			return { success = false, reason = "INVALID_OPERATION" }
		end
		
		-- Validate args
		if args == nil or type(args) ~= "table" then
			return { success = false, reason = "INVALID_ARGS" }
		end
		
		-- Lock player
		PlayerOperationLock[player] = true

		-- In case a function is taking too long
		task.delay(3, function()
			if PlayerOperationLock[player] then
				PlayerOperationLock[player] = nil
			end
		end)
		
		-- Execute operation (wrapped in pcall for safety)
		local success, result = pcall(function()
			return handler(player, args)
		end)
		
		-- Unlock player
		PlayerOperationLock[player] = nil
		
		-- Handle pcall failure
		if not success then
			warn("[InventoryService] Operation error for", player.Name, ":", result)
			return { success = false, reason = "SERVER_ERROR" }
		end
		
		return result
	end
end

--// ═══════════════════════════════════════════════════════════════════════════
--// INIT
--// ═══════════════════════════════════════════════════════════════════════════

function InventoryService.Init()
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	
	-- Handle existing players (studio test)
	for _, player in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end
	
	SetupRemotes()
	
	print("[InventoryService V1.2] Initialized")
end

return InventoryService
