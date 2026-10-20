--!strict

--@author: yyumchi
--@date: 2026-10-14
--[[@description:
	Showcase attraction (not system): wires the player's Apple_Tree model
	with a pick prompt. Prompting grants an apple into the hotbar through
	the normal route — pick repeatedly and watch the stack badge climb.
	Public AddToHotbar route only; touches no inventory code. Studio only.
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

local cooldownUntil = 0

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function pickApple(player: Player)
	if os.clock() < cooldownUntil then
		return
	end
	cooldownUntil = os.clock() + 1.5
	-- Hotbar, not backpack: BackpackEnabled is off by default, and the
	-- stack badge climbing is the visual we want anyway.
	local res = Stoway.AddToHotbar(player, {
		Id = "apple",
		Amount = 1,
		Metadata = { Rarity = "Common", Type = "Consumable" },
	}, nil, true)
	if res.ok then
		print(`[Tree] {player.Name} picked an apple`)
	else
		warn(`[Tree] pick failed: {res.error and res.error.message or "?"}`)
	end
end

-----------------------------
-- MAIN --
-----------------------------

-- Studio only: the shipped game is unaffected.
if not RunService:IsStudio() then
	return
end

local model = Workspace:WaitForChild("Apple_Tree", 30)
-- Lowest part wins: canopy parts (Bark/leaves) sit above prompt range.
local anchor: BasePart? = nil
if model then
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (anchor == nil or descendant.Position.Y < anchor.Position.Y) then
			anchor = descendant
		end
	end
end
if not anchor then
	warn("[Tree] Apple_Tree model or anchor part missing, prompt not attached")
	return
end

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Pick"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
-- The canopy sits high; reach it from the ground.
prompt.MaxActivationDistance = 20
prompt.RequiresLineOfSight = false
prompt.Parent = anchor

prompt.Triggered:Connect(function(player: Player)
	pickApple(player)
end)
