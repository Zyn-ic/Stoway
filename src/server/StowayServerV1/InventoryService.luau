-- src/server/StowayServerV1/InventoryService.luau
local InventoryService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local InventoryData = require(script.Parent.Classes.InventoryData)
local ItemSpawner = require(script.Parent.Modules.ItemSpawner)
--local Settings = require(script.Parent.Config.Settings)

local PlayerInventories = {} -- [Player] = InventoryData
local ServiceJanitor = Janitor.new()

--// Remotes
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
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

--// Private Methods

local function OnPlayerAdded(player: Player)
	local inventory = InventoryData.new(player)
	PlayerInventories[player] = inventory
	
	-- Hook up character spawning logic if needed
	player.CharacterAdded:Connect(function()
		-- Reset equipped state or respawn tool if persistent
		inventory.EquippedSlot = nil
	end)

	--// Debug Chat Commands
	player.Chatted:Connect(function(msg)
		local args = string.split(msg, " ")
		local cmd = string.lower(args[1])

		if cmd == "/inv" then
			print("--- Inventory for " .. player.Name .. " ---")
			print("Hotbar:", inventory.Hotbar)
			print("Storage:", inventory.Storage)
			print("Items:", inventory.Items)
			print("--------------------------------")
		
		elseif cmd == "/add" then
			-- /add [id] [amount]
			local id = args[2]
			local amount = tonumber(args[3]) or 1
			if id then
				InventoryService.AddItem(player, id, amount)
				print("Added", amount, id)
			end

		elseif cmd == "/remove" then
			-- /remove [uuid] [amount]
			local uuid = args[2]
			local amount = tonumber(args[3]) or 1
			if uuid then
				local success = inventory:RemoveItem(uuid, amount)
				if success then
					print("Removed item", uuid)
					InventoryService.Replicate(player)
				else
					warn("Failed to remove item")
				end
			end

		elseif cmd == "/swap" then
			-- /swap [Hotbar/Storage] [slot1] [Hotbar/Storage] [slot2]
			-- Example: /swap Hotbar 1 Hotbar 2
			local type1 = args[2]
			local slot1 = tonumber(args[3])
			local type2 = args[4]
			local slot2 = tonumber(args[5])
			
			if type1 and slot1 and type2 and slot2 then
				inventory:SwapSlots(type1, slot1, type2, slot2)
				print("Swapped slots")
				InventoryService.Replicate(player)
			end

		elseif cmd == "/equip" then
			-- /equip [slot]
			local slot = tonumber(args[2])
			if slot then
				InventoryService.EquipSlot(player, slot)
				print("Equipped slot", slot)
			end
		end
	end)
	
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
	
	-- If already equipped, unequip
	if inventory.EquippedSlot == slotIndex then
		local currentItem = inventory:GetItemInSlot("Hotbar", slotIndex)
		if currentItem then
			-- Find tool and destroy
			local char = player.Character
			if char then
				local tool = char:FindFirstChildWhichIsA("Tool")
				if tool then tool:Destroy() end
			end
		end
		inventory.EquippedSlot = nil
		InventoryService.Replicate(player) -- Update client equipped state
		return
	end
	
	-- Unequip old
	if inventory.EquippedSlot then
		local char = player.Character
		if char then
			local tool = char:FindFirstChildWhichIsA("Tool")
			if tool then tool:Destroy() end
		end
	end
	
	-- Equip new
	local item = inventory:GetItemInSlot("Hotbar", slotIndex)
	if item then
		ItemSpawner.SpawnTool(player, item.Id, item.Metadata)
		inventory.EquippedSlot = slotIndex
	end
	InventoryService.Replicate(player)
end

function InventoryService.Replicate(player: Player)
	local inventory = PlayerInventories[player]
	if inventory then
		local data = {
			Items = inventory.Items,
			Hotbar = inventory.Hotbar,
			Storage = inventory.Storage,
			EquippedSlot = inventory.EquippedSlot
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
				EquippedSlot = inventory.EquippedSlot
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
	
	print("[InventoryService] Initialized V1")
end

ServiceJanitor:Add(function()
	-- Cleanup
end)

return InventoryService
