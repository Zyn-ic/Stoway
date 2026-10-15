--!strict

--@author: yyumchi
--@date: 2026-10-14
--[[@description:
	Showcase attraction (not system): wires the player's cop model with
	two choices. "Make me a cop" confiscates the ENTIRE inventory of a
	criminal who talks to him, and turns anyone else into a cop (stamping
	everything held plus everything picked up afterwards). "Nothing" walks
	away. Public Stoway routes only; touches no inventory code. Studio only.
]]
-----------------------------
-- SERVICES --
-----------------------------

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local Sides = require(script.Parent.Sides)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function confiscate(player: Player)
	local state = Stoway.get(player)
	if not state then
		return
	end
	local equipped: string? = state.EquippedItemUUID
	local uuids: { string } = {}
	for uuid in state.Items do
		table.insert(uuids, uuid)
	end
	for _, uuid in uuids do
		Stoway.RemoveItem(player, uuid, nil, true)
	end
	if equipped then
		Stoway.UnequipSlot(player, true)
	end
	print(`[Cop] contraband seized from {player.Name} ({#uuids} stacks gone)`)
end

local function makeCop(player: Player)
	if Sides.isCop(player) then
		print(`[Cop] you're already wearing the badge, {player.Name}`)
		return
	end
	if Sides.get(player) == "Criminal" then
		confiscate(player)
		return
	end
	local state = Stoway.get(player)
	if not state then
		return
	end
	local count = 0
	for uuid in state.Items do
		if Stoway.UpdateMetadata(player, uuid, { Team = "Police" }, true).ok then
			count += 1
		end
	end
	Sides.set(player, "Police")
	print(`[Cop] {player.Name} is a cop now ({count} items stamped, future picks stay cop)`)
end

local function attachPrompt(parent: Instance, text: string, key: Enum.KeyCode): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = text
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-----------------------------
-- MAIN --
-----------------------------

-- Studio only: the shipped game is unaffected.
if not RunService:IsStudio() then
	return
end

local model = Workspace:WaitForChild("cop", 30)
local head = if model then model:FindFirstChild("Head") else nil
local torso = if model then model:FindFirstChild("Torso") else nil
if not head or not torso then
	warn("[Cop] cop model parts missing, prompts not attached")
	return
end

-- Split across parts: two prompts on one part stack into one UI slot.
local badge = attachPrompt(head, "Make me a cop", Enum.KeyCode.E)
badge.Triggered:Connect(function(player: Player)
	makeCop(player)
end)

local pass = attachPrompt(torso, "Nothing, officer", Enum.KeyCode.F)
pass.Triggered:Connect(function(player: Player)
	print(`[Cop] move along, {player.Name}`)
end)
