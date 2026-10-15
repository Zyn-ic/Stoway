--!strict

--@author: yyumchi
--@date: 2026-10-14
--[[@description:
	Showcase glue (not system): tracks each player's side (cop vs
	criminal) and stamps future adds to match, so picked items never show
	up grey. Thief and Cop scripts share this module. Self-initializes on
	require: connects PlayerRemoving cleanup and registers one team-guard
	adapter. UpdateMetadata results are ignored, so stamps never loop.
	Studio only (required exclusively by Studio-only showcase scripts).
]]
-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local Protocol = require(ServerScriptService.Services.StowayServerV3_0_0.Protocol)

local Sides = {}

local sides: { [Player]: string } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function installTeamGuard()
	Stoway.registerAdapter(function(player: Player, signal: Protocol.Signal)
		if signal.operation ~= "AddItem" and signal.operation ~= "AddToBackpack" and signal.operation ~= "AddToHotbar" then
			return
		end
		-- Cast is intentional: result payloads differ per operation, and
		-- the operation guard above already selected the Add shape
		-- (same idiom as Communications' adapter).
		local result = signal.result :: any
		if not result.ok then
			return
		end
		local side = sides[player]
		if side ~= "Police" and side ~= "Criminal" then
			return
		end
		local added = result.value.addedItems
		if typeof(added) ~= "table" then
			return
		end
		-- Deferred: dispatch runs inside the completed route while it still
		-- holds the per-player lock. Stamping now would hit
		-- OPERATION_IN_PROGRESS; next frame the lock is free.
		task.defer(function()
			if Stoway.get(player) == nil then
				return
			end
			for _, entry in added do
				Stoway.UpdateMetadata(player, entry.uuid, { Team = side }, true)
			end
		end)
	end)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Sides.set(player: Player, side: string)
	sides[player] = side
end

function Sides.get(player: Player): string?
	return sides[player]
end

function Sides.isCop(player: Player): boolean
	return sides[player] == "Police"
end

-----------------------------
-- MAIN --
-----------------------------

Players.PlayerRemoving:Connect(function(player: Player)
	sides[player] = nil
end)

installTeamGuard()

return Sides
