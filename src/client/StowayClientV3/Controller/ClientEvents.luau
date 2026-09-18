--!strict

--@author: yyumchi
--@date: 2026-09-18
--[[@description:
	Generic client UI event bus (Layer 1). Fixed minimal payloads
	(slotType, index, uuid) typed once with SignalPlus, stable forever.
	External systems subscribe here; skin HookFuncs modules are
	privileged subscribers invoked directly at call sites (Layer 2),
	never through this bus. See docs/specs/ClientEvents.md.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalPlus = require(ReplicatedStorage.Packages.SignalPlus)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local ClientEvents = {}

-----------------------------
-- SIGNALS --
-----------------------------

-- Payloads never contain frames, buttons, or scopes. Subscribers
-- resolve visuals themselves.
ClientEvents.SlotClicked = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number, string?>
ClientEvents.SlotHovered = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.DragStarted = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.DragEnded = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.Equipped = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.Unequipped = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.ItemAdded = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.ItemRemoved = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.Swapped = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number, CoreTypes.SlotType, number>
ClientEvents.Selected = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>
ClientEvents.Deselected = SignalPlus() :: SignalPlus.Signal<CoreTypes.SlotType, number>

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Invoke one skin hook function defensively. Always task.spawn'd: stock
-- hooks yield (OnSlotHover task.waits twice), so a synchronous call
-- would stall the input/drag thread. pcall'd: a throwing hook warns
-- once and never breaks inventory.
function ClientEvents.CallHook(hooks: { [string]: any }?, hookName: string, ...: any)
	if hooks == nil then return end
	local fn = hooks[hookName]
	if typeof(fn) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn(`[ClientEvents] hook '{hookName}' threw: {tostring(err)}`)
		end
	end)
end

function ClientEvents.Destroy()
	-- any: the 11 signals have different arities; the loop only
	-- needs DisconnectAll, which they all share.
	local all: { any } = {
		ClientEvents.SlotClicked,
		ClientEvents.SlotHovered,
		ClientEvents.DragStarted,
		ClientEvents.DragEnded,
		ClientEvents.Equipped,
		ClientEvents.Unequipped,
		ClientEvents.ItemAdded,
		ClientEvents.ItemRemoved,
		ClientEvents.Swapped,
		ClientEvents.Selected,
		ClientEvents.Deselected,
	}
	for _, signal in all do
		signal:DisconnectAll()
	end
end

-----------------------------
-- MAIN --
-----------------------------

return ClientEvents
