--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Loads the DefaultModern skin. Clones the skin folder's single ScreenGui
	and returns handles to its frames for the layout.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local DefaultModern = {}

-- Parse a comma-separated Studio attribute into a name list. Non-strings
-- and empties resolve to nil (caller falls back to built-in defaults).
local function parseNameList(value: any): { string }?
	if typeof(value) ~= "string" then return nil end
	local names: { string } = {}
	for part in string.gmatch(value, "[^,]+") do
		local trimmed = string.match(part, "^%s*(.-)%s*$") or ""
		if trimmed ~= "" then table.insert(names, trimmed) end
	end
	if #names == 0 then return nil end
	return names
end

local function parseBleedPx(value: any): number?
	if typeof(value) == "number" then return value end
	return nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Loads the skin GUI onto the given scope.
function DefaultModern.Load(scope: Fusion.Scope<typeof(Fusion)>, playerGui: PlayerGui, skinAssetName: string): CoreTypes.SkinHandle?
	local guiRoot = ReplicatedStorage:FindFirstChild("Stoway")
	local guiFolder = guiRoot and guiRoot:FindFirstChild("GUI")
	local skinFolder = guiFolder and guiFolder:FindFirstChild(skinAssetName)

	if not skinFolder then
		warn(`[DefaultModern] skin asset '{skinAssetName}' not found at ReplicatedStorage.Stoway.GUI`)
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
		warn(`[DefaultModern] skin asset '{skinAssetName}' must contain exactly one ScreenGui (found {guiCount})`)
		return nil
	end
	if guiCount ~= 1 then
		warn(`[DefaultModern] skin asset '{skinAssetName}' must contain exactly one ScreenGui (found {guiCount})`)
		return nil
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

	-- Single shared DraggingGui at the GUI root; create as a last resort.
	local existingDragging = guiFolder and (guiFolder:FindFirstChild("DraggingGui") :: ScreenGui?)
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
	}
end

-----------------------------
-- MAIN --
-----------------------------

return DefaultModern
