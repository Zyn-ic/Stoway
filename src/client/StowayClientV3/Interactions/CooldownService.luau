--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Client cooldown state (example branch). uuid -> os.clock end-times,
	keyed on the item so cooldowns travel through swaps and moves. One
	shared Tick clock advanced by a single RenderStepped connection that
	only runs while a cooldown is live; views derive veil + countdown
	from Tick. Nothing here touches Instances.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CooldownService = {}

local scope: Fusion.Scope<typeof(Fusion)> = Fusion.scoped(Fusion)

CooldownService.Tick = scope:Value(0)

local ends: { [string]: number } = {}
local tickConn: RBXScriptConnection? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function ensureLoop()
	if tickConn then return end
	tickConn = RunService.RenderStepped:Connect(function()
		CooldownService.Tick:set(os.clock())
		if next(ends) == nil then
			if tickConn then tickConn:Disconnect(); tickConn = nil end
		end
	end)
	table.insert(scope, function()
		if tickConn then tickConn:Disconnect(); tickConn = nil end
	end)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function CooldownService.StartCooldown(uuid: string, duration: number)
	if duration <= 0 then return end
	ends[uuid] = os.clock() + duration
	ensureLoop()
	CooldownService.Tick:set(os.clock())
end

function CooldownService.Remaining(uuid: string): number
	local e = ends[uuid]
	if not e then return 0 end
	local left = e - os.clock()
	if left <= 0 then
		ends[uuid] = nil
		return 0
	end
	return left
end

function CooldownService.IsOnCooldown(uuid: string): boolean
	return CooldownService.Remaining(uuid) > 0
end

function CooldownService.Clear(uuid: string)
	ends[uuid] = nil
end

-- Drop uuids no longer in state (FullSync wholesale replace).
function CooldownService.Prune(items: { [string]: any })
	for uuid in ends do
		if items[uuid] == nil then ends[uuid] = nil end
	end
end

-----------------------------
-- MAIN --
-----------------------------

return CooldownService
