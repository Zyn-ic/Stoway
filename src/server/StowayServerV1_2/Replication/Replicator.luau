-- src/server/StowayServerV1.2/Replication/Replicator.luau
-- Centralized delta replication dispatcher

local Replicator = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Actions = require(script.Parent.Actions)

-- Remote setup
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

local function GetRemote(name: string, class: string): any
	local remote = RemotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(class)
		remote.Name = name
		remote.Parent = RemotesFolder
	end
	return remote
end

-- Main event for inventory updates
local InventoryUpdateRemote = GetRemote("InventoryUpdate", "RemoteEvent")

--// Send delta update to player
function Replicator.Send(player: Player, action: string, payload: any)
	InventoryUpdateRemote:FireClient(player, action, payload)
end

--// Convenience methods for each action type
function Replicator.SendInit(player: Player, state: any)
	local payload = Actions.Init(state)
	Replicator.Send(player, Actions.Types.INIT, payload)
end

function Replicator.SendAdd(player: Player, addedItems: any, items: any)
	local payload = Actions.Add(addedItems, items)
	Replicator.Send(player, Actions.Types.ADD, payload)
end

function Replicator.SendRemove(player: Player, slotType: string, slot: number, uuid: string)
	local payload = Actions.Remove(slotType, slot, uuid)
	Replicator.Send(player, Actions.Types.REMOVE, payload)
end

function Replicator.SendSwap(player: Player, fromType: string, fromSlot: number, toType: string, toSlot: number)
	local payload = Actions.Swap(fromType, fromSlot, toType, toSlot)
	Replicator.Send(player, Actions.Types.SWAP, payload)
end

function Replicator.SendEquip(player: Player, uuid: string?)
	local payload = Actions.Equip(uuid)
	Replicator.Send(player, Actions.Types.EQUIP, payload)
end

function Replicator.SendUpdateSettings(player: Player, Settings: any?)
	if player and Settings then
		local payload = Actions.UpdateSettings(Settings)
		Replicator.Send(player, Actions.Types.UPDATE_SETTINGS, payload)
	end
end

function Replicator.SendReload(player: Player, configSettingName: string, data: any)
	if player and configSettingName then
		local playload = Actions.Reload(configSettingName, data)
		Replicator.Send(player, Actions.Types.RELOAD, playload)
	end
end

function Replicator.SendUpdateMeta(player: Player, uuid: string, updates: { [string]: any }, newWeight)
	local payload = Actions.UpdateMeta(uuid, updates, newWeight)
	Replicator.Send(player, Actions.Types.RELOAD, payload)
end

--// Initial Sync Request Handling
local InitialSyncRemote = GetRemote("AskForStoway", "RemoteFunction")

function Replicator.RegisterInitialSyncCallback(callback: (Player) -> any)
	InitialSyncRemote.OnServerInvoke = callback
end

--// Get remote for external access (e.g., InitialSync)
function Replicator.GetRemotesFolder(): Folder
	return RemotesFolder
end

return Replicator
