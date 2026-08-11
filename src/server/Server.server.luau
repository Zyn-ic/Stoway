--!strict

--@author: yyumchi
--@date: 2026-08-08
--[[@description:
	Stoway server bootstrap — the Server script.
	Injects CoreStore, registers the QuickNet Communications adapter,
	starts Stoway player lifecycle wiring, and registers debug chat commands.
]]
-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local PlayerServiceSignals = require(ServerScriptService.Libraries.PlayerServiceSignals)
local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local CoreStore = require(ServerScriptService.Services.StowayServerV3_0_0.CoreStore)
local Communications = require(ServerScriptService.Services.StowayServerV3_0_0.Communications)
local ChatCommands = require(ServerScriptService.Services.StowayServerV3_0_0.Debug.ChatCommands)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function registerChatCommands(player: Player)
	ChatCommands.Register(player, Stoway)
end

-----------------------------
-- MAIN --
-----------------------------

Stoway.Init(CoreStore)
Communications.Init(Stoway)
Stoway.Start()

PlayerServiceSignals.BindToPlrAdded:Connect(registerChatCommands)
for _, player in Players:GetPlayers() do
	registerChatCommands(player)
end

print("[Stoway] server bootstrap online")
