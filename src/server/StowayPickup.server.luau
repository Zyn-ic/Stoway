--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Stoway world-drop pickup. Watches for Tools tagged "Stoway" (spawned
	by Stoway.Drop): strips default touch pickup, attaches a ProximityPrompt,
	picks up into the player's backpack on trigger (replicates to them),
	destroys unclaimed tools after 15s via Debris.
]]
-----------------------------
-- SERVICES --
-----------------------------

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)
local Log = require(ReplicatedStorage.Shared.Stoway.Log)

-----------------------------
-- CONSTANTS --
-----------------------------

local TAG = "Stoway"
local CLAIM_LIFETIME = 15

local configuredTools = setmetatable({} :: { [Tool]: boolean }, { __mode = "k" })
local pickupInProgress = setmetatable({} :: { [Tool]: boolean }, { __mode = "k" })

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Metadata is everything on the tool except the attributes used to identify
-- the dropped item itself. Other attributes round-trip as item metadata.
local function readMetadata(tool: Tool): { [string]: any }
	local meta: { [string]: any } = {}
	for key, value in tool:GetAttributes() do
		if key ~= "UUID" and key ~= "Amount" and key ~= "Id" then
			meta[key] = value
		end
	end
	return meta
end

local function setup(tool: Tool)
	-- Only a descendant of Workspace is a live world drop and may receive a
	-- prompt or Debris timer. A tagged template can briefly exist elsewhere;
	-- Workspace.DescendantAdded below catches it when it becomes live.
	if not tool:IsDescendantOf(Workspace) then return end
	if configuredTools[tool] then return end
	configuredTools[tool] = true

	-- The route strips already; this covers hand-placed tagged tools.
	-- Default touch pickup must never fire: the prompt is the only way in.
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		handle = tool:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	end
	if handle then
		local touch = handle:FindFirstChild("TouchInterest")
		if touch then touch:Destroy() end
		handle.CanTouch = false
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle or tool
	prompt.Triggered:Connect(function(player: Player)
		if tool.Parent == nil then return end
		if pickupInProgress[tool] then return end
		local id = tool:GetAttribute("Id")
		local amount = tool:GetAttribute("Amount")
		if typeof(id) ~= "string" then return end
		pickupInProgress[tool] = true
		local itemId: string = id
		local itemAmount: number = if typeof(amount) == "number" then amount else 1
		local res = Stoway.AddToBackpack(player, { Id = itemId, Amount = itemAmount, Metadata = readMetadata(tool) }, nil, true)
		if res.ok then
			tool:Destroy()
		else
			pickupInProgress[tool] = nil
			local pickupState = Stoway.get(player)
			Log.warn(pickupState and pickupState.Settings, `[StowayPickup] add failed for {player.Name}: {res.error.message}`)
		end
	end)

	Debris:AddItem(tool, CLAIM_LIFETIME)
end

-----------------------------
-- MAIN --
-----------------------------

for _, inst in CollectionService:GetTagged(TAG) do
	if inst:IsA("Tool") then setup(inst) end
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst: Instance)
	if inst:IsA("Tool") then setup(inst) end
end)

-- A Tool can inherit a CollectionService tag from a Studio template while it
-- is cloned into a Character or Backpack. In that case the tag-added signal
-- fires before the Tool reaches Workspace; catch the later parenting event so
-- the world-drop prompt is still installed.
Workspace.DescendantAdded:Connect(function(inst: Instance)
	if inst:IsA("Tool") and CollectionService:HasTag(inst, TAG) then
		setup(inst)
	end
end)

Log.print(nil, "[StowayPickup] watching for tagged tools")
