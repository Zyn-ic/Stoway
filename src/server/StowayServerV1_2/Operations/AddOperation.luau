-- src/server/StowayServerV1.2/Operations/AddOperation.luau
-- Handles full Add logic flow: Limit Check → Stack → Hotbar → Storage
-- Uses state.Settings (per-player) for limits and stacking

local AddOperation = {}
local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local LimitChecker = require(script.Parent.Parent.Core.LimitChecker)
local StackChecker = require(script.Parent.Parent.Utils.StackChecker)
local MetadataParser = require(script.Parent.Parent.Utils.MetadataParser)
local UUID = require(script.Parent.Parent.Utils.UUID)

export type AddResult = {
	success: boolean,
	reason: string?,
	addedItems: { { uuid: string, slotType: string, slot: number } }?,
	updatedItems: { [string]: number }?, -- UUID -> New Amount
	addedAmount: number?,   -- How many were actually added
	overflow: number?       -- How many could NOT be added (for dropping/ignoring)
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
	
	-- Calculate results
	local addedAmount = amountToAdd - _amount
	local overflow = originalAmount - addedAmount
	
	return { 
		success = addedAmount > 0, 
		addedItems = addedItems, 
		updatedItems = updatedItems,
		addedAmount = addedAmount, 
		overflow = overflow,
		reason = overflow > 0 and "PARTIAL" or nil
	}
end

return AddOperation

