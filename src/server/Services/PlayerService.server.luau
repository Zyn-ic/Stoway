--@author: yyumchi
--@date: 2026-05-19
--[[@description:
	Player lifecycle service handling add/remove/character/death.
	Fires PlayerServiceSignals for other systems to hook into.
]]
-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PlayerServiceSignals = require(ServerScriptService.Libraries.PlayerServiceSignals)

-----------------------------
-- VARIABLES --
-----------------------------

type PlayerRecord = {
	IsDead: boolean,
	Janitor: any,
}

local serviceJanitor = Janitor.new()
local playerRecords: {[Player]: PlayerRecord} = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function debugPrint(message: string)
	print(("[PlayerService][%.3f] %s"):format(workspace:GetServerTimeNow(), message))
end

local function getHumanoid(character: Model): Humanoid?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	local found = character:WaitForChild("Humanoid", 5)
	if found and found:IsA("Humanoid") then
		return found
	end

	return nil
end

local function onCharacterAdded(player: Player, character: Model)
	local record = playerRecords[player]
	if not record then
		return
	end

	record.IsDead = false
	debugPrint(("character added: %s"):format(player.Name))
	PlayerServiceSignals.BindToCharAdded:Fire(player, character)

	local humanoid = getHumanoid(character)
	if not humanoid then
		warn(("[PlayerService] missing humanoid for %s"):format(player.Name))
		return
	end

	record.Janitor:Add(humanoid.Died:Once(function()
		record.IsDead = true
		debugPrint(("player died: %s"):format(player.Name))
		PlayerServiceSignals.BindToPlrHasDied:Fire(player)
	end), "Disconnect")
end

local function onPlayerAdded(player: Player)
	if playerRecords[player] then
		return
	end

	local playerJanitor = Janitor.new()
	playerRecords[player] = {
		IsDead = false,
		Janitor = playerJanitor,
	}

	debugPrint(("player added: %s"):format(player.Name))
	PlayerServiceSignals.BindToPlrAdded:Fire(player)

	playerJanitor:Add(player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end), "Disconnect")

	if player.Character then
		task.defer(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local record = playerRecords[player]
	if not record then
		return
	end

	debugPrint(("player removing: %s"):format(player.Name))
	PlayerServiceSignals.BindToPlrRemoving:Fire(player)

	record.Janitor:Cleanup()
	playerRecords[player] = nil
end

-----------------------------
-- HANDLERS --
-----------------------------

serviceJanitor:Add(Players.PlayerAdded:Connect(onPlayerAdded), "Disconnect")
serviceJanitor:Add(Players.PlayerRemoving:Connect(onPlayerRemoving), "Disconnect")

-----------------------------
-- MAIN --
-----------------------------

for _, player in Players:GetPlayers() do
	task.defer(onPlayerAdded, player)
end

game:BindToClose(function()
	serviceJanitor:Cleanup()

	for _, record in playerRecords do
		record.Janitor:Cleanup()
	end

	table.clear(playerRecords)

	PlayerServiceSignals.BindToPlrAdded:DisconnectAll()
	PlayerServiceSignals.BindToCharAdded:DisconnectAll()
	PlayerServiceSignals.BindToPlrHasDied:DisconnectAll()
	PlayerServiceSignals.BindToPlrRemoving:DisconnectAll()
end)
