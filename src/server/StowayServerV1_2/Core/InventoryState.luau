-- src/server/StowayServerV1.2/Core/InventoryState.luau
-- Pure data container for player inventory state
-- Includes per-player settings (defaults from Config, modifiable at runtime)

local InventoryState = {}
InventoryState.__index = InventoryState

local Settings = require(script.Parent.Parent.Config.Settings)

--// Types
export type ItemInstance = {
	UUID: string,
	Id: string,
	Amount: number,
	Metadata: { [string]: any }?
}

export type PlayerSettings = {
	Limit: number,             -- Weight limit (0 = infinite)
	CanStack: boolean,         -- Allow stacking
	MaxStackSize: number,      -- Max items per stack
	MaxHotbarSlots: number,    -- Number of hotbar slots
	Droppable: boolean,        -- Allow dropping
}

export type InventoryStateType = {
	Player: Player,
	Items: { [string]: ItemInstance },      -- UUID -> Item
	ItemsByID: { [string]: { string } },    -- ItemId -> Array of UUIDs (for stacking lookup)
	Hotbar: { [number]: string? },          -- Slot -> UUID (Static: nil holes allowed)
	Storage: { string },                     -- Array of UUIDs (Dynamic: packed, no holes)
	EquippedItemUUID: string?,              -- UUID of currently equipped item
	Weight: number,                          -- Total item count (sum of all stack amounts)
	Settings: PlayerSettings,               -- Per-player settings (modifiable!)
}

--// Constructor
function InventoryState.new(player: Player): InventoryStateType
	local self = setmetatable({}, InventoryState)
	self.Player = player
	self.Items = {}
	self.ItemsByID = {}
	self.Hotbar = {}
	self.Storage = {}
	self.EquippedItemUUID = nil
	self.Weight = 0
	
	-- Per-player settings (defaults from Config)
	self.Settings = {
		Droppable = Settings.Storage.Droppable,
		Limit = Settings.Storage.Limit,
		CanStack = Settings.Storage.CanStack,
		MaxStackSize = Settings.Storage.MaxStackSize,
		MaxHotbarSlots = Settings.Hotbar.MaxSlots,
	}
	
	return self
end

--// Getters (No logic, just data access)
function InventoryState:GetItem(uuid: string): ItemInstance?
	return self.Items[uuid]
end

function InventoryState:GetHotbarUUID(slot: number): string?
	return self.Hotbar[slot]
end

function InventoryState:GetStorageUUID(index: number): string?
	return self.Storage[index]
end

function InventoryState:IsEquipped(uuid: string): boolean
	return self.EquippedItemUUID == uuid
end

return InventoryState

