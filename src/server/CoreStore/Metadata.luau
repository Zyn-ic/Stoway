local Types = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type ItemInput = Types.ItemInput
type ItemMetadata = Types.ItemMetadata

local Metadata = {}

function Metadata.normalize(itemData: ItemInput): (string?, number?, ItemMetadata?, string?)
    local itemId = itemData.Id or itemData.ID

    if type(itemId) ~= "string" or itemId == "" then
        return nil, nil, nil, "INVALID_ITEM_ID"
    end

    local metadata: ItemMetadata = {}

    if type(itemData.Metadata) == "table" then
        metadata = Utils.shallowCopy(itemData.Metadata) :: ItemMetadata
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
    leftMetadata: ItemMetadata,
    rightMetadata: ItemMetadata,
    requiredFields: { string }
): boolean
    for _, field in ipairs(requiredFields) do
        if leftMetadata[field] ~= rightMetadata[field] then
            return false
        end
    end

    return true
end

function Metadata.isBlacklisted(metadata: ItemMetadata, blacklist: { boolean }): boolean
    local rarity = metadata.Rarity

    if rarity ~= nil and blacklist[rarity] then
        return true
    end

    return false
end

return Metadata