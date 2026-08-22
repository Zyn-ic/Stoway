--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Loads the DefaultModern skin. Clones the Stoway ScreenGui and returns
	handles to its frames for the layout.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local DefaultModern = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Loads the skin GUI onto the given scope.
function DefaultModern.Load(scope: Fusion.Scope<any>, playerGui: PlayerGui, skinAssetName: string): CoreTypes.SkinHandle?
	local guiRoot = ReplicatedStorage:FindFirstChild("Stoway")
	local guiFolder = guiRoot and guiRoot:FindFirstChild("GUI")
	local skinFolder = guiFolder and guiFolder:FindFirstChild(skinAssetName)

	if not skinFolder then
		warn(`[DefaultModern] skin asset '{skinAssetName}' not found at ReplicatedStorage.Stoway.GUI`)
		return nil
	end

	local root = skinFolder:FindFirstChild("StowayGui") or skinFolder
	local guiTemplate = root:FindFirstChild("Stoway") :: ScreenGui?
	if not guiTemplate then
		warn(`[DefaultModern] skin asset '{skinAssetName}' has no Stoway ScreenGui`)
		return nil
	end

	local gui = guiTemplate:Clone()
	gui.Parent = playerGui
	table.insert(scope, gui)

	local backpack = gui:FindFirstChild("Backpack") :: Frame?
	local slotFolder = root:FindFirstChild("Slot")

	-- Ensure a dedicated DraggingGui for spring ghost – create if prefab lacks it
	local draggingGui = gui:FindFirstChild("DraggingGui") :: ScreenGui?
	if not draggingGui then
		draggingGui = Instance.new("ScreenGui")
		draggingGui.Name = "DraggingGui"
		draggingGui.DisplayOrder = 100
		draggingGui.IgnoreGuiInset = false
		draggingGui.ResetOnSpawn = false
		draggingGui.Parent = playerGui
		table.insert(scope, draggingGui)
	else
		draggingGui.IgnoreGuiInset = false
		if draggingGui.Parent ~= playerGui then draggingGui.Parent = playerGui end
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
	}
end

-----------------------------
-- MAIN --
-----------------------------

return DefaultModern
