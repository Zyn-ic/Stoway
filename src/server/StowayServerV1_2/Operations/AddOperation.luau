local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AddOperation = {}
local Settings = require(ReplicatedStorage.Shared.Settings)
local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local LimitChecker = require(script.Parent.Parent.Core.LimitChecker)
local StackChecker = require(script.Parent.Parent.Utils.StackChecker)
local MetadataParser = require(script.Parent.Parent.Utils.MetadataParser)
local UUID = require(script.Parent.Parent.Utils.UUID)
local DropOperation = require(script.Parent.DropOperation)
local EquipOperation = require(script.Parent.EquipOperation)

export type AddResult = {
	success: boolean,
	reason: string?,
	addedItems: { { uuid: string, slotType: string, slot: number } }?,
	updatedItems: { [string]: number }?, -- UUID -> New Amount
	addedAmount: number?,   -- How many were actually added
	overflow: number?,       -- How many could NOT be added (for dropping/ignoring)
	equippedUUID: string?   -- UUID of the item that was automatically equipped
}

--// Create a new item instance
local function CreateItem(state: any, itemId: string, amount: number, metadata: any?): any
	local uuid = UUID.Generate()
	local newAmount = math.min(amount, state.Settings.MaxStackSize)

	local item = {
		UUID = uuid,
		Id = itemId,
		Amount = newAmount,
		Metadata = metadata or {}
	}

	-- Add to Items map
	state.Items[uuid] = item

	-- Update ItemsByID lookup
	if not state.ItemsByID[itemId] then
		state.ItemsByID[itemId] = {}
	end
	table.insert(state.ItemsByID[itemId], uuid)

	-- Update weight
	LimitChecker.AddWeight(state, newAmount)

	return item
end

--// Main Execute function
function AddOperation.Execute(state: any, itemId: string, amount: number?, metadataOverrides: any?): AddResult
	-- Prepare metadata (parse from tool + merge overrides)
	-- MetadataParser returns (metadata, defaultAmount) - Amount is excluded from metadata
	local baseMeta, defaultAmount = MetadataParser.FromItemId(itemId)
	local finalMetadata = MetadataParser.Merge(baseMeta, metadataOverrides)

	-- Use passed amount, or fall back to tool's Amount attribute, or default to 1
	local finalAmount = amount or defaultAmount or 1
	local equippedUUID = nil

	-- Validate amount
	if finalAmount <= 0 then
		return { success = false, reason = "INVALID_AMOUNT" }
	end

	local addedItems = {}
	local originalAmount = finalAmount

	-- 1. Cap amount to remaining capacity (partial fill)
	local _amount: number = finalAmount
	if LimitChecker.IsEnabled(state) then
		local remaining = LimitChecker.GetRemainingCapacity(state)
		if remaining <= 0 then
			-- Completely full, nothing can be added
			return { success = false, reason = "FULL", addedAmount = 0, overflow = finalAmount }
		end
		-- Cap to what we can fit
		_amount = math.min(_amount, remaining)
	end

	local amountToAdd = _amount -- Track how much we'll try to add after capping

	-- 2. Try stacking first (StackChecker updates weight internally)
	local updatedItems = {}
	if state.Settings.CanStack then
		local stacked, updates = StackChecker.TryStack(state, itemId, _amount, finalMetadata)
		_amount -= stacked
		updatedItems = updates or {}

		if _amount <= 0 then
			local overflow = originalAmount - amountToAdd
			return { success = true, addedItems = addedItems, updatedItems = updatedItems, addedAmount = amountToAdd, overflow = overflow }
		end
	end

	-- 3. Remaining amount after stacking - create new slots

	-- Check for Backpack Disabled Logic
	if Settings.Storage.BackpackEnabled == false then
		-- Try Hotbar first
		while _amount > 0 do
			local slot = SlotManager.FindEmptyHotbarSlot(state)
			if slot then
				local item = CreateItem(state, itemId, _amount, finalMetadata)
				SlotManager.SetHotbarSlot(state, slot, item.UUID)
				table.insert(addedItems, { uuid = item.UUID, slotType = "Hotbar", slot = slot })
				_amount -= item.Amount
			else
				-- Hotbar is FULL.
				-- Logic: Drop currently equipped item (or slot 1), then place new item there.

				-- 1. Determine Target Slot
				local targetSlot = 1
				equippedUUID = (state.EquippedItemUUID ~= nil)

				if equippedUUID then
					local sType, sIndex = SlotManager.FindSlotByUUID(state, state.EquippedItemUUID)
					if sType == "Hotbar" then
						targetSlot = sIndex
					end
				end

				-- 2. Drop existing item in target slot
				local existingUUID = state.Hotbar[targetSlot]
				if existingUUID then
					-- We force drop. DropOperation handles unequip + remove + spawn.
					-- Note: DropOperation might check Droppable settings.
					-- If dropping is disabled but we are forcing a swap, we might need to override or just Remove.
					-- Requirement says "drop that to the world".

					DropOperation.Execute(state, state.Player, "Hotbar", targetSlot)
				end


				local item = CreateItem(state, itemId, _amount, finalMetadata)
				SlotManager.SetHotbarSlot(state, targetSlot, item.UUID)
				table.insert(addedItems, { uuid = item.UUID, slotType = "Hotbar", slot = targetSlot })

				-- 4. Re-equip new item if previous was equipped
				if equippedUUID then
					EquipOperation.Equip(state, state.Player, item.UUID)
					equippedUUID = item.UUID
				end

				_amount -= item.Amount

				-- Since we are forcing a swap for the remainder, we break loop after one swap?
				-- Usually you pick up one stack/item.
				-- If _amount > maxStack, we might loop.
				-- But for "swap" logic, usually we handle one slot.
				break
			end
		end

	else
		-- Standard Logic (Backpack Enabled)

		-- 3. Try Hotbar first (Static)
		while _amount > 0 do
			local slot = SlotManager.FindEmptyHotbarSlot(state)
			if slot then
				local item = CreateItem(state, itemId, _amount, finalMetadata)
				SlotManager.SetHotbarSlot(state, slot, item.UUID)
				table.insert(addedItems, { uuid = item.UUID, slotType = "Hotbar", slot = slot })
				_amount -= item.Amount
			else
				break
			end
		end

		-- 4. Try Storage (Dynamic Append)
		while _amount > 0 do
			-- If limit is infinite OR we have capacity, allow adding
			if not LimitChecker.IsEnabled(state) or LimitChecker.GetRemainingCapacity(state) > 0 then
				local item = CreateItem(state, itemId, _amount, finalMetadata)
				SlotManager.AppendStorage(state, item.UUID)
				local storageIndex = #state.Storage
				table.insert(addedItems, { uuid = item.UUID, slotType = "Storage", slot = storageIndex })
				_amount -= item.Amount
			else
				break -- No more room
			end
		end
	end

	-- Calculate results
	local addedAmount = amountToAdd - _amount
	local overflow = originalAmount - addedAmount

	return {
		success = addedAmount > 0,
		addedItems = addedItems,
		updatedItems = updatedItems,
		addedAmount = addedAmount,
		overflow = overflow,
		reason = overflow > 0 and "PARTIAL" or nil,
		equippedUUID = equippedUUID
	}
end

return AddOperation
