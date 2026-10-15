--@author: yyumchi
--@date: 2026-10-15
--[[@description:
	Gated system logging. print/warn go through here with the active
	Settings so flipping Settings.DebugLogs silences the whole system.
	Fail-open: nil settings log (diagnostics matter most when state is
	absent). Hook output (ClientEvents) and console output (conch) stay on
	their own paths by design.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.CoreStore.Types)

local Log = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Log.enabled(settings: Types.Settings?): boolean
	return settings == nil or settings.DebugLogs ~= false
end

function Log.print(settings: Types.Settings?, ...: unknown)
	if Log.enabled(settings) then
		print(...)
	end
end

function Log.warn(settings: Types.Settings?, ...: unknown)
	if Log.enabled(settings) then
		warn(...)
	end
end

-----------------------------
-- MAIN --
-----------------------------

return Log
