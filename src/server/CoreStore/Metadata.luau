--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Metadata normalization and validation for item inputs
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")
local Utils = require("../CoreStore/Utils")

local Metadata = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

function Metadata.normalize(itemData: Types.ItemInput): (string?, number?, Types.ItemMetadata?, string?)
	local itemId = itemData.Id or itemData.ID

	if type(itemId) ~= "string" or itemId == "" then
		return nil, nil, nil, "INVALID_ITEM_ID"
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
		return nil, nil, nil, "INVALID_AMOUNT"
	end

	if metadata.Droppable == nil then
		metadata.Droppable = true
	end

	return itemId, amount, metadata, nil
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
