-- src/server/StowayServerV1.2/World/ItemSpawner.luau
-- Physical tool spawn/despawn/drop in game world

local ItemSpawner = {}

local ServerStorage = game:GetService("ServerStorage")
local Settings = require(script.Parent.Parent.Config.Settings)

local ToolStorage = ServerStorage:FindFirstChild("Tools") :: Folder?

--// Spawn tool in player's character
function ItemSpawner.SpawnTool(player: Player, itemId: string, metadata: any?): Tool?
	if not player.Character then
		warn("[ItemSpawner] Cannot spawn tool - player has no character:", player.Name)
		return nil
	end
	
	if not ToolStorage then
		warn("[ItemSpawner] Tools folder not found in ServerStorage")
		return nil
	end
	
	local toolTemplate = ToolStorage:FindFirstChild(itemId) :: Tool?
	if not toolTemplate then
		warn("[ItemSpawner] Tool not found in storage:", itemId)
		return nil
	end
	
	local toolClone = toolTemplate:Clone()
	
	-- Apply metadata as attributes
	if metadata then
		for key, value in pairs(metadata) do
			toolClone:SetAttribute(key, value)
		end
	end
	
	toolClone.Parent = player.Character or player.CharacterAdded:Wait()
	return toolClone
end

--// Despawn tool from player
function ItemSpawner.DespawnTool(player: Player, tool: Tool)
	if tool and tool.Parent == player.Character then
		tool:Destroy()
	end
end

--// Drop tool into world
function ItemSpawner.DropTool(player: Player, itemId: string, amount: number, metadata: any?)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	if not ToolStorage then
		warn("[ItemSpawner] Tools folder not found in ServerStorage")
		return
	end
	
	local toolTemplate = ToolStorage:FindFirstChild(itemId)
	if not toolTemplate then
		warn("[ItemSpawner] Tool not found for drop:", itemId)
		return
	end
	
	local pickup = toolTemplate:Clone()
	
	-- Apply metadata
	if metadata then
		for key, value in pairs(metadata) do
			pickup:SetAttribute(key, value)
		end
	end
	
	-- Set amount attribute for pickup
	pickup:SetAttribute("StackAmount", amount)
	
	-- Calculate drop position
	local rootCframe = hrp.CFrame
	local dropOffset = rootCframe.LookVector * Settings.Gameplay.DropDistance
	local dropPosition = rootCframe.Position + dropOffset
	
	-- Position and parent to workspace
	if pickup:IsA("Tool") then
		local handle = pickup:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = CFrame.new(dropPosition)
		else
			pickup:PivotTo(CFrame.new(dropPosition))
		end
	end
	
	pickup.Parent = workspace
	
	-- TODO: Add pickup interaction script or CollectionService tag
end

return ItemSpawner
