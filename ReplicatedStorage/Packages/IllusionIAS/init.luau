--!strict
--IllusionIAS.luau
--[[
////////////////////////////////////////////////
\\       Illusion's InputActionSystem        //
//          Input Manager using IAS          \\
//   More informations on the DevForum post  //
\\                By Illusion                \\
///////////////////////////////////////////////
]]

local IAS = require("@self/TypeDefinition")
local IASignal = require("@self/IllusionSignal")
local BindUtils = require("@self/BindUtils")

export type IAScriptConnection = IAS.IAScriptConnection
export type IAScriptSignal<T = variant> = IAS.IAScriptSignal<T>
export type variant = IAS.variant
export type Bind = IAS.Bind
export type Binds = IAS.Binds
export type BindingObject<T = variant> = IAS.BindingObject<T>
export type Context = IAS.Context
export type Contexts = IAS.Contexts
export type IllusionIAS = IAS.IllusionIAS
export type supposedKeyCode = IAS.supposedKeyCode
export type func<T = variant> = IAS.func<T>

@native local function getBindFolder(): Folder
	local existing = script:FindFirstChild("BindFolder")
	if existing and existing:IsA("Folder") then return existing end

	local folder = Instance.new("Folder")
	folder.Name = "BindFolder"
	folder.Parent = script

	return folder
end

@native local function instanceSetup(name: string, inputType: Enum.InputActionType, InputContext: InputContext): InputBinding
	local InputAction = Instance.new("InputAction")
	InputAction.Name = name
	InputAction.Type = inputType
	InputAction:SetAttribute("CustomName", InputContext.Name)
	InputAction.Parent = InputContext

	local InputBinding = Instance.new("InputBinding")
	InputBinding.Parent = InputAction

	return InputBinding
end

@native local function instanceDeletion(name: string, InputContext: InputContext)
	local inputAction = InputContext:FindFirstChild(name)
	if inputAction then inputAction:Destroy() end
end

@native local function valueOftypeGivesVariant(inputType: Enum.InputActionType): variant
	return
		if inputType == Enum.InputActionType.Bool then false
		elseif inputType == Enum.InputActionType.Direction1D then 0
		elseif inputType == Enum.InputActionType.Direction2D or inputType == Enum.InputActionType.ViewportPosition then Vector2.zero
		else Vector3.zero
end

@native local function valueOfVariantGivesPressed(variantValue: variant): boolean
	return
		if typeof(variantValue) == "boolean" then variantValue
		elseif typeof(variantValue) == "number" then variantValue ~= 0
		elseif typeof(variantValue) == "Vector2" then variantValue ~= Vector2.zero
		elseif typeof(variantValue) == "Vector3" then variantValue ~= Vector3.zero
		else false
end

@native local function convertStrToEnumKeycode(name: supposedKeyCode?): Enum.KeyCode
	return BindUtils.ConvertKeyCode(name)
end

@native local function getNameForBinding(key: Enum.KeyCode): string
	return IAS.InputTypeByKey[key] or "Input"
end

@native local function getBindNameFromKeyOrName(keyOrName: (supposedKeyCode | string)?, binds: Binds): string?
	if not keyOrName then return "MainAction" end

	if typeof(keyOrName) == "string" and binds[keyOrName] then
		return keyOrName
	end

	local keyEnum = convertStrToEnumKeycode(keyOrName)
	for bindName, bind in binds do
		if bindName ~= "UIButton" and bind.KeyCode == keyEnum then
			return bindName
		end
	end

	return nil
end

@native local function getBindNameFromKeyCode(mainKey: Enum.KeyCode, binds: Binds): string?
	for bindName, bind in binds do
		if bindName ~= "UIButton" and bind.KeyCode == mainKey then
			return bindName
		end
	end

	return nil
end

local IIAS = {} :: IllusionIAS
IIAS.contextedBinds = {}

local activeBinds: { [string]: BindingObject } = {}

function IIAS.new(name: string, inputType: Enum.InputActionType?): BindingObject
	if activeBinds[name] then return activeBinds[name] end
	local InputType = inputType or Enum.InputActionType.Bool

	local variantBaseValue = valueOftypeGivesVariant(InputType)

	local InputContext = Instance.new("InputContext")

	InputContext.Name = name
	InputContext.Priority = 1000
	InputContext.Sink = false
	InputContext.Enabled = true
	InputContext.Parent = getBindFolder()

	local MainName = "MainAction"

	local self: BindingObject = {
		Name = name,

		Hold = true,

		Binds = {
			MainAction = {
				KeyCode = Enum.KeyCode.None,
				PrimaryModifier = Enum.KeyCode.None,
				SecondaryModifier = Enum.KeyCode.None,
				UIButton = nil,
				UIModifier = nil,
				DisplayName = "",
				DisplayImage = nil,
				Type = Enum.InputBindingType.Automatic,
			},
			UIButton = {
				KeyCode = Enum.KeyCode.None,
				PrimaryModifier = Enum.KeyCode.None,
				SecondaryModifier = Enum.KeyCode.None,
				UIButton = nil,
				UIModifier = nil,
				DisplayName = "",
				DisplayImage = nil,
				Type = Enum.InputBindingType.Automatic,
			},
		},

		UIButton = nil,
		UIModifier = nil,

		Active = variantBaseValue,

		Enabled = true,
		Priority = 1000,
		Sink = false,

		Scale = 1,
		VectorScale = if InputType == Enum.InputActionType.Direction2D then Vector2.one else Vector3.one,
		ResponseCurve = 1,

		PointerIndex = 1,
		ClampMagnitudeToOne = true,

		PressedThreshold = 0.5,
		ReleasedThreshold = 0.2,

		Cooldown = 0,

		TapRequired = 1,
		TapWindow = 0,

		InputBufferEnabled = false,
		InputBufferTime = 0.15,

		Activated = IASignal.new(),
		Started = IASignal.new(),
		Ended = IASignal.new(),
	} :: BindingObject

	local stateConnections: { [string]: RBXScriptConnection } = {}

	local _PrevBinds = BindUtils.Clone(self.Binds)

	local _ToggleState = false
	local _CooldownUntil = 0
	local _LastTapTime = 0
	local _TapCount = 0

	local _ActiveBindName: string? = nil
	local _ActiveMainKey: Enum.KeyCode = Enum.KeyCode.None

	local _Buffered = false
	local _BufferedTime = 0
	local _BufferedBindName: string? = nil
	local _BufferedKey: Enum.KeyCode = Enum.KeyCode.None
	local _BufferedVariant: variant? = nil

	local blockedPresses: { [string]: boolean } = {}
	local uiButtonDestroyConn: RBXScriptConnection? = nil
	local uiModifierDestroyConn: RBXScriptConnection? = nil

	local function fire(value: variant, pressed: boolean)
		if not self.Enabled then return end

		self.Active = value
		self.Activated:Fire(value, pressed)

		if pressed then
			self.Started:Fire(value)
		else
			self.Ended:Fire(value)
		end
	end

	local function tryConsumeBuffer(): boolean
		if not _Buffered then return false end

		local now = os.clock()
		if (now - _BufferedTime) > self.InputBufferTime then
			_Buffered = false
			_BufferedBindName = nil
			_BufferedKey = Enum.KeyCode.None
			_BufferedVariant = nil
			return false
		end

		if _ActiveBindName and _ActiveBindName ~= _BufferedBindName then
			return false
		end

		if self.Cooldown > 0 and now < _CooldownUntil then
			_Buffered = false
			_BufferedBindName = nil
			_BufferedKey = Enum.KeyCode.None
			_BufferedVariant = nil
			return false
		end

		_Buffered = false
		local bufferedBind = _BufferedBindName or MainName
		local keyEnum = _BufferedKey
		local bufferedVariant = _BufferedVariant
		_BufferedBindName = nil
		_BufferedKey = Enum.KeyCode.None
		_BufferedVariant = nil

		_ActiveBindName = bufferedBind
		if bufferedBind ~= "UIButton" then
			_ActiveMainKey = keyEnum
		else
			_ActiveMainKey = Enum.KeyCode.None
		end

		local activeValue = if InputType == Enum.InputActionType.Bool then true else (bufferedVariant or variantBaseValue)
		local inactiveValue = variantBaseValue

		if self.Hold then
			fire(activeValue, true)
			if self.Cooldown > 0 then _CooldownUntil = now + self.Cooldown end
			return true
		else
			_ToggleState = not _ToggleState
			fire(if _ToggleState then activeValue else inactiveValue, true)
			if _ToggleState and self.Cooldown > 0 then _CooldownUntil = now + self.Cooldown end
			return true
		end
	end

	local function applyBindingProperties(binding: InputBinding)
		binding.Scale = self.Scale
		if InputType == Enum.InputActionType.Direction2D then
			binding.Vector2Scale = if typeof(self.VectorScale) == "Vector2" then self.VectorScale else Vector2.one
		elseif InputType == Enum.InputActionType.Direction3D then
			binding.Vector3Scale = if typeof(self.VectorScale) == "Vector3" then self.VectorScale else Vector3.one
		end
		binding.ResponseCurve = self.ResponseCurve
		binding.PressedThreshold = self.PressedThreshold
		binding.ReleasedThreshold = self.ReleasedThreshold
		binding.PointerIndex = self.PointerIndex
		binding.ClampMagnitudeToOne = self.ClampMagnitudeToOne
	end

	local function updateAllBindingsProperties()
		if not InputContext then return end
		for _, action in InputContext:GetChildren() do
			if action:IsA("InputAction") then
				local binding = action:FindFirstChildOfClass("InputBinding")
				if binding then
					applyBindingProperties(binding)
				end
			end
		end
	end

	local function connectAction(child: Instance)
		if child:IsA("InputAction") then
			stateConnections[child.Name] = child.StateChanged:Connect(function(variant: variant)
				if not self.Enabled then return end

				local pressed = valueOfVariantGivesPressed(variant)

				local inputBinding = child:FindFirstChildOfClass("InputBinding")
				if not inputBinding then return end

				local bindName = child.Name
				local keyEnum = if bindName ~= "UIButton" then inputBinding.KeyCode else Enum.KeyCode.None

				local now = os.clock()

				if InputType ~= Enum.InputActionType.ViewportPosition then
					local activeValue = if InputType == Enum.InputActionType.Bool then true else variant
					local inactiveValue = variantBaseValue

					if pressed then
						if _ActiveBindName ~= nil and _ActiveBindName ~= bindName then
							if self.InputBufferEnabled then
								_Buffered = true
								_BufferedTime = now
								_BufferedBindName = bindName
								_BufferedKey = keyEnum
								_BufferedVariant = if InputType ~= Enum.InputActionType.Bool then variant else nil
							end
							return
						end

						if self.TapRequired > 1 then
							if now - _LastTapTime > self.TapWindow then
								_TapCount = 1
							else
								_TapCount += 1
							end
							_LastTapTime = now

							if _TapCount < self.TapRequired then
								return
							end
						end

						if self.Cooldown > 0 and now < _CooldownUntil then
							_TapCount = 0
							fire(inactiveValue, true)
							blockedPresses[bindName] = true
							return
						end

						_ActiveBindName = bindName
						if bindName ~= "UIButton" then
							_ActiveMainKey = keyEnum
						else
							_ActiveMainKey = Enum.KeyCode.None
						end

						if self.Hold then
							fire(activeValue, true)
							if self.Cooldown > 0 then
								_CooldownUntil = now + self.Cooldown
							end
						else
							_ToggleState = not _ToggleState
							fire(if _ToggleState then activeValue else inactiveValue, true)
							if _ToggleState and self.Cooldown > 0 then
								_CooldownUntil = now + self.Cooldown
							end
						end

						_TapCount = 0
						return
					end

					if blockedPresses[bindName] then
						blockedPresses[bindName] = nil
						fire(inactiveValue, false)
						return
					end

					if _ActiveBindName ~= bindName then
						return
					end

					if self.Hold then
						_ActiveBindName = nil
						_ActiveMainKey = Enum.KeyCode.None
						_ToggleState = false
						fire(inactiveValue, false)

						tryConsumeBuffer()
						return
					end

					if _TapCount == 0 then
						fire(if _ToggleState then self.Active else inactiveValue, false)
					end

					_ActiveBindName = nil
					_ActiveMainKey = Enum.KeyCode.None
					tryConsumeBuffer()

					return

				elseif InputType == Enum.InputActionType.ViewportPosition then
					if self.Cooldown > 0 and now < _CooldownUntil then
						fire(Vector2.zero, false)
						return
					end

					fire(variant, pressed)

					if pressed and self.Cooldown > 0 then
						_CooldownUntil = now + self.Cooldown
					end

					return
				end
			end)
		end
	end

	local childAddedConn: RBXScriptConnection? = InputContext.ChildAdded:Connect(connectAction)

	local childRemovedConn: RBXScriptConnection? = InputContext.ChildRemoved:Connect(function(child)
		if stateConnections[child.Name] then
			stateConnections[child.Name]:Disconnect()
			stateConnections[child.Name] = nil
		end
	end)

	local rebuilding = false
	local destroyed = false

	local function rebuild()
		if rebuilding or destroyed or not InputContext then return end
		rebuilding = true

		local isEqual, differences = BindUtils.CheckDifferences(_PrevBinds, self.Binds)
		if not isEqual and differences then
			local diffs = BindUtils.GetDifference(_PrevBinds, differences)

			for _, diff in diffs do
				if diff.ChangeType == "Added" then
					local binding = instanceSetup(diff.BindName, InputType, InputContext)
					if diff.BindName == "UIButton" then
						if diff.UIButton then
							binding.UIButton = diff.UIButton
						end
						if diff.UIModifier then
							binding.UIModifier = diff.UIModifier
						end
					else
						binding.KeyCode = diff.NewKeyCode or Enum.KeyCode.None
						binding.Name = getNameForBinding(binding.KeyCode) .. "Binding"
						binding.PrimaryModifier = diff.NewModifiers.PrimaryModifier
						binding.SecondaryModifier = diff.NewModifiers.SecondaryModifier
					end
					binding.DisplayName = diff.DisplayName or ""
					if diff.DisplayImage then
						binding.DisplayImage = diff.DisplayImage
					end
					binding.Type = diff.BindingType or Enum.InputBindingType.Automatic
					applyBindingProperties(binding)

				elseif diff.ChangeType == "Modified" then
					local action = InputContext:FindFirstChild(diff.BindName)
					if action and action:IsA("InputAction") then
						local binding = action:FindFirstChildOfClass("InputBinding")
						if binding then
							if diff.BindName == "UIButton" then
								if diff.UIButton then
									binding.UIButton = diff.UIButton
								end
								if diff.UIModifier then
									binding.UIModifier = diff.UIModifier
								end
							else
								if diff.NewKeyCode then
									binding.KeyCode = diff.NewKeyCode
									binding.Name = getNameForBinding(binding.KeyCode) .. "Binding"
								end
								binding.PrimaryModifier = diff.NewModifiers.PrimaryModifier
								binding.SecondaryModifier = diff.NewModifiers.SecondaryModifier
							end
							if diff.DisplayName ~= nil then binding.DisplayName = diff.DisplayName end
							if diff.DisplayImage ~= nil then binding.DisplayImage = diff.DisplayImage end
							if diff.BindingType ~= nil then binding.Type = diff.BindingType end
							applyBindingProperties(binding)
						end
					end

				elseif diff.ChangeType == "Removed" then
					instanceDeletion(diff.BindName, InputContext)
				end
			end

			BindUtils.ApplyDifferences(_PrevBinds, differences)
			_PrevBinds = BindUtils.Clone(self.Binds)
		end

		rebuilding = false
	end

	local mainBinding = instanceSetup(MainName, InputType, InputContext)
	mainBinding.Name = "InputBinding"
	mainBinding.KeyCode = Enum.KeyCode.None
	mainBinding.PrimaryModifier = Enum.KeyCode.None
	mainBinding.SecondaryModifier = Enum.KeyCode.None
	mainBinding.DisplayName = ""
	mainBinding.Type = Enum.InputBindingType.Automatic
	applyBindingProperties(mainBinding)

	local uiBinding = instanceSetup("UIButton", InputType, InputContext)
	uiBinding.Name = "InputBinding"
	uiBinding.DisplayName = ""
	uiBinding.Type = Enum.InputBindingType.Automatic
	applyBindingProperties(uiBinding)

	function self:Fire(active: variant, pressed: boolean)
		fire(active, pressed)
	end

	function self:SetHold(bool: boolean)
		self.Hold = bool
	end

	function self:SetUIButton(button: GuiButton?)
		if uiButtonDestroyConn then
			uiButtonDestroyConn:Disconnect()
			uiButtonDestroyConn = nil
		end

		self.UIButton = button
		BindUtils.SetUIButton(self.Binds, "UIButton", button)
		local uiAction = InputContext and InputContext:FindFirstChild("UIButton")
		if uiAction then
			local binding = uiAction:FindFirstChildOfClass("InputBinding")
			if binding and button then
				binding.UIButton = button
			end
		end

		if button then
			uiButtonDestroyConn = button.Destroying:Connect(function()
				if _ActiveBindName == "UIButton" then
					_ActiveBindName = nil
					_ActiveMainKey = Enum.KeyCode.None
					_ToggleState = false
					fire(variantBaseValue, false)
				end
				self:SetUIButton(nil)
			end)
		end
	end

	function self:SetUIModifier(button: GuiButton?)
		if uiModifierDestroyConn then
			uiModifierDestroyConn:Disconnect()
			uiModifierDestroyConn = nil
		end

		self.UIModifier = button
		BindUtils.SetUIModifier(self.Binds, "UIButton", button)
		local uiAction = InputContext and InputContext:FindFirstChild("UIButton")
		if uiAction then
			local binding = uiAction:FindFirstChildOfClass("InputBinding")
			if binding and button then
				binding.UIModifier = button
			end
		end

		if button then
			uiModifierDestroyConn = button.Destroying:Connect(function()
				self:SetUIModifier(nil)
			end)
		end
	end

	function self:GetUIModifier(): GuiButton?
		return self.UIModifier
	end

	function self:SetCooldown(cooldown: number)
		self.Cooldown = math.max(0, cooldown)
	end

	function self:ResetCooldown()
		_CooldownUntil = 0
	end

	function self:CooldownEnded(): boolean
		return self:GetCooldownRemaining() <= 0
	end

	function self:SetTapActivation(requiredTaps: number, tapWindow: number)
		self.TapRequired = math.max(1, requiredTaps)
		self.TapWindow = math.max(0, tapWindow)
		_TapCount = 0
		_LastTapTime = 0
	end

	function self:SetEnabled(enabled: boolean)
		if self.Enabled == enabled then return end
		self.Enabled = enabled

		if not enabled then
			self.Active = variantBaseValue
			_ActiveBindName = nil
			_ActiveMainKey = Enum.KeyCode.None
			_ToggleState = false
			_Buffered = false
			_BufferedBindName = nil
			_BufferedKey = Enum.KeyCode.None
			_BufferedVariant = nil
			_TapCount = 0
			table.clear(blockedPresses)
			self.Activated:Fire(variantBaseValue, false)
			self.Ended:Fire(variantBaseValue)
		end

		if InputContext then
			InputContext.Enabled = enabled
		end
	end

	function self:IsEnabled(): boolean
		return self.Enabled
	end

	function self:SetPriority(priority: number)
		self.Priority = priority
		if InputContext then
			InputContext.Priority = priority
		end
	end

	function self:GetPriority(): number
		return self.Priority
	end

	function self:SetSink(sink: boolean)
		self.Sink = sink
		if InputContext then
			InputContext.Sink = sink
		end
	end

	function self:GetSink(): boolean
		return self.Sink
	end

	function self:SetScale(scale: number)
		self.Scale = scale
		updateAllBindingsProperties()
	end

	function self:GetScale(): number
		return self.Scale
	end

	function self:SetVectorScale(vector: Vector2 | Vector3)
		self.VectorScale = vector
		updateAllBindingsProperties()
	end

	function self:GetVectorScale(): Vector2 | Vector3
		return self.VectorScale
	end

	function self:SetInputBufferEnabled(enabled: boolean)
		self.InputBufferEnabled = enabled
	end

	function self:SetResponseCurve(curve: number)
		self.ResponseCurve = curve
		updateAllBindingsProperties()
	end

	function self:GetResponseCurve(): number
		return self.ResponseCurve
	end

	function self:SetPressedThreshold(threshold: number)
		self.PressedThreshold = threshold
		updateAllBindingsProperties()
	end

	function self:GetPressedThreshold(): number
		return self.PressedThreshold
	end

	function self:SetReleasedThreshold(threshold: number)
		self.ReleasedThreshold = threshold
		updateAllBindingsProperties()
	end

	function self:GetReleasedThreshold(): number
		return self.ReleasedThreshold
	end

	function self:SetPointerIndex(index: number)
		self.PointerIndex = index
		updateAllBindingsProperties()
	end

	function self:GetPointerIndex(): number
		return self.PointerIndex
	end

	function self:SetClampMagnitudeToOne(bool: boolean)
		self.ClampMagnitudeToOne = bool
		updateAllBindingsProperties()
	end

	function self:GetClampMagnitudeToOne(): boolean
		return self.ClampMagnitudeToOne
	end

	function self:SetInputBufferTime(t: number)
		self.InputBufferTime = math.max(0, t)
	end

	function self:GetState(): variant
		return self.Active
	end

	function self:GetCooldownRemaining(): number
		local now = os.clock()
		return math.max(0, _CooldownUntil - now)
	end

	function self:IsBuffered(): boolean
		return _Buffered
	end

	function self:ResetBuffer()
		_Buffered = false
		_BufferedTime = 0
		_BufferedBindName = nil
		_BufferedKey = Enum.KeyCode.None
		_BufferedVariant = nil
	end

	function self:GetBufferedVariant(): variant?
		return _BufferedVariant
	end

	function self:GetBufferedKey(): Enum.KeyCode
		return _BufferedKey
	end

	function self:GetActiveBindCount(): number
		return if _ActiveBindName ~= nil then 1 else 0
	end

	function self:GetToggleState(): boolean
		return _ToggleState
	end

	function self:GetActiveMainKey(): Enum.KeyCode
		return _ActiveMainKey
	end

	function self:ClearBinds()
		BindUtils.ResetBinds(self.Binds)
		self.UIButton = nil
		self.UIModifier = nil
		rebuild()
	end

	function self:GetBinds(): Binds
		return BindUtils.Clone(self.Binds)
	end

	function self:AddBind(
		mainKey: supposedKeyCode,
		PrimaryModifier: supposedKeyCode?,
		SecondaryModifier: supposedKeyCode?,
		UIButton: GuiButton?,
		UIModifier: GuiButton?,
		DisplayName: string?,
		DisplayImage: Content?,
		BindingType: Enum.InputBindingType?
	)
		local keyEnum = convertStrToEnumKeycode(mainKey)
		local pmEnum = convertStrToEnumKeycode(PrimaryModifier)
		local smEnum = convertStrToEnumKeycode(SecondaryModifier)

		if UIButton then
			self:SetUIButton(UIButton)
		end
		if UIModifier then
			self:SetUIModifier(UIModifier)
		end

		if keyEnum == Enum.KeyCode.None then return end

		for bindName, bind in self.Binds do
			if bindName ~= "UIButton" and bind.KeyCode == keyEnum and bind.PrimaryModifier == pmEnum and bind.SecondaryModifier == smEnum then
				BindUtils.SetModifiers(self.Binds, bindName, pmEnum, smEnum)
				if DisplayName ~= nil then BindUtils.SetDisplayName(self.Binds, bindName, DisplayName) end
				if DisplayImage ~= nil then BindUtils.SetDisplayImage(self.Binds, bindName, DisplayImage) end
				if BindingType ~= nil then BindUtils.SetBindingType(self.Binds, bindName, BindingType) end
				rebuild()
				return
			end
		end

		local mainBind = self.Binds[MainName]
		if mainBind and mainBind.KeyCode == Enum.KeyCode.None then
			BindUtils.SetKeyCode(self.Binds, MainName, keyEnum)
			BindUtils.SetModifiers(self.Binds, MainName, pmEnum, smEnum)
			if DisplayName ~= nil then BindUtils.SetDisplayName(self.Binds, MainName, DisplayName) end
			if DisplayImage ~= nil then BindUtils.SetDisplayImage(self.Binds, MainName, DisplayImage) end
			if BindingType ~= nil then BindUtils.SetBindingType(self.Binds, MainName, BindingType) end
			rebuild()
			return
		end

		local index = 1
		local bindName
		repeat
			bindName = `AltAction{index}`
			index += 1
		until not self.Binds[bindName]

		BindUtils.AddBind(
			self.Binds,
			bindName,
			keyEnum,
			pmEnum,
			smEnum,
			nil,
			nil,
			DisplayName,
			DisplayImage,
			BindingType
		)
		rebuild()
	end

	function self:SetAllBinds(Binds: Binds)
		self.Binds = BindUtils.Clone(Binds)
		rebuild()
	end

	function self:SetBind(
		mainKey: supposedKeyCode,
		PrimaryModifier: supposedKeyCode?,
		SecondaryModifier: supposedKeyCode?,
		UIButton: GuiButton?,
		UIModifier: GuiButton?,
		DisplayName: string?,
		DisplayImage: Content?,
		BindingType: Enum.InputBindingType?
	)
		self:ClearBinds()
		self:AddBind(mainKey, PrimaryModifier, SecondaryModifier, UIButton, UIModifier, DisplayName, DisplayImage, BindingType)
	end

	function self:RemoveBind(mainKey: supposedKeyCode, PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?)
		local keyCode: Enum.KeyCode = convertStrToEnumKeycode(mainKey)
		local primary: Enum.KeyCode = convertStrToEnumKeycode(PrimaryModifier)
		local secondary: Enum.KeyCode = convertStrToEnumKeycode(SecondaryModifier)

		if keyCode == Enum.KeyCode.None then return end

		for bindName, bind in self.Binds do
			if bindName == "UIButton" or bind.KeyCode ~= keyCode then continue end

			if not BindUtils.Matches(bind, keyCode, primary, secondary) then continue end

			if bindName == MainName then
				BindUtils.ResetKeyCode(self.Binds, MainName)
				BindUtils.ClearModifiers(self.Binds, MainName)
				BindUtils.SetDisplayName(self.Binds, MainName, "")
				BindUtils.SetDisplayImage(self.Binds, MainName, nil)
			else
				BindUtils.RemoveBind(self.Binds, bindName)
			end

			rebuild()
			return
		end
	end

	function self:EditBind(
		oldMain: supposedKeyCode,
		oldMods: { PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? },
		newMain: supposedKeyCode,
		newMods: { PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode? }
	)
		local oldKeyCode: Enum.KeyCode = convertStrToEnumKeycode(oldMain)
		local newKeyCode: Enum.KeyCode = convertStrToEnumKeycode(newMain)
		local oldPrimary: Enum.KeyCode = convertStrToEnumKeycode(oldMods.PrimaryModifier)
		local oldSecondary: Enum.KeyCode = convertStrToEnumKeycode(oldMods.SecondaryModifier)

		if oldKeyCode == Enum.KeyCode.None or newKeyCode == Enum.KeyCode.None then return end

		for bindName, bind in self.Binds do
			if bindName == "UIButton" or bind.KeyCode ~= oldKeyCode then continue end

			if not BindUtils.Matches(bind, oldKeyCode, oldPrimary, oldSecondary) then continue end

			BindUtils.SetKeyCode(self.Binds, bindName, newKeyCode)
			BindUtils.SetModifiers(self.Binds, bindName, newMods.PrimaryModifier, newMods.SecondaryModifier)
			rebuild()
			return
		end
	end

	function self:SetDisplayName(mainKey: supposedKeyCode, displayName: string): boolean
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return false end

		BindUtils.SetDisplayName(self.Binds, bindName, displayName)

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			action:SetAttribute("CustomName", displayName)
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding then
				binding.DisplayName = displayName
			end
		end

		return true
	end

	function self:GetDisplayName(mainKey: supposedKeyCode): string?
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return nil end

		local bind = self.Binds[bindName]
		if bind and bind.DisplayName and bind.DisplayName ~= "" then
			return bind.DisplayName
		end

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding and binding.DisplayName ~= "" then
				return binding.DisplayName
			end
			local customName = action:GetAttribute("CustomName")
			if typeof(customName) == "string" and customName ~= "" then
				return customName
			end
		end

		return self.Name
	end

	function self:SetDisplayImage(mainKey: supposedKeyCode, displayImage: Content): boolean
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return false end

		BindUtils.SetDisplayImage(self.Binds, bindName, displayImage)

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding then
				binding.DisplayImage = displayImage
			end
		end

		return true
	end

	function self:GetDisplayImage(mainKey: supposedKeyCode): Content?
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return nil end

		local bind = self.Binds[bindName]
		if bind and bind.DisplayImage ~= nil then
			return bind.DisplayImage
		end

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding then
				return binding.DisplayImage
			end
		end

		return nil
	end

	function self:SetBindingType(mainKey: supposedKeyCode, bindingType: Enum.InputBindingType): boolean
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return false end

		BindUtils.SetBindingType(self.Binds, bindName, bindingType)

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding then
				binding.Type = bindingType
			end
		end

		return true
	end

	function self:GetBindingType(mainKey: supposedKeyCode): Enum.InputBindingType?
		local keyCode = convertStrToEnumKeycode(mainKey)
		local bindName = getBindNameFromKeyCode(keyCode, self.Binds)
		if not bindName then return nil end

		local bind = self.Binds[bindName]
		if bind and bind.Type ~= nil then
			return bind.Type
		end

		local action = InputContext and InputContext:FindFirstChild(bindName)
		if action and action:IsA("InputAction") then
			local binding = action:FindFirstChildOfClass("InputBinding")
			if binding then
				return binding.Type
			end
		end

		return Enum.InputBindingType.Automatic
	end

	function self:SetCompositeDirections(
		up: supposedKeyCode?,
		down: supposedKeyCode?,
		left: supposedKeyCode?,
		right: supposedKeyCode?,
		forward: supposedKeyCode?,
		backward: supposedKeyCode?
	)
		if InputType == Enum.InputActionType.Bool or InputType == Enum.InputActionType.ViewportPosition then return end

		local mainAction = InputContext and InputContext:FindFirstChild(MainName)
		local targetBinding = mainAction and mainAction:FindFirstChildOfClass("InputBinding")
		if not targetBinding then return end

		targetBinding.Up = convertStrToEnumKeycode(up)
		targetBinding.Down = convertStrToEnumKeycode(down)
		targetBinding.Left = convertStrToEnumKeycode(left)
		targetBinding.Right = convertStrToEnumKeycode(right)
		targetBinding.Forward = convertStrToEnumKeycode(forward)
		targetBinding.Backward = convertStrToEnumKeycode(backward)
	end

	function self:GetCompositeDirections(): {
		Up: Enum.KeyCode,
		Down: Enum.KeyCode,
		Left: Enum.KeyCode,
		Right: Enum.KeyCode,
		Forward: Enum.KeyCode,
		Backward: Enum.KeyCode,
		}
		local mainAction = InputContext and InputContext:FindFirstChild(MainName)
		local targetBinding = mainAction and mainAction:FindFirstChildOfClass("InputBinding")
		if not targetBinding then
			return {
				Up = Enum.KeyCode.None,
				Down = Enum.KeyCode.None,
				Left = Enum.KeyCode.None,
				Right = Enum.KeyCode.None,
				Forward = Enum.KeyCode.None,
				Backward = Enum.KeyCode.None,
			}
		end

		return {
			Up = targetBinding.Up or Enum.KeyCode.None,
			Down = targetBinding.Down or Enum.KeyCode.None,
			Left = targetBinding.Left or Enum.KeyCode.None,
			Right = targetBinding.Right or Enum.KeyCode.None,
			Forward = targetBinding.Forward or Enum.KeyCode.None,
			Backward = targetBinding.Backward or Enum.KeyCode.None,
		}
	end

	function self:SetCompositeModifiers(PrimaryModifier: supposedKeyCode?, SecondaryModifier: supposedKeyCode?)
		if InputType == Enum.InputActionType.Bool or InputType == Enum.InputActionType.ViewportPosition then return end

		local mainAction = InputContext and InputContext:FindFirstChild(MainName)
		local targetBinding = mainAction and mainAction:FindFirstChildOfClass("InputBinding")
		if not targetBinding then return end

		targetBinding.PrimaryModifier = convertStrToEnumKeycode(PrimaryModifier)
		targetBinding.SecondaryModifier = convertStrToEnumKeycode(SecondaryModifier)
	end

	function self:GetCompositeModifiers(): {
		PrimaryModifier: Enum.KeyCode,
		SecondaryModifier: Enum.KeyCode,
		}
		local mainAction = InputContext and InputContext:FindFirstChild(MainName)
		local targetBinding = mainAction and mainAction:FindFirstChildOfClass("InputBinding")
		if not targetBinding then
			return {
				PrimaryModifier = Enum.KeyCode.None,
				SecondaryModifier = Enum.KeyCode.None,
			}
		end

		return {
			PrimaryModifier = targetBinding.PrimaryModifier or Enum.KeyCode.None,
			SecondaryModifier = targetBinding.SecondaryModifier or Enum.KeyCode.None,
		}
	end

	function self:GetPreferredBinding(): InputBinding?
		if not InputContext then return nil end
		local activeAction = InputContext:FindFirstChild(_ActiveBindName or MainName)
		if activeAction and activeAction:IsA("InputAction") then
			return activeAction.PreferredBinding or activeAction:FindFirstChildOfClass("InputBinding")
		end
		return nil
	end

	function self:GetInputAction(): InputAction?
		local mainAction = InputContext and InputContext:FindFirstChild(MainName)
		if mainAction and mainAction:IsA("InputAction") then
			return mainAction
		end
		return (InputContext and InputContext:FindFirstChildOfClass("InputAction"))
	end

	function self:GetInputContext(): InputContext?
		return InputContext
	end

	function self:GetInputBinding(keyOrName: (supposedKeyCode | string)?): InputBinding?
		if not InputContext then return nil end
		local bindName = getBindNameFromKeyOrName(keyOrName, self.Binds)
		if bindName then
			local action = InputContext:FindFirstChild(bindName)
			if action and action:IsA("InputAction") then
				return action:FindFirstChildOfClass("InputBinding")
			end
		end
		return nil
	end

	function self:CreateActionLabel(parent: Instance?): GuiObject?
		local mainAction = self:GetInputAction()
		if not mainAction then return nil end
		local ok, label = pcall(function()
			local lbl = Instance.new("InputActionLabel")
			lbl.InputAction = mainAction
			lbl.Parent = parent
			return lbl
		end)
		if not ok then
			warn("[IIAS] Failed to create InputActionLabel: " .. tostring(label))
			return nil
		end
		return label
	end

	function self:Destroy(): boolean
		if destroyed then return false end
		destroyed = true

		for connName, conn in stateConnections do
			conn:Disconnect()
		end
		table.clear(stateConnections)

		if childAddedConn then
			childAddedConn:Disconnect()
			childAddedConn = nil
		end

		if childRemovedConn then
			childRemovedConn:Disconnect()
			childRemovedConn = nil
		end

		if uiButtonDestroyConn then
			uiButtonDestroyConn:Disconnect()
			uiButtonDestroyConn = nil
		end

		if uiModifierDestroyConn then
			uiModifierDestroyConn:Disconnect()
			uiModifierDestroyConn = nil
		end

		for _, context in IIAS.contextedBinds do
			context.Members[self.Name] = nil
		end

		if InputContext then
			for _, child in InputContext:GetChildren() do
				child:Destroy()
			end
			InputContext:Destroy()
		end

		self.Activated:DisconnectAll()
		self.Started:DisconnectAll()
		self.Ended:DisconnectAll()

		activeBinds[name] = nil

		return true
	end

	activeBinds[name] = self
	return self
end

function IIAS.enableControlHints(module: Instance | string, parent: Instance | PlayerGui?): ScreenGui
	-- Credits: ZurichBT - ControlHints https://devforum.roblox.com/t/control-hints-show-your-ias-bindings-pc-xbox-playstation-mobile/3978604/
	return (module and (require)(module)).CreateUI(getBindFolder(), parent)
end

function IIAS.get(name: string): BindingObject?
	return activeBinds[name]
end

function IIAS.getAll(): { [string]: BindingObject }
	return table.clone(activeBinds)
end

local function evaluateActionContexts(actionName: string)
	local obj = IIAS.get(actionName)
	if not obj then return end

	local shouldEnable = true
	for _, ctx in IIAS.contextedBinds do
		if ctx.Members[actionName] and not ctx.Enabled then
			shouldEnable = false
			break
		end
	end

	obj:SetEnabled(shouldEnable)
end

function IIAS.newContext(name: string)
	if not IIAS.contextedBinds[name] then
		IIAS.contextedBinds[name] = {
			Enabled = true,
			Members = {},
		}
	end
end

function IIAS.getContext(name: string): Context?
	local ctx = IIAS.contextedBinds[name]
	if not ctx then return nil end
	return {
		Enabled = ctx.Enabled,
		Members = table.clone(ctx.Members),
	}
end

function IIAS.addContext(name: string, ...: BindingObject)
	IIAS.newContext(name)
	local context = IIAS.contextedBinds[name]
	for _, obj in { ... } do
		context.Members[obj.Name] = true
		evaluateActionContexts(obj.Name)
	end
end

function IIAS.enableContext(name: string, enabled: boolean)
	local context = IIAS.contextedBinds[name]
	if not context then return end
	context.Enabled = enabled

	for bindName in context.Members do
		evaluateActionContexts(bindName)
	end
end

function IIAS.isContextEnabled(name: string): boolean
	if not IIAS.contextedBinds[name] then return false end
	return IIAS.contextedBinds[name].Enabled
end

function IIAS.removeContext(name: string)
	local context = IIAS.contextedBinds[name]
	if not context then return end
	local oldMembers = context.Members
	IIAS.contextedBinds[name] = nil
	for bindName in oldMembers do
		evaluateActionContexts(bindName)
	end
end

function IIAS.removeFromContext(name: string, bind: BindingObject)
	local context = IIAS.contextedBinds[name]
	if not context then return end
	context.Members[bind.Name] = nil
	evaluateActionContexts(bind.Name)
end

function IIAS.removeAllFromContext(name: string)
	local context = IIAS.contextedBinds[name]
	if not context then return end
	local oldMembers = context.Members
	context.Members = {}
	for bindName in oldMembers do
		evaluateActionContexts(bindName)
	end
end

function IIAS.clearContexts()
	local allOldMembers: { [string]: boolean } = {}
	for _, ctx in IIAS.contextedBinds do
		for bindName in ctx.Members do
			allOldMembers[bindName] = true
		end
	end
	table.clear(IIAS.contextedBinds)
	for bindName in allOldMembers do
		evaluateActionContexts(bindName)
	end
end

return IIAS
