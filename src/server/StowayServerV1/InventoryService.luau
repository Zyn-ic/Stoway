-- src/server/StowayServerV1/InventoryService.luau
local InventoryService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local InventoryData = require(script.Parent.Classes.InventoryData)
local ItemSpawner = require(script.Parent.Modules.ItemSpawner)
local ChatCommands = require(script.Parent.Modules.ChatCommands)


local PlayerInventories = {} -- [Player] = InventoryData
local ServiceJanitor = Janitor.new()

--// Remotes
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
RemotesFolder.Name = "Remotes"

local function GetRemote(name, class)
	local remote = RemotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(class)
		remote.Name = name
		remote.Parent = RemotesFolder
	end
	return remote
end

local InventoryUpdateRemote = GetRemote("InventoryUpdate", "RemoteEvent")
local InitialSyncRemote = GetRemote("InitialSync", "RemoteFunction")
local SwapSlotsRemote = GetRemote("SwapSlots", "RemoteEvent")
local EquipSlotRemote = GetRemote("EquipSlot", "RemoteEvent")
local UnequipSlotRemote = GetRemote("UnequipSlot", "RemoteEvent")
local RemoveItemRemote = GetRemote("RemoveItem", "RemoteEvent")
local DropItemRemote = GetRemote("DropItem", "RemoteEvent")

--// Private Methods

local function OnPlayerAdded(player: Player)
	local inventory = InventoryData.new(player)
	PlayerInventories[player] = inventory
	
	-- Hook up character spawning logic if needed
	player.CharacterAdded:Connect(function()
		-- Reset equipped state or respawn tool if persistent
		-- For now, reset
		inventory.EquippedItemUUID = nil
	end)

	--// Debug Chat Commands
	ChatCommands.Register(player, InventoryService, PlayerInventories)
	
	print("[InventoryService] Loaded inventory for " .. player.Name)
end

local function OnPlayerRemoving(player: Player)
	-- Save data here (Future implementation)
	PlayerInventories[player] = nil
	print("[InventoryService] Unloaded inventory for " .. player.Name)
end

--// Public API

function InventoryService.AddItem(player: Player, itemId: string, amount: number)
	local inventory = PlayerInventories[player]
	if inventory then
		local success = inventory:AddItem(itemId, amount)
		if success then
			InventoryService.Replicate(player)
		end
		return success
	end
	return false
end

function InventoryService.EquipSlot(player: Player, slotIndex: number)
	local inventory = PlayerInventories[player]
	if not inventory then return end
	
	-- Currently only allowing equipping from Hotbar via hotkey
	-- If UI requests equip from storage, we can support it if needed, but usually storage items must be moved to hotbar
	-- Let's support Hotbar equipping for now.
	local item = inventory:GetItemInSlot("Hotbar", slotIndex) or inventory:GetItemInSlot("Storage", slotIndex)
	
	if item then
		-- Unequip current if any
		if inventory.EquippedItemUUID then
			-- Destroy old tool
			local char = player.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then
					ItemSpawner.DespawnTool(player, tool)
				end
			end
		end

		inventory.EquippedItemUUID = item.UUID
		ItemSpawner.SpawnTool(player, item.Id, item.Metadata)
		InventoryService.Replicate(player)
	end
end

function InventoryService.UnequipSlot(player: Player)
	local inventory = PlayerInventories[player]
	if not inventory or not inventory.EquippedItemUUID then return end
	
	inventory.EquippedItemUUID = nil
	
	-- Find and destroy equipped tool
	local char = player.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			ItemSpawner.DespawnTool(player, tool)
		end
	end
	
	InventoryService.Replicate(player)
end

function InventoryService.SwapSlots(player: Player, slotType1: "Hotbar" | "Storage", slotIndex1: number, slotType2: "Hotbar" | "Storage", slotIndex2: number)
	local inventory = PlayerInventories[player]
	if not inventory then return end
	
	local succ = inventory:SwapSlots(slotType1, slotIndex1, slotType2, slotIndex2)
	if succ then 
		InventoryService.Replicate(player) 
	end
end

function InventoryService.RemoveItem(player: Player, uuid: string, amount: number)
	local inventory = PlayerInventories[player]
	if not inventory then return false end
	
	-- RemoveItem handles setting EquippedItemUUID to nil if the equipped item is removed
	local success = inventory:RemoveItem(uuid, amount)
	
	if success then
		-- If item removed was equipped, we should ensure the physical tool is gone too
		-- RemoveItem in InventoryData sets EquippedItemUUID to nil, so we check that
		if not inventory.EquippedItemUUID then
			local char = player.Character
			if char then
				local tool = char:FindFirstChildOfClass("Tool")
				if tool then tool:Destroy() end
			end
		end
		
		InventoryService.Replicate(player)
	end
	return success
end

function InventoryService.UpdateMetadata(player: Player, uuid: string, updates: { [string]: any })
	local inventory = PlayerInventories[player]
	if not inventory then return false end
	
	local success = inventory:UpdateMetadata(uuid, updates)
	if success then
		-- In a real production environment, you might want to debounce this 
		-- if it's called extremely frequently (e.g. ammo counters)
		InventoryService.Replicate(player)
	end
	return success
end

function InventoryService.DropItem(player: Player, slotType: "Hotbar" | "Storage", slotIndex: number)
	local inventory = PlayerInventories[player]
	if not inventory then
		warn("[InventoryService] No inventory found for player:", player.Name)
		return false
	end
	
	-- Get the item in the slot
	local item = inventory:GetItemInSlot(slotType, slotIndex)
	if not item then
		warn("[InventoryService] No item in slot:", slotType, slotIndex)
		return false
	end
	
	-- If equipped, unequip first
	if inventory.EquippedItemUUID == item.UUID then
		InventoryService.UnequipSlot(player)
	end
	
	-- Drop the item into the world
	ItemSpawner.DropTool(player, item.Id, item.Amount, item.Metadata)
	
	-- Remove from inventory
	inventory:RemoveItem(item.UUID, item.Amount)
	InventoryService.Replicate(player)
	
	return true
end

function InventoryService.Replicate(player: Player)
	local inventory = PlayerInventories[player]
	if inventory then
		-- Serialize data for client
		-- Client expects: { Items: {}, Vector3s? No. }
		-- We need to send Equipped Data. 
		-- We should send the *UUID* that is equipped, and let Client figure out which slot it is.
		-- OR we can send "IsEquipped" flag on items.
		
		-- Let's assume the Client UI iterates slots and checks UUID against EquippedUUID or something?
		-- Or we stick to the plan: Send Items, Hotbar, Storage, and EquippedUUID.
		
		local data = {
			Items = inventory.Items,
			Hotbar = inventory.Hotbar,
			Storage = inventory.Storage,
			EquippedUUID = inventory.EquippedItemUUID
		}
		InventoryUpdateRemote:FireClient(player, data)
	end
end

function InventoryService.Init()
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	
	for _, player in ipairs(Players:GetPlayers()) do
		OnPlayerAdded(player)
	end
	
	-- Networking Hooks
	InitialSyncRemote.OnServerInvoke = function(player)
		local inventory = PlayerInventories[player]
		if inventory then
			return {
				Items = inventory.Items,
				Hotbar = inventory.Hotbar,
				Storage = inventory.Storage,
				EquippedUUID = inventory.EquippedItemUUID
			}
		end
		return nil
	end

	SwapSlotsRemote.OnServerEvent:Connect(function(player, type1, slot1, type2, slot2)
		local inventory = PlayerInventories[player]
		if inventory then
			inventory:SwapSlots(type1, slot1, type2, slot2)
			InventoryService.Replicate(player)
		end
	end)

	EquipSlotRemote.OnServerEvent:Connect(function(player, slotIndex)
		InventoryService.EquipSlot(player, slotIndex)
	end)
	
	UnequipSlotRemote.OnServerEvent:Connect(function(player)
		InventoryService.UnequipSlot(player)
	end)
	
	RemoveItemRemote.OnServerEvent:Connect(function(player, uuid, amount)
		InventoryService.RemoveItem(player, uuid, amount)
	end)
	
	DropItemRemote.OnServerEvent:Connect(function(player, slotType, slotIndex)
		InventoryService.DropItem(player, slotType, slotIndex)
	end)
	
	print("[InventoryService] Initialized V1")
end

ServiceJanitor:Add(function()
	-- Cleanup
end)

return InventoryService
