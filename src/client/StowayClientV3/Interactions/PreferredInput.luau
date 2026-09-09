--!strict

--@author: yyumchi
--@date: 2026-09-09
--[[@description:
	Injectable PreferredInput adapter. Defaults to Roblox
	UserInputService.PreferredInput, but exposes SetSource(customSignal)
	so a game-wide input bus can publish "PreferredInput changed to X"
	and Stoway just subscribes. Avoids hard-coupling to UIS everywhere.

	Usage: PreferredInput.Init(scope) -- wires default UIS
	       PreferredInput.SetSource(customSignal) -- custom SignalPlus/Connectable
	       PreferredInput.Changed:Connect(function(new: Enum.PreferredInputType) end)
	       PreferredInput.Get(): Enum.PreferredInputType
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalPlus = require(ReplicatedStorage.Packages.SignalPlus)

local PreferredInput = {}

local _current: any = UserInputService.PreferredInput
local _defaultConn: RBXScriptConnection? = nil
local _customConn: any = nil
local _customSignal: any = nil

PreferredInput.Changed = (SignalPlus :: any)() :: any

function PreferredInput.Get(): any
	return _current
end

local function setCurrent(new: any)
	if _current == new then return end
	_current = new
	PreferredInput.Changed:Fire(new)
end

function PreferredInput.Init(scope: any?)
	-- scope optional: if provided, auto-cleanup conn on doCleanup
	if _defaultConn then return end
	_current = UserInputService.PreferredInput
	_defaultConn = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		if _customSignal then return end -- custom source wins while set
		setCurrent(UserInputService.PreferredInput)
	end)
	if scope and _defaultConn then
		table.insert(scope, _defaultConn)
		table.insert(scope, function()
			_defaultConn = nil
		end)
	end
end

-- Inject a game-wide signal. That signal must Fire(Enum.PreferredInput)
-- or a string mapped via ToPreferredInput. Passing nil restores default UIS.
function PreferredInput.SetSource(customSignal: any?)
	if _customConn then
		_customConn:Disconnect()
		_customConn = nil
	end
	_customSignal = customSignal
	if customSignal and customSignal.Connect then
		_customConn = customSignal:Connect(function(val: any)
			local mapped: any = nil
			if typeof(val) == "EnumItem" then
				mapped = val
			elseif typeof(val) == "string" then
				-- string fallback: "KeyboardAndMouse" / "Gamepad" / "Touch"
				mapped = (Enum :: any).PreferredInput[val]
			end
			if mapped then setCurrent(mapped) end
		end)
	else
		-- restore UIS polling
		_current = UserInputService.PreferredInput
	end
end

function PreferredInput.Destroy()
	if _defaultConn then _defaultConn:Disconnect(); _defaultConn = nil end
	if _customConn then _customConn:Disconnect(); _customConn = nil end
	_customSignal = nil
end

return PreferredInput
