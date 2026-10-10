--!strict

--@author: yyumchi
--@date: 2026-09-21
--[[@description:
	Phase-1 data-output test: per-player settings replication. Prints the
	engine settings atoms at boot, then watches store.Settings and prints a
	fresh dump plus an atoms-vs-_state parity check on the first real change,
	then disables itself (session-only, file untouched). Observer-only: never
	mutates inventory. A human judges PASS/FAIL from the [SettingsVerify]
	lines. Guards the sync-clobber class (stale boot snapshot overwriting
	pushed settings — the set-to-4 bug showed 10 slots). See
	docs/specs/TestingRules.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

-- Flat scalar engine fields; tables compared separately below.
local SCALARS = {
	"HotbarType",
	"MaxHotbarSlots",
	"Limit",
	"CanStack",
	"MaxStackSize",
	"BackpackEnabled",
	"Sorting",
	"SortOrder",
	"StackOnSwap",
	"DefaultDroppable",
}

local function keyOf(settings: CoreTypes.Settings?): string
	if settings == nil then
		return "nil"
	end
	local required: { string } = {}
	for _, v in settings.StackRequiredFields do
		table.insert(required, v)
	end
	local blacklist: { string } = {}
	for k in pairs(settings.StackBlacklist) do
		table.insert(blacklist, k)
	end
	table.sort(blacklist)
	local parts: { string } = {}
	for _, field in SCALARS do
		table.insert(parts, tostring((settings :: any)[field]))
	end
	table.insert(parts, table.concat(required, ","))
	table.insert(parts, table.concat(blacklist, ","))
	return table.concat(parts, "|")
end

local function dump(tag: string)
	local atoms: CoreTypes.Settings? = Fusion.peek(ClientStore.Settings)
	local state = ClientController.GetState()
	if atoms == nil or state == nil then
		print(`[SettingsVerify] {tag} no state yet (pre-Init)`)
		return
	end
	local mirror = state.Settings
	print(`[SettingsVerify] {tag} atoms MaxHotbarSlots={tostring(atoms.MaxHotbarSlots)} HotbarType={tostring(atoms.HotbarType)} Sorting={tostring(atoms.Sorting)}`)
	local mismatches: { string } = {}
	local a: any = atoms
	local b: any = mirror
	for _, field in SCALARS do
		if a[field] ~= b[field] then
			table.insert(mismatches, field)
		end
	end
	local arf: { string } = a.StackRequiredFields or {}
	local srf: { string } = b.StackRequiredFields or {}
	if table.concat(arf, ",") ~= table.concat(srf, ",") then
		table.insert(mismatches, "StackRequiredFields")
	end
	local abl: { string } = {}
	for k in pairs(a.StackBlacklist or {}) do
		table.insert(abl, k)
	end
	local sbl: { string } = {}
	for k in pairs(b.StackBlacklist or {}) do
		table.insert(sbl, k)
	end
	table.sort(abl)
	table.sort(sbl)
	if table.concat(abl, ",") ~= table.concat(sbl, ",") then
		table.insert(mismatches, "StackBlacklist")
	end
	if #mismatches == 0 then
		print(`[SettingsVerify] {tag} parity atoms==mirror PASS`)
	else
		print(`[SettingsVerify] {tag} parity MISMATCH [{table.concat(mismatches, ", ")}] FAIL`)
	end
end

local scope = Fusion.scoped(Fusion)
local lastKey: string? = nil

task.defer(function()
	dump("boot")
	local atoms: CoreTypes.Settings? = Fusion.peek(ClientStore.Settings)
	lastKey = keyOf(atoms)
end)

scope:Observer(ClientStore.Settings):onChange(function()
	local atoms: CoreTypes.Settings? = Fusion.peek(ClientStore.Settings)
	local key = keyOf(atoms)
	if key == lastKey then
		return
	end
	lastKey = key
	dump("changed")
	script.Disabled = true
end)
