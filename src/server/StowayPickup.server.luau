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
local ServerScriptService = game:GetService("ServerScriptService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Stoway = require(ServerScriptService.Services.StowayServerV3_0_0)

-----------------------------
-- CONSTANTS --
-----------------------------

local TAG = "Stoway"
local CLAIM_LIFETIME = 15

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Metadata is everything on the tool except the system attributes the
-- Drop route stamps (UUID/Amount/Id). Attribute types round-trip.
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
	if tool:GetAttribute("StowayClaimed") then return end
	tool:SetAttribute("StowayClaimed", true)

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
		if tool:GetAttribute("StowayPickedUp") then return end
		tool:SetAttribute("StowayPickedUp", true)
		local id = tool:GetAttribute("Id")
		local amount = tool:GetAttribute("Amount")
		if typeof(id) ~= "string" then return end
		local itemId: string = id
		local itemAmount: number = if typeof(amount) == "number" then amount else 1
		local res = Stoway.AddToBackpack(player, { Id = itemId, Amount = itemAmount, Metadata = readMetadata(tool) }, nil, true)
		if res.ok then
			tool:Destroy()
		else
			tool:SetAttribute("StowayPickedUp", false)
			warn(`[StowayPickup] add failed for {player.Name}: {res.error.message}`)
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

print("[StowayPickup] watching for tagged tools")
