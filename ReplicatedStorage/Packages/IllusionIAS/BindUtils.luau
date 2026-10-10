--!strict
--BindUtils.luau
--[[
  //////////////////////
 //   Bind Utility   //
//////////////////////
]]

local BindUtils = {}

local IAS = require("./TypeDefinition")

local REMOVED: IAS.Bind = {
	KeyCode = Enum.KeyCode.None,
	PrimaryModifier = Enum.KeyCode.None,
	SecondaryModifier = Enum.KeyCode.None,
	UIButton = nil,
	UIModifier = nil,
	DisplayName = nil,
	DisplayImage = nil,
	Type = nil,
}

@native local function convertStrToEnumKeycode(name: IAS.supposedKeyCode?): Enum.KeyCode
	if not name then return Enum.KeyCode.None end
	if typeof(name) == "string" then
		if name == "MouseButton1" then
			return Enum.KeyCode.MouseLeftButton
		elseif name == "MouseButton2" then
			return Enum.KeyCode.MouseRightButton
		elseif name == "MouseButton3" then
			return Enum.KeyCode.MouseMiddleButton
		elseif name == "Touch" then
			return Enum.KeyCode.TouchPosition
		end
		local found = Enum.KeyCode:FromName(name)
		if found then return found end
		return Enum.KeyCode.None
	end
	return (if typeof(name) == "EnumItem" then name else nil) or Enum.KeyCode.None
end

local function getBind(binds: IAS.Binds, name: string): IAS.Bind?
	return binds[name]
end

function BindUtils.ConvertKeyCode(name: IAS.supposedKeyCode?): Enum.KeyCode
	return convertStrToEnumKeycode(name)
end

function BindUtils.Matches(
	bind: IAS.Bind,
	keyCode: Enum.KeyCode,
	primary: Enum.KeyCode?,
	secondary: Enum.KeyCode?
): boolean
	return bind.KeyCode == keyCode
		and (bind.PrimaryModifier or Enum.KeyCode.None) == (primary or Enum.KeyCode.None)
		and (bind.SecondaryModifier or Enum.KeyCode.None) == (secondary or Enum.KeyCode.None)
end

function BindUtils.AddBind(
	binds: IAS.Binds,
	name: string,
	keyCode: IAS.supposedKeyCode?,
	PrimaryModifier: IAS.supposedKeyCode?,
	SecondaryModifier: IAS.supposedKeyCode?,
	UIButton: GuiButton?,
	UIModifier: GuiButton?,
	DisplayName: string?,
	DisplayImage: Content?,
	BindingType: Enum.InputBindingType?
): boolean
	if binds[name] ~= nil then return false end

	if name == "UIButton" then
		binds[name] = {
			KeyCode = Enum.KeyCode.None,
			PrimaryModifier = Enum.KeyCode.None,
			SecondaryModifier = Enum.KeyCode.None,
			UIButton = UIButton,
			UIModifier = UIModifier,
			DisplayName = DisplayName or "",
			DisplayImage = DisplayImage,
			Type = BindingType or Enum.InputBindingType.Automatic,
		}
	else
		binds[name] = {
			KeyCode = convertStrToEnumKeycode(keyCode),
			PrimaryModifier = convertStrToEnumKeycode(PrimaryModifier),
			SecondaryModifier = convertStrToEnumKeycode(SecondaryModifier),
			UIButton = nil,
			UIModifier = nil,
			DisplayName = DisplayName or "",
			DisplayImage = DisplayImage,
			Type = BindingType or Enum.InputBindingType.Automatic,
		}
	end

	return true
end

function BindUtils.RemoveBind(binds: IAS.Binds, name: string): boolean
	if binds[name] == nil then return false end
	if name == "MainAction" then
		binds.MainAction = {
			KeyCode = Enum.KeyCode.None,
			PrimaryModifier = Enum.KeyCode.None,
			SecondaryModifier = Enum.KeyCode.None,
			UIButton = nil,
			UIModifier = nil,
			DisplayName = "",
			DisplayImage = nil,
			Type = Enum.InputBindingType.Automatic,
		}
		return true
	elseif name == "UIButton" then
		binds.UIButton = {
			KeyCode = Enum.KeyCode.None,
			PrimaryModifier = Enum.KeyCode.None,
			SecondaryModifier = Enum.KeyCode.None,
			UIButton = nil,
			UIModifier = nil,
			DisplayName = "",
			DisplayImage = nil,
			Type = Enum.InputBindingType.Automatic,
		}
		return true
	end

	binds[name] = nil
	return true
end

local function setKeyCode(binds: IAS.Binds, name: string, keyCode: IAS.supposedKeyCode): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.KeyCode = convertStrToEnumKeycode(keyCode)
	return true
end

local function setModifiers(binds: IAS.Binds, name: string, PrimaryModifier: IAS.supposedKeyCode?, SecondaryModifier: IAS.supposedKeyCode?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.PrimaryModifier = convertStrToEnumKeycode(PrimaryModifier)
	bind.SecondaryModifier = convertStrToEnumKeycode(SecondaryModifier)
	return true
end

function BindUtils.SetKeyCode(binds: IAS.Binds, name: string, keyCode: IAS.supposedKeyCode): boolean
	return setKeyCode(binds, name, keyCode)
end

function BindUtils.ResetKeyCode(binds: IAS.Binds, name: string): boolean
	return setKeyCode(binds, name, Enum.KeyCode.None)
end

function BindUtils.SetModifiers(binds: IAS.Binds, name: string, PrimaryModifier: IAS.supposedKeyCode?, SecondaryModifier: IAS.supposedKeyCode?): boolean
	return setModifiers(binds, name, PrimaryModifier, SecondaryModifier)
end

function BindUtils.ClearModifiers(binds: IAS.Binds, name: string): boolean
	return setModifiers(binds, name, Enum.KeyCode.None, Enum.KeyCode.None)
end

function BindUtils.SetUIButton(binds: IAS.Binds, name: string, button: GuiButton?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.UIButton = button
	return true
end

function BindUtils.SetUIModifier(binds: IAS.Binds, name: string, button: GuiButton?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.UIModifier = button
	return true
end

function BindUtils.SetDisplayName(binds: IAS.Binds, name: string, displayName: string?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.DisplayName = displayName or ""
	return true
end

function BindUtils.SetDisplayImage(binds: IAS.Binds, name: string, displayImage: Content?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.DisplayImage = displayImage
	return true
end

function BindUtils.SetBindingType(binds: IAS.Binds, name: string, bindingType: Enum.InputBindingType?): boolean
	local bind = getBind(binds, name)
	if not bind then return false end
	bind.Type = bindingType or Enum.InputBindingType.Automatic
	return true
end

function BindUtils.ResetBinds(binds: IAS.Binds): boolean
	for name in binds do
		binds[name] = nil
	end

	binds.MainAction = {
		KeyCode = Enum.KeyCode.None,
		PrimaryModifier = Enum.KeyCode.None,
		SecondaryModifier = Enum.KeyCode.None,
		UIButton = nil,
		UIModifier = nil,
		DisplayName = "",
		DisplayImage = nil,
		Type = Enum.InputBindingType.Automatic,
	}

	binds.UIButton = {
		KeyCode = Enum.KeyCode.None,
		PrimaryModifier = Enum.KeyCode.None,
		SecondaryModifier = Enum.KeyCode.None,
		UIButton = nil,
		UIModifier = nil,
		DisplayName = "",
		DisplayImage = nil,
		Type = Enum.InputBindingType.Automatic,
	}

	return true
end

@native function BindUtils.Clone(binds: IAS.Binds): IAS.Binds
	local clone: IAS.Binds = {}

	for name, bind in binds do
		if name == "UIButton" then
			clone[name] = {
				KeyCode = Enum.KeyCode.None,
				PrimaryModifier = Enum.KeyCode.None,
				SecondaryModifier = Enum.KeyCode.None,
				UIButton = bind.UIButton,
				UIModifier = bind.UIModifier,
				DisplayName = bind.DisplayName,
				DisplayImage = bind.DisplayImage,
				Type = bind.Type,
			}
		else
			clone[name] = {
				KeyCode = bind.KeyCode or Enum.KeyCode.None,
				PrimaryModifier = bind.PrimaryModifier or Enum.KeyCode.None,
				SecondaryModifier = bind.SecondaryModifier or Enum.KeyCode.None,
				UIButton = nil,
				UIModifier = nil,
				DisplayName = bind.DisplayName,
				DisplayImage = bind.DisplayImage,
				Type = bind.Type,
			}
		end
	end

	return clone
end

@native function BindUtils.CheckDifferences(base: IAS.Binds, compare: IAS.Binds): (boolean, IAS.Binds?)
	local differences: IAS.Binds = {}
	local hasDifferences = false

	for name, compareBind in compare do
		local baseBind = base[name]

		if not baseBind then
			hasDifferences = true
			differences[name] = {
				KeyCode = compareBind.KeyCode,
				PrimaryModifier = compareBind.PrimaryModifier,
				SecondaryModifier = compareBind.SecondaryModifier,
				UIButton = compareBind.UIButton,
				UIModifier = compareBind.UIModifier,
				DisplayName = compareBind.DisplayName,
				DisplayImage = compareBind.DisplayImage,
				Type = compareBind.Type,
			}
			continue
		end

		local entryDiff = {}

		if name == "UIButton" then
			if baseBind.UIButton ~= compareBind.UIButton then
				entryDiff.UIButton = compareBind.UIButton
			end

			if baseBind.UIModifier ~= compareBind.UIModifier then
				entryDiff.UIModifier = compareBind.UIModifier
			end
		else
			if baseBind.KeyCode ~= compareBind.KeyCode then
				entryDiff.KeyCode = compareBind.KeyCode
			end

			if baseBind.PrimaryModifier ~= compareBind.PrimaryModifier then
				entryDiff.PrimaryModifier = compareBind.PrimaryModifier
			end

			if baseBind.SecondaryModifier ~= compareBind.SecondaryModifier then
				entryDiff.SecondaryModifier = compareBind.SecondaryModifier
			end
		end

		if baseBind.DisplayName ~= compareBind.DisplayName then
			entryDiff.DisplayName = compareBind.DisplayName
		end

		if baseBind.DisplayImage ~= compareBind.DisplayImage then
			entryDiff.DisplayImage = compareBind.DisplayImage
		end

		if baseBind.Type ~= compareBind.Type then
			entryDiff.Type = compareBind.Type
		end

		if next(entryDiff) ~= nil then
			hasDifferences = true
			differences[name] = entryDiff
		end
	end

	for name in base do
		if compare[name] == nil then
			hasDifferences = true
			differences[name] = REMOVED
		end
	end

	if not hasDifferences then
		return true, nil
	end

	return false, differences
end

@native function BindUtils.ApplyDifferences(target: IAS.Binds, differences: IAS.Binds): boolean
	local changed = false

	for name, diff in differences do
		if diff == REMOVED then
			if target[name] ~= nil then
				if name == "MainAction" then
					target.MainAction = {
						KeyCode = Enum.KeyCode.None,
						PrimaryModifier = Enum.KeyCode.None,
						SecondaryModifier = Enum.KeyCode.None,
						UIButton = nil,
						UIModifier = nil,
						DisplayName = "",
						DisplayImage = nil,
						Type = Enum.InputBindingType.Automatic,
					}
				elseif name == "UIButton" then
					target.UIButton = {
						KeyCode = Enum.KeyCode.None,
						PrimaryModifier = Enum.KeyCode.None,
						SecondaryModifier = Enum.KeyCode.None,
						UIButton = nil,
						UIModifier = nil,
						DisplayName = "",
						DisplayImage = nil,
						Type = Enum.InputBindingType.Automatic,
					}
				else
					target[name] = nil
				end
				changed = true
			end
			continue
		end

		if not target[name] then
			target[name] = {
				KeyCode = Enum.KeyCode.None,
				PrimaryModifier = Enum.KeyCode.None,
				SecondaryModifier = Enum.KeyCode.None,
				UIButton = nil,
				UIModifier = nil,
				DisplayName = "",
				DisplayImage = nil,
				Type = Enum.InputBindingType.Automatic,
			}
			changed = true
		end

		local bind = target[name]

		if name == "UIButton" then
			if diff.UIButton ~= nil or diff == differences[name] then
				if bind.UIButton ~= diff.UIButton then
					bind.UIButton = diff.UIButton
					changed = true
				end
			end

			if diff.UIModifier ~= nil or diff == differences[name] then
				if bind.UIModifier ~= diff.UIModifier then
					bind.UIModifier = diff.UIModifier
					changed = true
				end
			end
		else
			if diff.KeyCode ~= nil and bind.KeyCode ~= diff.KeyCode then
				bind.KeyCode = diff.KeyCode
				changed = true
			end

			if diff.PrimaryModifier ~= nil and bind.PrimaryModifier ~= diff.PrimaryModifier then
				bind.PrimaryModifier = diff.PrimaryModifier
				changed = true
			end

			if diff.SecondaryModifier ~= nil and bind.SecondaryModifier ~= diff.SecondaryModifier then
				bind.SecondaryModifier = diff.SecondaryModifier
				changed = true
			end
		end

		if diff.DisplayName ~= nil and bind.DisplayName ~= diff.DisplayName then
			bind.DisplayName = diff.DisplayName
			changed = true
		end

		if diff.DisplayImage ~= nil and bind.DisplayImage ~= diff.DisplayImage then
			bind.DisplayImage = diff.DisplayImage
			changed = true
		end

		if diff.Type ~= nil and bind.Type ~= diff.Type then
			bind.Type = diff.Type
			changed = true
		end
	end

	return changed
end

@native function BindUtils.GetDifference(base: IAS.Binds, differences: IAS.Binds): { IAS.DiffList }
	local results: { IAS.DiffList } = {}

	for bindName, diff in differences do
		local baseBind = base[bindName]

		if diff == REMOVED then
			if baseBind then
				table.insert(results, {
					BindName = bindName,
					ChangeType = if (bindName == "MainAction" or bindName == "UIButton") then "Modified" else "Removed",

					OldKeyCode = baseBind.KeyCode,
					NewKeyCode = Enum.KeyCode.None,

					OldModifiers = {
						PrimaryModifier = baseBind.PrimaryModifier or Enum.KeyCode.None,
						SecondaryModifier = baseBind.SecondaryModifier or Enum.KeyCode.None,
					},

					NewModifiers = {
						PrimaryModifier = Enum.KeyCode.None,
						SecondaryModifier = Enum.KeyCode.None,
					},

					AddedModifiers = {
						PrimaryModifier = Enum.KeyCode.None,
						SecondaryModifier = Enum.KeyCode.None,
					},

					RemovedModifiers = {
						PrimaryModifier = baseBind.PrimaryModifier or Enum.KeyCode.None,
						SecondaryModifier = baseBind.SecondaryModifier or Enum.KeyCode.None,
					},

					UIButton = nil,
					UIModifier = nil,
					DisplayName = "",
					DisplayImage = nil,
					BindingType = Enum.InputBindingType.Automatic,
				})
			end
			continue
		end

		if bindName == "UIButton" then
			table.insert(results, {
				BindName = "UIButton",
				ChangeType = if not baseBind then "Added" else "Modified",

				OldKeyCode = Enum.KeyCode.None,
				NewKeyCode = Enum.KeyCode.None,

				OldModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				NewModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				AddedModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				RemovedModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				UIButton = if diff.UIButton ~= nil then diff.UIButton else (baseBind and baseBind.UIButton),
				UIModifier = if diff.UIModifier ~= nil then diff.UIModifier else (baseBind and baseBind.UIModifier),
				DisplayName = if diff.DisplayName ~= nil then diff.DisplayName else (baseBind and baseBind.DisplayName),
				DisplayImage = if diff.DisplayImage ~= nil then diff.DisplayImage else (baseBind and baseBind.DisplayImage),
				BindingType = if diff.Type ~= nil then diff.Type else (baseBind and baseBind.Type),
			})
			continue
		end

		if not baseBind then
			local pm = diff.PrimaryModifier or Enum.KeyCode.None
			local sm = diff.SecondaryModifier or Enum.KeyCode.None
			table.insert(results, {
				BindName = bindName,
				ChangeType = "Added",

				OldKeyCode = Enum.KeyCode.None,
				NewKeyCode = diff.KeyCode or Enum.KeyCode.None,

				OldModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				NewModifiers = {
					PrimaryModifier = pm,
					SecondaryModifier = sm,
				},

				AddedModifiers = {
					PrimaryModifier = pm,
					SecondaryModifier = sm,
				},

				RemovedModifiers = {
					PrimaryModifier = Enum.KeyCode.None,
					SecondaryModifier = Enum.KeyCode.None,
				},

				UIButton = nil,
				UIModifier = nil,
				DisplayName = diff.DisplayName,
				DisplayImage = diff.DisplayImage,
				BindingType = diff.Type or Enum.InputBindingType.Automatic,
			})
			continue
		end

		local oldPM = baseBind.PrimaryModifier or Enum.KeyCode.None
		local oldSM = baseBind.SecondaryModifier or Enum.KeyCode.None
		local newPM = if diff.PrimaryModifier ~= nil then diff.PrimaryModifier else oldPM
		local newSM = if diff.SecondaryModifier ~= nil then diff.SecondaryModifier else oldSM

		local addedPM = Enum.KeyCode.None
		local addedSM = Enum.KeyCode.None
		local removedPM = Enum.KeyCode.None
		local removedSM = Enum.KeyCode.None

		if oldPM ~= newPM then
			if newPM ~= Enum.KeyCode.None then
				addedPM = newPM
			end
			if oldPM ~= Enum.KeyCode.None then
				removedPM = oldPM
			end
		end

		if oldSM ~= newSM then
			if newSM ~= Enum.KeyCode.None then
				addedSM = newSM
			end
			if oldSM ~= Enum.KeyCode.None then
				removedSM = oldSM
			end
		end

		table.insert(results, {
			BindName = bindName,
			ChangeType = "Modified",

			OldKeyCode = baseBind.KeyCode,
			NewKeyCode = if diff.KeyCode ~= nil then diff.KeyCode else baseBind.KeyCode,

			OldModifiers = {
				PrimaryModifier = oldPM,
				SecondaryModifier = oldSM,
			},

			NewModifiers = {
				PrimaryModifier = newPM,
				SecondaryModifier = newSM,
			},

			AddedModifiers = {
				PrimaryModifier = addedPM,
				SecondaryModifier = addedSM,
			},

			RemovedModifiers = {
				PrimaryModifier = removedPM,
				SecondaryModifier = removedSM,
			},

			UIButton = nil,
			UIModifier = nil,
			DisplayName = if diff.DisplayName ~= nil then diff.DisplayName else baseBind.DisplayName,
			DisplayImage = if diff.DisplayImage ~= nil then diff.DisplayImage else baseBind.DisplayImage,
			BindingType = if diff.Type ~= nil then diff.Type else baseBind.Type,
		})
	end

	return results
end

return BindUtils
