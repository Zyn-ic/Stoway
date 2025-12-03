-- src/server/StowayServerV1/Modules/ItemSpawner.luau
local ItemSpawner = {}

local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

-- Assuming tools are stored in a folder named "Tools" in ServerStorage
-- You might need to adjust this path based on your actual project structure
local ToolStorage = ServerStorage:FindFirstChild("Tools") or Instance.new("Folder", ServerStorage)
ToolStorage.Name = "Tools"

function ItemSpawner.SpawnTool(player: Player, itemId: string, metadata: any?): Tool?
	local toolTemplate = ToolStorage:FindFirstChild(itemId)
	if not toolTemplate then
		warn("[ItemSpawner] Tool not found in storage:", itemId)
		return nil
	end

	local toolClone = toolTemplate:Clone()
	
	-- Apply metadata if needed (e.g., durability, name change)
	if metadata then
		-- Example: toolClone:SetAttribute("Durability", metadata.Durability)
	end

	toolClone.Parent = player.Character
	return toolClone
end

function ItemSpawner.DespawnTool(player: Player, tool: Tool)
	if tool and tool.Parent == player.Character then
		tool:Destroy()
	end
end

function ItemSpawner.DropTool(player: Player, itemId: string, amount: number, metadata: any?)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Create a physical pickup
	-- This is a placeholder. Usually you'd spawn a model or handle.
	local toolTemplate = ToolStorage:FindFirstChild(itemId)
	if toolTemplate then
		local pickup = toolTemplate:Clone()
		if pickup:IsA("Tool") then
			pickup.Parent = workspace
			if pickup:FindFirstChild("Handle") then
				pickup.Handle.CFrame = hrp.CFrame * CFrame.new(0, 0, -5)
			else
				pickup:PivotTo(hrp.CFrame * CFrame.new(0, 0, -5))
			end
			-- Add a pickup script or tag here
		end
	end
end

return ItemSpawner
