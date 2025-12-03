-- src/server/StowayServerV1/Classes/InventoryData.luau
local InventoryData = {}
InventoryData.__index = InventoryData

local Settings = require(script.Parent.Parent.Config.Settings)
local InventoryUtils = require(script.Parent.Parent.Modules.InventoryUtils)

export type ItemInstance = {
	UUID: string,
	Id: string,
	Amount: number,
	Metadata: { [string]: any }?
}

export type InventoryData = {
	Player: Player,
	Items: { [string]: ItemInstance }, -- UUID -> Item
	Hotbar: { [number]: string? },     -- Slot -> UUID
	Storage: { [number]: string? },    -- Slot -> UUID
	EquippedSlot: number?,
}

function InventoryData.new(player: Player)
	local self = setmetatable({}, InventoryData)
	self.Player = player
	self.Items = {}
	self.Hotbar = {}
	self.Storage = {}
	self.EquippedSlot = nil
	return self
end

function InventoryData:AddItem(itemId: string, amount: number, metadata: any?): boolean
	-- 1. Try to stack
	if Settings.Storage.CanStack then
		for _, item in pairs(self.Items) do
			if InventoryUtils.CanStack({Id = itemId, Metadata = metadata}, item, Settings.Gameplay.RarityCheck) then
				if item.Amount < Settings.Storage.MaxStackSize then
					local space = Settings.Storage.MaxStackSize - item.Amount
					local toAdd = math.min(amount, space)
					item.Amount += toAdd
					amount -= toAdd
					if amount <= 0 then return true end
				end
			end
		end
	end

	-- 2. Add to empty slot (Hotbar first, then Storage)
	while amount > 0 do
		local uuid = InventoryUtils.GenerateUUID()
		local newAmount = math.min(amount, Settings.Storage.MaxStackSize)
		
		local newItem = {
			UUID = uuid,
			Id = itemId,
			Amount = newAmount,
			Metadata = metadata
		}

		-- Find slot
		local hotbarSlot = InventoryUtils.FindEmptySlot(self.Hotbar, Settings.Hotbar.MaxSlots)
		if hotbarSlot then
			self.Items[uuid] = newItem
			self.Hotbar[hotbarSlot] = uuid
		else
			local storageSlot = InventoryUtils.FindEmptySlot(self.Storage, Settings.Storage.MaxSlots)
			if storageSlot then
				self.Items[uuid] = newItem
				self.Storage[storageSlot] = uuid
			else
				return false -- Full
			end
		end
		
		amount -= newAmount
	end

	return true
end

function InventoryData:RemoveItem(uuid: string, amount: number): boolean
	local item = self.Items[uuid]
	if not item then return false end

	if item.Amount > amount then
		item.Amount -= amount
		return true
	elseif item.Amount == amount then
		self.Items[uuid] = nil
		-- Remove from slots
		for i, id in pairs(self.Hotbar) do if id == uuid then self.Hotbar[i] = nil; break end end
		for i, id in pairs(self.Storage) do if id == uuid then self.Storage[i] = nil; break end end
		return true
	else
		return false -- Not enough
	end
end

function InventoryData:GetItemInSlot(slotType: "Hotbar" | "Storage", slot: number): ItemInstance?
	local uuid
	if slotType == "Hotbar" then
		uuid = self.Hotbar[slot]
	else
		uuid = self.Storage[slot]
	end
	
	if uuid then
		return self.Items[uuid]
	end
	return nil
end

function InventoryData:SwapSlots(fromType: "Hotbar" | "Storage", fromSlot: number, toType: "Hotbar" | "Storage", toSlot: number)
	local fromTable = (fromType == "Hotbar") and self.Hotbar or self.Storage
	local toTable = (toType == "Hotbar") and self.Hotbar or self.Storage
	
	local temp = fromTable[fromSlot]
	fromTable[fromSlot] = toTable[toSlot]
	toTable[toSlot] = temp
end

return InventoryData
