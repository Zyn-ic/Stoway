--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Metadata normalization and validation for item inputs
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Result
do
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Stoway.Result)
	end)
	if ok and mod then
		Result = mod
	else
		Result = require("@Result")
	end
end
local function importCore(name: string)
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Stoway.CoreStore[name])
	end)
	if ok and mod then
		return mod
	end
	return require("@CoreStore/" .. name)
end

local Types = importCore("Types")
local Utils = importCore("Utils")

local Metadata = {}

local EK = Result.ErrorKind

-----------------------------
-- CONSTANTS --
-----------------------------

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

-- Normalizes raw item input into a Result of { itemId, amount, metadata }.
--
-- Amount fallback chain: itemData.Amount -> metadata.Amount -> metadata.StackAmount -> 1
-- Cleans Amount/StackAmount from metadata after extraction.
-- Defaults Droppable to true if not set.
function Metadata.normalize(itemData: Types.ItemInput): Result.Result<{ itemId: string, amount: number, metadata: Types.ItemMetadata }>
	local itemId = itemData.Id

	if type(itemId) ~= "string" or itemId == "" then
		return Result.Err({ kind = EK.InvalidArgument, message = "INVALID_ITEM_ID" })
	end

	local metadata: Types.ItemMetadata = {}

	if type(itemData.Metadata) == "table" then
		metadata = Utils.shallowCopy(itemData.Metadata) :: Types.ItemMetadata
	end

	local rawAmount = itemData.Amount

	if rawAmount == nil then
		rawAmount = metadata.Amount
	end

	if rawAmount == nil then
		rawAmount = metadata.StackAmount
	end

	if type(rawAmount) == "string" then
		rawAmount = tonumber(rawAmount)
	end

	metadata.Amount = nil
	metadata.StackAmount = nil

	local amount = rawAmount or 1

	if not Utils.isPositiveNumber(amount) then
		return Result.Err({ kind = EK.InvalidArgument, message = "INVALID_AMOUNT" })
	end

	if metadata.Droppable == nil then
		metadata.Droppable = true
	end

	return Result.Ok({ itemId = itemId, amount = amount, metadata = metadata })
end

function Metadata.matchesRequiredFields(
	leftMetadata: Types.ItemMetadata,
	rightMetadata: Types.ItemMetadata,
	requiredFields: { string }
): boolean
	for _, field in requiredFields do
		if leftMetadata[field] ~= rightMetadata[field] then
			return false
		end
	end

	return true
end

function Metadata.isBlacklisted(metadata: Types.ItemMetadata, blacklist: { boolean }): boolean
	local rarity = metadata.Rarity

	if rarity ~= nil and blacklist[rarity] then
		return true
	end

	return false
end

-----------------------------
--MAIN--
-----------------------------

return Metadata
