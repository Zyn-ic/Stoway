-- src/server/StowayServerV1.2/Utils/MetadataParser.luau
-- Parses metadata from Tool attributes
-- Note: "Amount" is extracted separately and excluded from metadata

local MetadataParser = {}

local ServerStorage = game:GetService("ServerStorage")

local ToolStorage = ServerStorage:FindFirstChild("Tools") :: Folder?

-- Fields that should NOT be in metadata (they're used as item properties)
local EXCLUDED_FIELDS = {
	Amount = true,  -- Amount is item.Amount, not metadata
}

--// Parse metadata from a Tool's attributes (excludes Amount and other reserved fields)
function MetadataParser.FromTool(tool: Tool): ({ [string]: any }?, number?)
	if not tool or not tool:IsA("Tool") then
		return nil, nil
	end
	
	local attributes = tool:GetAttributes()
	local metadata = {}
	local amount = nil
	
	for key, value in pairs(attributes) do
		if key == "Amount" then
			amount = value  -- Extract Amount separately
		elseif not EXCLUDED_FIELDS[key] then
			metadata[key] = value
		end
	end
	
	-- Return nil if no metadata keys, otherwise return the table
	local finalMeta = next(metadata) and metadata or nil
	return finalMeta, amount
end

--// Get metadata from a tool template by itemId
--// Returns: metadata, defaultAmount
function MetadataParser.FromItemId(itemId: string): ({ [string]: any }?, number?)
	if not ToolStorage then
		warn("[MetadataParser] Tools folder not found in ServerStorage")
		return nil, nil
	end
	
	local toolTemplate = ToolStorage:FindFirstChild(itemId)
	if toolTemplate and toolTemplate:IsA("Tool") then
		return MetadataParser.FromTool(toolTemplate)
	end
	
	return nil, nil
end

--// Merge base metadata with overrides
function MetadataParser.Merge(base: { [string]: any }?, overrides: { [string]: any }?): { [string]: any }
	local result = {}
	
	-- Copy base
	if base then
		for k, v in pairs(base) do
			result[k] = v
		end
	end
	
	-- Apply overrides
	if overrides then
		for k, v in pairs(overrides) do
			result[k] = v
		end
	end
	
	return result
end

return MetadataParser

