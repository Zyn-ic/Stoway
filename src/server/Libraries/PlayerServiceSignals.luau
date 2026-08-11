local SignalPlus = require(game:GetService("ReplicatedStorage").Packages.SignalPlus)

local PlayerServiceSignals = {}
PlayerServiceSignals.BindToPlrHasDied = SignalPlus() :: SignalPlus.Signal<Player>
PlayerServiceSignals.BindToPlrAdded = SignalPlus() :: SignalPlus.Signal<Player>
PlayerServiceSignals.BindToCharAdded = SignalPlus() :: SignalPlus.Signal<Player, Model>
PlayerServiceSignals.BindToPlrRemoving = SignalPlus() :: SignalPlus.Signal<Player>

return PlayerServiceSignals
