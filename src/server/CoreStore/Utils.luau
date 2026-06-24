local Utils = {}

local uuidCounter = 0

function Utils.deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[key] = Utils.deepCopy(child)
    end

    return copy
end

function Utils.shallowCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[key] = child
    end

    return copy
end

function Utils.generateUUID(): string
    uuidCounter += 1

    local randomPart = math.random(100000, 999999)
    return `core-{os.clock()}-{uuidCounter}-{randomPart}`
end

function Utils.isPositiveNumber(value: any): boolean
    return type(value) == "number" and value > 0 and value == value
end

function Utils.clampAmount(amount: number, minValue: number, maxValue: number): number
    return math.max(minValue, math.min(amount, maxValue))
end

return Utils