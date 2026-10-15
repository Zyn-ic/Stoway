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

local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local CoreStore = require(ReplicatedStorage.Shared.Stoway.CoreStore)
local Communications = require(ServerScriptService.Services.StowayServerV3_0_0.Communications)
local ConchCommands = require(ServerScriptService.Services.StowayServerV3_0_0.Debug.ConchCommands)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------

Stoway.Init(CoreStore)
Communications.Init(Stoway)
-- Conch console owner (server): lifecycle -> role -> commands -> grants.
ConchCommands.RegisterAll(Stoway)
Communications.Start()
Stoway.Start()

Log.print(nil, "[Stoway] server bootstrap online")
