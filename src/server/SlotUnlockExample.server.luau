--!strict

--@author: yyumchi
--@date: 2026-09-20
--[[@description:
	EXAMPLE (branch example/locked-slots): consumable slot unlock. Tools
	tagged "UnlockToken" (e.g. the PouchToken template) unlock a hotbar slot
	when the holder ACTIVATES them (click while equipped): the server finds
	one token unit in that player's inventory, DESTROYS it (Removed push —
	the client deletes, never drops), flips the slot out of
	LockedHotbarSlots, and pushes FullSync so the client learns the unlock.
	Use-to-unlock: merely holding the token does nothing. Already-unlocked
	slots are a harmless no-op (nothing is consumed).
]]
-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local Communications = require(ServerScriptService.Services.StowayServerV3_0_0.Communications)
local SlotLocks = require(game:GetService("ReplicatedStorage").Shared.Stoway.SlotLocks)

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "UnlockToken"

local handled = setmetatable({} :: { [Tool]: boolean }, { __mode = "k" })

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- First inventory unit carrying a numeric UnlocksHotbarSlot field.
local function findTokenUuid(items: { [string]: any }): (string?, number?)
	for uuid, item in items do
		local metadata = item.Metadata
		local slot = metadata and metadata[SlotLocks.UNLOCK_FIELD]
		if typeof(slot) == "number" then
			return uuid, slot
		end
	end
	return nil, nil
end

local function setup(tool: Tool)
	if handled[tool] then return end
	handled[tool] = true
	tool.Activated:Connect(function()
		local character = tool.Parent ~= nil and tool.Parent :: Model; if not character then return end
		local player = if character then Players:GetPlayerFromCharacter(character) else nil; if not player then return end
		local state = Stoway.get(player); if not state then return end
		local uuid, slot = findTokenUuid(state.Items)
		if uuid == nil or slot == nil then
			print(`[SlotUnlock] {tool.Name} activated with no unlock token held, ignoring`)
			return
		end
		if slot < 1 or slot > state.Settings.MaxHotbarSlots then
			warn(`[SlotUnlock] token targets out-of-range slot {tostring(slot)}, ignoring`)
			return
		end
		-- Consume first, then flip: route() is synchronous, so the check
		-- above and the mutation below are atomic within the tick — rapid
		-- double-clicks see the flipped settings and no-op instead of
		-- double-consuming.
		if SlotLocks.isUnlocked(state.Settings.LockedHotbarSlots, slot) then
			print(`[SlotUnlock] slot {slot} already unlocked, ignoring`)
			return
		end
		local res = Stoway.RemoveItem(player, uuid, nil, true)
		if not res.ok then
			warn(`[SlotUnlock] failed to consume token: {res.error and res.error.message or tostring(res)}`)
			return
		end
		local locked: { [number]: boolean } = state.Settings.LockedHotbarSlots or {}
		local nextLocked: { [number]: boolean } = {}
		for s, flag in locked do
			if s ~= slot and flag then
				nextLocked[s] = flag
			end
		end
		state.Settings.LockedHotbarSlots = nextLocked
		Communications.SendFullSync(player)
		print(`[SlotUnlock] slot {slot} unlocked for {player.Name}`)
	end)
end

-----------------------------
-- MAIN --
-----------------------------

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Tool") then
		setup(inst)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst: Instance)
	if inst:IsA("Tool") then
		setup(inst)
	end
end)
