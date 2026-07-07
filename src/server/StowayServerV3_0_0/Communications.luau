--!strict

--@author: yyumchi
--@date: 2026-07-07
--[[@description:
	Communications adapter for Stoway.
	Creates RemoteEvents and fires intent-based events to clients.
	Registers as an adapter with Stoway — Stoway does not import this module.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Communications = {}

type Adapter = (Player, string, any) -> ()

type StowayApi = {
	registerAdapter: (Adapter) -> (),
}

local _Stoway: StowayApi? = nil
local RemoteFolder: Instance? = nil

local Remotes: { [string]: RemoteEvent } = {}

-- CONSTANTS --
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function ensureRemote(name: string): RemoteEvent
	local existing = Remotes[name]
	if existing then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = RemoteFolder
	Remotes[name] = remote
	return remote
end

local function fireToClient(player: Player, remoteName: string, ...: any)
	local remote = Remotes[remoteName]
	if remote then
		remote:FireClient(player, ...)
	end
end

local function adapter(player: Player, operation: string, result: any)
	if not result.success then
		return
	end

	if operation == "AddItem" or operation == "AddToBackpack" or operation == "AddToHotbar" then
		local addedItems = result.addedItems
		if addedItems then
			for _, added in addedItems do
				fireToClient(player, "InventoryAdded", {
					uuid = added.uuid,
					slotType = added.slotType,
					slot = added.slot,
				})
			end
		end

	elseif operation == "RemoveItem" then
		local removedItem = result.removedItem
		if removedItem then
			fireToClient(player, "InventoryRemoved", {
				uuid = removedItem.UUID,
				slotType = result.slotType,
				slot = result.slot,
			})
		end

	elseif operation == "EquipSlot" then
		fireToClient(player, "InventoryEquipped", {
			uuid = result.uuid,
		})

	elseif operation == "UnequipSlot" then
		fireToClient(player, "InventoryUnequipped", {
			uuid = result.previousUUID,
		})
	end
end

-- PUBLIC FUNCTIONS --
-----------------------------

function Communications.Init(stowayModule: StowayApi, folder: Instance)
	_Stoway = stowayModule
	RemoteFolder = folder

	ensureRemote("InventoryAdded")
	ensureRemote("InventoryRemoved")
	ensureRemote("InventoryEquipped")
	ensureRemote("InventoryUnequipped")

	stowayModule.registerAdapter(adapter)
end

-----------------------------
--MAIN--
-----------------------------

return Communications
