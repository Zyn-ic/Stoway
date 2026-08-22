--!strict

--@author: yyumchi
--@date: 2026-08-21
--[[@description:
	Local SignalPlus bus mirroring master NetworkHandler pattern.
	No Roblox Remotes – pure in-memory signals for mock-phase client tests.
	Each signal corresponds to a CoreStore operation. ClientController connects
	to these and performs clone->mutate->set on ClientStore atoms so Fusion
	recomputes atomically (same as master InventoryController).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalPlus = require(ReplicatedStorage.Packages.SignalPlus)
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

local Signals = {}

-----------------------------
-- SIGNALS --
-----------------------------

-- Mirrors PlayerServiceSignals pattern: typed SignalPlus buses
Signals.Swap = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotRef, CoreTypes.SlotRef>
Signals.SwapStack = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotRef, CoreTypes.SlotRef>
Signals.Move = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotRef, CoreTypes.SlotRef>
Signals.Remove = SignalPlus() :: SignalPlus.Signal<string, number?>
Signals.Add = SignalPlus() :: SignalPlus.Signal<CoreTypes.ItemInput, CoreTypes.AddOptions?>
Signals.Split = SignalPlus() :: SignalPlus.Signal<string, number, CoreTypes.SlotRef?>
Signals.Equip = SignalPlus() :: SignalPlus.Signal<string>
Signals.Unequip = SignalPlus() :: SignalPlus.Signal<>

-----------------------------
-- MAIN --
-----------------------------

return Signals
