-- src/server/StowayServerV1/Modules/ChatCommands.luau
local ChatCommands = {}

function ChatCommands.Register(player: Player, InventoryService: any, PlayerInventories: { [Player]: any })
	player.Chatted:Connect(function(msg)
		local args = string.split(msg, " ")
		local cmd = string.lower(args[1])
		local inventory = PlayerInventories[player]

		if not inventory then return end

		if cmd == "/inv" then
			print("--- Inventory for " .. player.Name .. " ---")
			print("Hotbar:", inventory.Hotbar)
			print("Storage:", inventory.Storage)
			print("Items:", inventory.Items)
			
			-- Resolve Equipped Slot from UUID
			local equippedInfo = "None"
			if inventory.EquippedItemUUID then
				local hotbartest = table.find(inventory.Hotbar, inventory.EquippedItemUUID)
				local storagetest = table.find(inventory.Storage, inventory.EquippedItemUUID)
				equippedInfo = hotbartest and "Hotbar Slot: " .. hotbartest or storagetest and "Storage Slot: " .. storagetest or "Not in slots?"
			end
			print("Equipped:", equippedInfo)
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
				local success = InventoryService.RemoveItem(player, uuid, amount)
				if success then
					print("Removed item", uuid)
				else
					print("Failed to remove item (not found or insufficient)")
				end
			end

		elseif cmd == "/swap" then
			-- /swap [Hotbar/Storage] [slot1] [Hotbar/Storage] [slot2]
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
			
		elseif cmd == "/unequip" then
			-- /unequip
			InventoryService.UnequipSlot(player)
			print("Unequipped")
			
		elseif cmd == "/drop" then
			-- /drop [Hotbar/Storage] [slot]
			local slotType = args[2]
			local slotIndex = tonumber(args[3])
			
			if slotType and slotIndex then
				if slotType ~= "Hotbar" and slotType ~= "Storage" then
					print("Invalid slot type. Use 'Hotbar' or 'Storage'")
					return
				end
				
				local success = InventoryService.DropItem(player, slotType, slotIndex)
				if success then
					print("Dropped item from", slotType, slotIndex)
				else
					print("Failed to drop item")
				end
			end
		end
	end)
end

return ChatCommands
