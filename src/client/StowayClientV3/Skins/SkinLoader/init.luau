--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Generic skin loader. Clones the named skin folder's single ScreenGui
	and returns handles to its frames for the layout. Per-skin modules
	(Default, Modern, Metal) re-export this; the UiSkin key IS the
	ReplicatedStorage.Stoway.GUI asset folder, so a key can only ever
	mount its own GUI.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local SkinLoader = {}

-- Parse a comma-separated Studio attribute into a name list. Non-strings
-- and empties resolve to nil (caller falls back to built-in defaults).
local function parseNameList(value: unknown): { string }?
	if typeof(value) ~= "string" then return nil end
	local names: { string } = {}
	for part in string.gmatch(value, "[^,]+") do
		local trimmed = string.match(part, "^%s*(.-)%s*$") or ""
		if trimmed ~= "" then table.insert(names, trimmed) end
	end
	if #names == 0 then return nil end
	return names
end

local function parseBleedPx(value: unknown): number?
	if typeof(value) == "number" then return value end
	return nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Loads the skin GUI onto the given scope.
function SkinLoader.Load(scope: Fusion.Scope<typeof(Fusion)>, playerGui: PlayerGui, skinAssetName: string): CoreTypes.SkinHandle?
	local guiRoot = ReplicatedStorage:FindFirstChild("Stoway")
	local guiFolder = guiRoot and guiRoot:FindFirstChild("GUI")
	local skinFolder = guiFolder and guiFolder:FindFirstChild(skinAssetName)

	if not skinFolder then
		warn(`[SkinLoader] skin asset '{skinAssetName}' not found at ReplicatedStorage.Stoway.GUI`)
		return nil
	end

	-- Flat shape only: exactly one ScreenGui directly under the skin folder.
	local guiTemplate: ScreenGui? = nil
	local guiCount = 0
	for _, child in skinFolder:GetChildren() do
		if child:IsA("ScreenGui") then
			guiCount += 1
			guiTemplate = child
		end
	end
	if not guiTemplate then
		warn(`[SkinLoader] skin asset '{skinAssetName}' must contain exactly one ScreenGui (found {guiCount})`)
		return nil
	end
	if guiCount ~= 1 then
		warn(`[SkinLoader] skin asset '{skinAssetName}' must contain exactly one ScreenGui (found {guiCount})`)
		return nil
	end

	-- Skin hook adapter (Layer 2): require the HookFuncs ModuleScript
	-- from the skin folder when present. Absent/failed = nil hooks and
	-- everything still works (absent = legacy, same rule as slot attrs).
	-- Validated against the 11-name contract; unknown entries warn.
	local hookFuncs: CoreTypes.HookMap? = nil
	local hookFolder = skinFolder:FindFirstChild("HookFuncs")
	if hookFolder then
		local hookModule: ModuleScript? = nil
		for _, child in hookFolder:GetChildren() do
			if child:IsA("ModuleScript") then
				hookModule = child
				break
			end
		end
		if hookModule then
			local ok, required = pcall(require, hookModule)
			if ok and typeof(required) == "table" then
				local validated: CoreTypes.HookMap = required :: CoreTypes.HookMap
				for name, fn in validated do
					if typeof(fn) ~= "function" then
						warn(`[SkinLoader] hook '{name}' in '{skinAssetName}' is not a function, ignoring`)
						validated[name] = nil
					end
				end
				hookFuncs = validated
			else
				warn(`[SkinLoader] HookFuncs in '{skinAssetName}' failed to require: {tostring(required)}`)
			end
		end
	end

	local gui = guiTemplate:Clone() :: ScreenGui
	gui.Parent = playerGui
	table.insert(scope, gui)

	local backpack = gui:FindFirstChild("Backpack") :: Frame?
	local slotFolder = skinFolder:FindFirstChild("Slot")
	local selectionCursor = slotFolder and (slotFolder:FindFirstChild("SelectionCursor") :: GuiObject?)

	-- Optional per-skin declarations on the Slot folder (absent = defaults).
	local ghostHidden: { string }? = if slotFolder then parseNameList(slotFolder:GetAttribute("GhostHidden")) else nil
	local hideInStorage: { string }? = if slotFolder then parseNameList(slotFolder:GetAttribute("HideInStorage")) else nil
	local hideInHotbar: { string }? = if slotFolder then parseNameList(slotFolder:GetAttribute("HideInHotbar")) else nil
	local slotBleedPx: number? = if slotFolder then parseBleedPx(slotFolder:GetAttribute("SlotBleedPx")) else nil

	-- Single shared DraggingGui: prefer the live one already in PlayerGui.
	-- The folder lookup alone misses it (it moved out on first mount), which
	-- used to strand the template in PlayerGui and clone a duplicate on
	-- every skin switch. Adopt it, destroy any extras, else fall back to the
	-- folder template (moved, never scope-owned — it is shared), else create
	-- scope-owned as a last resort.
	local existingDragging = playerGui:FindFirstChild("DraggingGui") :: ScreenGui?
	if existingDragging == nil then
		existingDragging = guiFolder and (guiFolder:FindFirstChild("DraggingGui") :: ScreenGui?)
	end
	local draggingGui: ScreenGui
	if existingDragging then
		existingDragging.IgnoreGuiInset = false
		if existingDragging.Parent ~= playerGui then existingDragging.Parent = playerGui end
		draggingGui = existingDragging
	else
		local created = Instance.new("ScreenGui")
		created.Name = "DraggingGui"
		created.DisplayOrder = 100
		created.IgnoreGuiInset = false
		created.ResetOnSpawn = false
		created.Parent = playerGui
		table.insert(scope, created)
		draggingGui = created
	end
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name == "DraggingGui" and child ~= draggingGui then
			child:Destroy()
		end
	end

	return {
		Gui = gui,
		HotbarFrame = gui:FindFirstChild("Hotbar") :: Frame?,
		BackpackFrame = backpack,
		ScrollingFrame = backpack and (backpack:FindFirstChild("ScrollingFrame") :: ScrollingFrame?),
		WeightLabel = backpack and (backpack:FindFirstChild("Weight") :: TextLabel?),
		SearchFilter = backpack and (backpack:FindFirstChild("SearchFilter") :: TextBox?),
		BackpackStuff = gui:FindFirstChild("BackpackStuff") :: ImageButton?,
		SlotTemplate = slotFolder and (slotFolder:FindFirstChild("template") :: Frame?),
		DraggingGui = draggingGui,
		SelectionCursorTemplate = selectionCursor,
		GhostHidden = ghostHidden,
		HideInStorage = hideInStorage,
		HideInHotbar = hideInHotbar,
		SlotBleedPx = slotBleedPx,
		Hooks = hookFuncs,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return SkinLoader
