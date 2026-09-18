--!strict

--@author: yyumchi
--@date: 2026-09-18
--[[@description:
	First external subscriber on the ClientEvents bus (Layer 1). Proves
	UI events are subscribable from outside the layout: toasts + sounds
	here when items land. Presentation is stubbed (no toast GUI or sound
	asset exists yet) — replace the stubs with real calls when they do.
	Subscription ownership: init.luau connects this at boot; the returned
	connection should be disconnected on client teardown.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalPlus = require(ReplicatedStorage.Packages.SignalPlus)

local ClientEvents = require(script.Parent.ClientEvents)
local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local NotifyExample = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function NotifyExample.Connect(): { SignalPlus.Connection }
	local conns: { SignalPlus.Connection } = {}
	table.insert(
		conns,
		ClientEvents.ItemAdded:Connect(function(slotType: CoreTypes.SlotType, index: number)
			task.defer(function()
				-- STUB: toast GUI goes here, e.g.
				-- ToastBus:Show(("New item in %s #%d"):format(slotType, index))
				warn(`[NotifyExample] ItemAdded in {slotType} #{index} (toast stub)`)
				-- STUB: sound goes here, e.g.
				-- SoundService:Play("ItemGet")
			end)
		end)
	)
	table.insert(
		conns,
		ClientEvents.Equipped:Connect(function(slotType: CoreTypes.SlotType, index: number)
			task.defer(function()
				warn(`[NotifyExample] Equipped {slotType} #{index} (sound stub)`)
			end)
		end)
	)
	return conns
end

-----------------------------
-- MAIN --
-----------------------------

return NotifyExample
