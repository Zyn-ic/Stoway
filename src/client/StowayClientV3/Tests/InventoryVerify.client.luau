--!strict

--@author: yyumchi
--@date: 2026-09-21
--[[@description:
	Phase-1 data-output test: inventory integrity. Prints a full snapshot
	(hotbar/storage/items/weight) at boot and on every add/remove, plus an
	orphan scan (slot referencing a uuid with no item entry — the "Other"
	class) and a weight invariant (Weight atom vs summed amounts).
	Observer-only: never mutates inventory. A human judges PASS/FAIL from
	the [InventoryVerify] lines. Note: disabling this script halts its main
	thread but NOT its bus subscriptions (observers stay rooted in live
	state) — it keeps verifying until play ends. See
	docs/specs/TestingRules.md.
]]

local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientEvents = require(script.Parent.Parent.Controller.ClientEvents)
local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local function snapshot(): CoreTypes.ClientSnapshot
	return {
		Items = Fusion.peek(ClientStore.Items),
		Hotbar = Fusion.peek(ClientStore.Hotbar),
		Storage = Fusion.peek(ClientStore.Storage),
		EquippedItemUUID = Fusion.peek(ClientStore.EquippedItemUUID),
		Weight = Fusion.peek(ClientStore.Weight),
		Settings = Fusion.peek(ClientStore.Settings) or ({} :: any),
	}
end

local function report(tag: string)
	local snap = snapshot()
	local orphans: { string } = {}
	local hotbarCount = 0
	for slot, uuid in snap.Hotbar do
		if uuid ~= nil then
			hotbarCount += 1
			if snap.Items[uuid] == nil then
				table.insert(orphans, `Hotbar#{slot}={uuid}`)
			end
		end
	end
	for index, uuid in snap.Storage do
		if snap.Items[uuid] == nil then
			table.insert(orphans, `Storage#{index}={uuid}`)
		end
	end
	local sum = 0
	local count = 0
	for _, item in snap.Items do
		count += 1
		sum += if typeof(item.Amount) == "number" then item.Amount else 0
	end
	print(`[InventoryVerify] {tag} hotbar={hotbarCount} storage={#snap.Storage} items={count} weight={snap.Weight} sum={sum}`)
	if sum ~= snap.Weight then
		print(`[InventoryVerify] {tag} weight MISMATCH atom={snap.Weight} sum={sum} FAIL`)
	else
		print(`[InventoryVerify] {tag} weight OK PASS`)
	end
	if #orphans == 0 then
		print(`[InventoryVerify] {tag} orphans none PASS`)
	else
		print(`[InventoryVerify] {tag} orphans [{table.concat(orphans, ", ")}] FAIL`)
	end
end

task.defer(report, "boot")
ClientEvents.ItemAdded:Connect(function(slotType: CoreTypes.SlotType, index: number)
	report(`added {slotType}#{index}`)
end)
ClientEvents.ItemRemoved:Connect(function(slotType: CoreTypes.SlotType, index: number)
	report(`removed {slotType}#{index}`)
end)
