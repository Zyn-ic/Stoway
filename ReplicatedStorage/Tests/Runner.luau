--!strict
--@author: yyumchi
--@date: 2026-08-21
--[[@description:
	Minimal Studio test runner for the data specs under ReplicatedStorage/Tests.
	Works without vendoring TestEZ — provides a tiny describe/it/expect that
	prints to Output. TestEZ-compatible specs still pass: they are functions
	(describe, it, expect) -> void.

	Usage (Studio Command Bar or TestService):
		require(game.ReplicatedStorage.Tests.Runner).run()

	Or to run a single spec:
		require(game.ReplicatedStorage.Tests.Runner).runSpec("ClientData")
]]

local Runner = {}

type Expect = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNil: () -> (),
	never: Expect,
}

local function expectFn(actual: any): any
	local exp: any = {}
	local neg: any = {}

	exp.toBe = function(expected: any)
		if actual ~= expected then
			error(`expect: {tostring(actual)} to be {tostring(expected)}`, 2)
		end
	end
	exp.toEqual = exp.toBe
	exp.toBeNil = function()
		if actual ~= nil then
			error(`expect: {tostring(actual)} to be nil`, 2)
		end
	end

	neg.toBe = function(expected: any)
		if actual == expected then
			error(`expect: {tostring(actual)} not to be {tostring(expected)}`, 2)
		end
	end
	neg.toEqual = neg.toBe
	neg.toBeNil = function()
		if actual == nil then
			error(`expect: to be not nil but got nil`, 2)
		end
	end

	exp.never = neg
	neg.never = exp

	return exp
end

local total = 0
local passed = 0
local failed = 0
local currentDescribe = ""

local function describe(name: string, fn: () -> ())
	currentDescribe = name
	print(`\n[Suite] {name}`)
	local packed = table.pack(pcall(fn))
	local ok = packed[1] :: boolean
	local err = packed[2]
	if not ok then
		failed += 1
		warn(`  [DESCRIBE FAIL] {name}: {err}`)
	end
end

local function it(name: string, fn: () -> ())
	total += 1
	local packed = table.pack(pcall(fn))
	local ok = packed[1] :: boolean
	local err = packed[2]
	if ok then
		passed += 1
		print(`  [PASS] {currentDescribe} > {name}`)
	else
		failed += 1
		warn(`  [FAIL] {currentDescribe} > {name}: {err}`)
	end
end

function Runner.run()
	total = 0; passed = 0; failed = 0
	print("=== Stoway Data Specs (Studio) ===")

	local specsFolder = script.Parent
	for _, child in specsFolder:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			local ok, specFn = pcall(require, child)
			if not ok then
				warn(`[Runner] failed to require {child.Name}: {specFn}`)
				failed += 1
				continue
			end
			-- specFn is (describe, it, expect) -> void
			local ok2, err = pcall(specFn, describe, it, expectFn)
			if not ok2 then
				warn(`[Runner] spec {child.Name} threw: {err}`)
				failed += 1
			end
		end
	end

	print(`\n=== Results: {passed} passed, {failed} failed, {total} total ===`)
	if failed > 0 then warn("Some data specs failed — check Output above") end
	return { passed = passed, failed = failed, total = total }
end

function Runner.runSpec(name: string)
	total = 0; passed = 0; failed = 0
	local spec = script.Parent:FindFirstChild(name) or script.Parent:FindFirstChild(name .. ".spec")
	if not spec then
		warn(`[Runner] spec not found: {name}`)
		return
	end
	local ok, specFn = pcall(require, spec)
	if not ok then warn(`[Runner] require failed: {specFn}`); return end
	pcall(specFn, describe, it, expectFn)
	print(`\n=== Single spec {name}: {passed}/{total} passed ===`)
end

return Runner
