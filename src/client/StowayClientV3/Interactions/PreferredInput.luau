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
local Fusion = require(ReplicatedStorage.Packages.fusion)

local PreferredInput = {}

local _current: EnumItem = UserInputService.PreferredInput
local _defaultConn: RBXScriptConnection? = nil
local _customConn: SignalPlus.Connection? = nil
local _customSignal: SignalPlus.Signal<EnumItem | string>? = nil

PreferredInput.Changed = SignalPlus() :: SignalPlus.Signal<EnumItem>

function PreferredInput.Get(): EnumItem
	return _current
end

local function setCurrent(new: EnumItem)
	if _current == new then return end
	_current = new
	PreferredInput.Changed:Fire(new)
end

function PreferredInput.Init(scope: Fusion.Scope<typeof(Fusion)>?)
	-- scope optional: if provided, auto-cleanup conn on doCleanup
	if _defaultConn ~= nil then return end
	_current = UserInputService.PreferredInput
	_defaultConn = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		if _customSignal ~= nil then return end -- custom source wins while set
		setCurrent(UserInputService.PreferredInput)
	end)
	if scope ~= nil and _defaultConn ~= nil then
		table.insert(scope, _defaultConn)
		table.insert(scope, function()
			_defaultConn = nil
		end)
	end
end

local function fromName(name: string): EnumItem?
	for _, item in _current.EnumType:GetEnumItems() do
		if item.Name == name then return item end
	end
	return nil
end

-- Inject a game-wide signal. That signal must Fire(Enum.PreferredInput)
-- or a string mapped via ToPreferredInput. Passing nil restores default UIS.
function PreferredInput.SetSource(customSignal: SignalPlus.Signal<EnumItem | string>?)
	if _customConn ~= nil then
		_customConn:Disconnect()
		_customConn = nil
	end

	_customSignal = customSignal
	if customSignal ~= nil then
		_customConn = customSignal:Connect(function(val)
			local mapped: EnumItem? = nil
			if typeof(val) == "EnumItem" then
				mapped = val
			elseif typeof(val) == "string" then
				-- string fallback: "KeyboardAndMouse" / "Gamepad" / "Touch"
				mapped = fromName(val)
			end
			if mapped ~= nil then setCurrent(mapped) end
		end)
	else
		-- restore UIS polling
		_current = UserInputService.PreferredInput
	end
end

function PreferredInput.Destroy()
	if _defaultConn ~= nil then _defaultConn:Disconnect(); _defaultConn = nil end
	if _customConn ~= nil then _customConn:Disconnect(); _customConn = nil end
	_customSignal = nil
end

return PreferredInput
