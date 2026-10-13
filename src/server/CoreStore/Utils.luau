--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Utility functions - deep copy, UUID generation, validation
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Utils = {}

type CopyTable = { [string | number]: unknown }

local uuidCounter = 0

-----------------------------
-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Utils.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local source = value :: CopyTable
	local copy: CopyTable = {}

	for key, child in source do
		copy[key] = Utils.deepCopy(child)
	end

	return (copy :: unknown) :: T
end

function Utils.shallowCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local source = value :: CopyTable
	local copy: CopyTable = {}

	for key, child in source do
		copy[key] = child
	end

	return (copy :: unknown) :: T
end

-- Generates a unique ID: core-{timestamp}-{counter}-{random6}
-- Not cryptographically unique, but sufficient for inventory UUIDs.
-- Example: "core-1719686400.5-42-738291"
function Utils.generateUUID(): string
	uuidCounter += 1

	local randomPart = math.random(100000, 999999)
	return `core-{os.clock()}-{uuidCounter}-{randomPart}`
end

-- Checks if value is a number > 0. value == value catches NaN.
function Utils.isPositiveNumber(value: unknown): boolean
	return type(value) == "number" and value > 0 and value == value
end

function Utils.clampAmount(amount: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(amount, maxValue))
end

-----------------------------
--MAIN--
-----------------------------

return Utils
