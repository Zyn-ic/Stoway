-- src/server/StowayServerV1.2/Debug/ChatCommands.luau
-- Debug chat commands for testing the inventory system

local ChatCommands = {}

function ChatCommands.Register(player: Player, InventoryService: any)
	player.Chatted:Connect(function(msg)
		local args = string.split(msg, " ")
		local cmd = string.lower(args[1])
		local state = InventoryService.GetState(player)
		
		if not state then return end
		
		--// ═══════════════════════════════════════════════════════════════════
		--// INVENTORY DISPLAY
		--// ═══════════════════════════════════════════════════════════════════
		
		if cmd == "/inv" then
			print("═══════════════════════════════════════════════════════════════")
			print("INVENTORY for " .. player.Name)
			print("───────────────────────────────────────────────────────────────")
			print("Weight:", state.Weight, "/", state.Settings.Limit, "(0 = Infinite)")
			print("CanStack:", state.Settings.CanStack, "| MaxStack:", state.Settings.MaxStackSize)
			print("Equipped UUID:", state.EquippedItemUUID or "None")
			print("───────────────────────────────────────────────────────────────")
			print("HOTBAR (max " .. state.Settings.MaxHotbarSlots .. "):")
			for i = 1, state.Settings.MaxHotbarSlots do
				local uuid = state.Hotbar[i]
				if uuid then
					local item = state.Items[uuid]
					if item then
						print("  [" .. i .. "]", item.Id, "x" .. item.Amount, "(UUID:" .. uuid .. ")")
					else
						print("  [" .. i .. "] (ORPHAN UUID:" .. uuid .. ")")
					end
				else
					print("  [" .. i .. "] (empty)")
				end
			end
			print("STORAGE:", "#" .. #state.Storage)
			for i, uuid in ipairs(state.Storage) do
				local item = state.Items[uuid]
				if item then
					print("  [" .. i .. "]", item.Id, "x" .. item.Amount, "(UUID:" .. uuid .. ")")
				else
					print("  [" .. i .. "] (ORPHAN UUID:" .. uuid .. ")")
				end
			end
			print("═══════════════════════════════════════════════════════════════")
		
		--// ═══════════════════════════════════════════════════════════════════
		--// ADD ITEM
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/add" then
			-- /add [itemId] [amount?]
			local itemId = args[2]
			local amount = tonumber(args[3])
			if itemId then
				local result = InventoryService.AddItem(player, itemId, amount)
				print("[Add]", itemId)
				print("  Success:", result.success)
				print("  Added:", result.addedAmount or "?")
				print("  Overflow:", result.overflow or 0)
				print("  Reason:", result.reason or "OK")
			else
				print("Usage: /add [itemId] [amount?]")
			end
		
		elseif cmd == "/addback" then
			-- /addback [itemId] [amount?] - Add directly to backpack (bypasses hotbar)
			local itemId = args[2]
			local amount = tonumber(args[3])
			if itemId then
				local result = InventoryService.AddToBackpack(player, itemId, amount)
				print("[AddToBackpack]", itemId)
				print("  Success:", result.success)
				print("  Added:", result.addedAmount or "?")
				print("  Overflow:", result.overflow or 0)
				print("  Reason:", result.reason or "OK")
			else
				print("Usage: /addback [itemId] [amount?]")
			end
		
		elseif cmd == "/stack" then
			-- /stack [fromType] [fromSlot] [toType] [toSlot]
			local fromType = args[2]
			local fromSlot = tonumber(args[3])
			local toType = args[4]
			local toSlot = tonumber(args[5])
			if fromType and fromSlot and toType and toSlot then
				local result = InventoryService.StackTwoSlots(player, fromType, fromSlot, toType, toSlot)
				print("[Stack]", fromType, fromSlot, "->", toType, toSlot)
				print("  Success:", result.success)
				print("  Transferred:", result.transferred or 0)
				print("  From Remaining:", result.fromRemaining or 0)
				print("  To Amount:", result.toAmount or 0)
				print("  Reason:", result.reason or "OK")
			else
				print("Usage: /stack [Hotbar/Storage] [slot] [Hotbar/Storage] [slot]")
			end
		
		--// ═══════════════════════════════════════════════════════════════════
		--// REMOVE ITEM
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/remove" then
			-- /remove [uuid] [amount?]
			local uuid = args[2]
			local amount = tonumber(args[3])
			if uuid then
				local result = InventoryService.RemoveItem(player, uuid, amount)
				print("[Remove]", uuid)
				print("  Success:", result.success)
				print("  Remaining:", result.remaining or 0)
				print("  Reason:", result.reason or "OK")
			else
				print("Usage: /remove [uuid] [amount?]")
			end
		
		--// ═══════════════════════════════════════════════════════════════════
		--// SWAP
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/swap" then
			-- /swap [fromType] [fromSlot] [toType] [toSlot]
			local fromType = args[2]
			local fromSlot = tonumber(args[3])
			local toType = args[4]
			local toSlot = tonumber(args[5])
			if fromType and fromSlot and toType and toSlot then
				local result = InventoryService.SwapSlots(player, fromType, fromSlot, toType, toSlot)
				print("[Swap]", fromType, fromSlot, "->", toType, toSlot)
				print("  Success:", result.success)
				print("  Reason:", result.reason or "OK")
			else
				print("Usage: /swap [Hotbar/Storage] [slot] [Hotbar/Storage] [slot]")
			end
		
		--// ═══════════════════════════════════════════════════════════════════
		--// EQUIP / UNEQUIP
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/equip" then
			-- /equip [slot] or /equip [type] [slot]
			local slotType = "Hotbar"
			local slot
			if tonumber(args[2]) then
				slot = tonumber(args[2])
			else
				slotType = args[2] or "Hotbar"
				slot = tonumber(args[3])
			end
			if slot then
				local result = InventoryService.EquipSlot(player, slotType, slot)
				print("[Equip]", slotType, slot)
				print("  Success:", result.success)
				print("  Equipped UUID:", result.currentUUID or "None")
			else
				print("Usage: /equip [slot] or /equip [type] [slot]")
			end
		
		elseif cmd == "/unequip" then
			local result = InventoryService.UnequipSlot(player)
			print("[Unequip]")
			print("  Success:", result.success)
		
		--// ═══════════════════════════════════════════════════════════════════
		--// DROP
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/drop" then
			-- /drop [type] [slot]
			local slotType = args[2]
			local slot = tonumber(args[3])
			if slotType and slot then
				local result = InventoryService.DropItem(player, slotType, slot)
				print("[Drop]", slotType, slot)
				print("  Success:", result.success)
			else
				print("Usage: /drop [Hotbar/Storage] [slot]")
			end
		
		--// ═══════════════════════════════════════════════════════════════════
		--// SETTINGS TOGGLE (PER-PLAYER!)
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/toggle_stack" then
			state.Settings.CanStack = not state.Settings.CanStack
			print("[Settings] CanStack:", state.Settings.CanStack)
		
		elseif cmd == "/toggle_limit" then
			if state.Settings.Limit == 0 then
				state.Settings.Limit = 15
			else
				state.Settings.Limit = 0
			end
			print("[Settings] Limit:", state.Settings.Limit, "(0 = Infinite)")
		
		elseif cmd == "/set_limit" then
			local newLimit = tonumber(args[2]) or 15
			state.Settings.Limit = newLimit
			print("[Settings] Limit set to:", newLimit)
		
		elseif cmd == "/set_max_stack" then
			local newMax = tonumber(args[2]) or 5
			state.Settings.MaxStackSize = newMax
			print("[Settings] MaxStackSize set to:", newMax)
		
		elseif cmd == "/set_hotbar_slots" then
			local newSlots = tonumber(args[2]) or 9
			state.Settings.MaxHotbarSlots = newSlots
			print("[Settings] MaxHotbarSlots set to:", newSlots)
		
		--// ═══════════════════════════════════════════════════════════════════
		--// CLEAR INVENTORY
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/clear" then
			local uuidsToRemove = {}
			for uuid, _ in pairs(state.Items) do
				table.insert(uuidsToRemove, uuid)
			end
			for _, uuid in pairs(uuidsToRemove) do
				InventoryService.RemoveItem(player, uuid)
			end
			print("[Clear] Inventory cleared")
		
		--// ═══════════════════════════════════════════════════════════════════
		--// HELP
		--// ═══════════════════════════════════════════════════════════════════
		
		elseif cmd == "/help" then
			print("═══════════════════════════════════════════════════════════════")
			print("INVENTORY DEBUG COMMANDS")
			print("───────────────────────────────────────────────────────────────")
			print("/inv              - Display inventory state")
			print("/add [id] [amt?]  - Add item (hotbar first)")
			print("/addback [id] [amt?] - Add directly to backpack")
			print("/remove [uuid] [amt?] - Remove item by UUID")
			print("/swap [t1] [s1] [t2] [s2] - Swap slots")
			print("/stack [t1] [s1] [t2] [s2] - Stack items together")
			print("/equip [slot]     - Equip from hotbar")
			print("/unequip          - Unequip current")
			print("/drop [type] [slot] - Drop item")
			print("/clear            - Clear inventory")
			print("───────────────────────────────────────────────────────────────")
			print("/toggle_stack       - Toggle stacking on/off (per-player)")
			print("/toggle_limit       - Toggle limit (0=infinite / 15)")
			print("/set_limit [n]      - Set weight limit")
			print("/set_max_stack [n]  - Set max stack size")
			print("/set_hotbar_slots [n] - Set hotbar slot count")
			print("═══════════════════════════════════════════════════════════════")
		end
	end)
	
	print("[Debug] Chat commands registered for", player.Name, "- Type /help")
end

return ChatCommands

