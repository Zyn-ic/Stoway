--!strict

--@author: yyumchi
--@date: 2026-10-14
--[[@description:
	Showcase attraction (not system): wires the player's criminal model
	with two choices. "Risk it" lets him steal a random item when you are
	not a cop (cops get a pass); "Join the crew" turns you criminal,
	stamping everything you hold and everything you pick up afterwards.
	Public Stoway routes + the world-drop tag contract only; touches no
	inventory code. Studio only.
]]
-----------------------------
-- SERVICES --
-----------------------------

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local Sides = require(script.Parent.Sides)

local TAG = "Stoway"

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function stripTouch(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		handle = tool:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	end
	if not handle then
		return
	end
	local touch = handle:FindFirstChild("TouchInterest")
	if touch then
		touch:Destroy()
	end
	handle.CanTouch = false
end

local function dropAt(feet: CFrame, item: { Id: string, Amount: number, Metadata: { [string]: any }, UUID: string })
	local toolsFolder = ServerStorage:FindFirstChild("Tools")
	local template = if toolsFolder then toolsFolder:FindFirstChild(item.Id) else nil
	if not template or not template:IsA("Tool") then
		return
	end
	local drop = template:Clone()
	drop:SetAttribute("UUID", item.UUID)
	drop:SetAttribute("Amount", item.Amount)
	drop:SetAttribute("Id", item.Id)
	for key, value in item.Metadata do
		if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
			drop:SetAttribute(key, value)
		end
	end
	stripTouch(drop)
	drop:PivotTo(feet * CFrame.new(0, 3, -4))
	drop.Parent = Workspace
	CollectionService:AddTag(drop, TAG)
end

local function riskIt(player: Player, feet: CFrame)
	if Sides.isCop(player) then
		print(`[Thief] Whoa… no trouble here, officer.`)
		return
	end
	local state = Stoway.get(player)
	if not state then
		return
	end
	local uuids: { string } = {}
	for uuid in state.Items do
		table.insert(uuids, uuid)
	end
	if #uuids == 0 then
		print(`[Thief] {player.Name} has nothing worth stealing`)
		return
	end
	local uuid = uuids[math.random(1, #uuids)]
	local item = state.Items[uuid]
	local res = Stoway.RemoveItem(player, uuid, nil, true)
	if not res.ok or not item then
		return
	end
	print(`[Thief] stole your {item.Id}! Quick — grab it back off the ground…`)
	dropAt(feet, { Id = item.Id, Amount = item.Amount, Metadata = item.Metadata, UUID = uuid })
end

local function joinCrew(player: Player)
	if Sides.get(player) == "Criminal" then
		print(`[Thief] you're already crew, {player.Name}`)
		return
	end
	local state = Stoway.get(player)
	if not state then
		return
	end
	local count = 0
	for uuid in state.Items do
		if Stoway.UpdateMetadata(player, uuid, { Team = "Criminal" }, true).ok then
			count += 1
		end
	end
	Sides.set(player, "Criminal")
	print(`[Thief] {player.Name} runs with the crew now ({count} items stamped, future picks stay criminal)`)
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

local model = Workspace:WaitForChild("criminal", 30)
local head = if model then model:FindFirstChild("Head") else nil
local torso = if model then model:FindFirstChild("UpperTorso") else nil
if not head or not torso then
	warn("[Thief] criminal model parts missing, prompts not attached")
	return
end

-- Split across parts: two prompts on one part stack into one UI slot.
local risk = attachPrompt(head, "Risk it", Enum.KeyCode.E)
risk.Triggered:Connect(function(player: Player)
	local root = head :: BasePart
	riskIt(player, root.CFrame)
end)

local join = attachPrompt(torso, "Join the crew", Enum.KeyCode.F)
join.Triggered:Connect(function(player: Player)
	joinCrew(player)
end)
