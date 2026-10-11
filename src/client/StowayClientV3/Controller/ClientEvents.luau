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
function ClientEvents.CallHook(hooks: CoreTypes.HookMap?, hookName: string, ...: unknown)
	if hooks == nil then return end
	local fn = hooks[hookName]
	if typeof(fn) ~= "function" then return end
	local invoke = fn :: (...unknown) -> ()
	local args = table.pack(...)
	task.spawn(function()
		local ok = pcall(function()
			invoke(table.unpack(args, 1, args.n))
		end)
		if not ok then
			warn(`[ClientEvents] hook '{hookName}' threw`)
		end
	end)
end

function ClientEvents.Destroy()
	ClientEvents.SlotClicked:DisconnectAll()
	ClientEvents.SlotHovered:DisconnectAll()
	ClientEvents.DragStarted:DisconnectAll()
	ClientEvents.DragEnded:DisconnectAll()
	ClientEvents.Equipped:DisconnectAll()
	ClientEvents.Unequipped:DisconnectAll()
	ClientEvents.ItemAdded:DisconnectAll()
	ClientEvents.ItemRemoved:DisconnectAll()
	ClientEvents.Swapped:DisconnectAll()
	ClientEvents.Selected:DisconnectAll()
	ClientEvents.Deselected:DisconnectAll()
end

-----------------------------
-- MAIN --
-----------------------------

return ClientEvents
