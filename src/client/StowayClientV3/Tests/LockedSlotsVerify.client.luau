--!strict

--@author: yyumchi
--@date: 2026-09-20
--[[@description:
	EXAMPLE (branch example/locked-slots): live lock verifier. Observer-only
	LocalScript — runs on play like Tests/NotifyExample.client.luau, subscribes
	to the ClientEvents bus and prints the slot-9 lock verdict plus every
	item's UnlocksHotbarSlot field (with typeof) whenever inventory changes.
	No state mutation: read the [LockVerify] lines in Output to confirm the
	metadata flow end to end.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientEvents = require(script.Parent.Parent.Controller.ClientEvents)
local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local Query = require(script.Parent.Parent.CoreStore.Query)
local State = require(script.Parent.Parent.CoreStore.State)

local function report(tag: string)
	local items: { [string]: CoreTypes.Item } = Fusion.peek(ClientStore.Items)
	local settings: CoreTypes.Settings? = Fusion.peek(ClientStore.Settings)
	local maxSlots = State.getMaxHotbarSlots(settings)
	local bits: { string } = {}
	for i = 1, maxSlots do
		bits[i] = if Query.isHotbarSlotUnlocked(items, settings, i) then "U" else "L"
	end
	print(`[LockVerify] {tag} slots={table.concat(bits, " ")}`)
	for _, item in items do
		local field = if item.Metadata then item.Metadata.UnlocksHotbarSlot else nil
		if field ~= nil then
			print(`[LockVerify] {tag} token {item.Id} UnlocksHotbarSlot({typeof(field)})={tostring(field)}`)
		end
	end
	local unlocked9 = Query.isHotbarSlotUnlocked(items, settings, 9)
	local locked9 = settings ~= nil
		and settings.LockedHotbarSlots ~= nil
		and settings.LockedHotbarSlots[9] == true
	local hasToken9 = false
	for _, item in items do
		if item.Metadata and item.Metadata.UnlocksHotbarSlot == 9 then
			hasToken9 = true
			break
		end
	end
	local expected = if hasToken9 then true else not locked9
	local verdict = if unlocked9 == expected then "PASS" else "FAIL"
	print(`[LockVerify] {tag} slot9 unlocked={tostring(unlocked9)} expected={tostring(expected)} {verdict}`)
end

task.defer(report, "boot")
ClientEvents.ItemAdded:Connect(function(slotType: CoreTypes.SlotType, index: number)
	report(`added {slotType}#{index}`)
end)
ClientEvents.ItemRemoved:Connect(function(slotType: CoreTypes.SlotType, index: number)
	report(`removed {slotType}#{index}`)
end)
