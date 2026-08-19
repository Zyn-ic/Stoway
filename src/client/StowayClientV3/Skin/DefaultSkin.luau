--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Resolves the active UiSkin prefab from ReplicatedStorage.Stoway.GUI.
	Prefab contract:
		ReplicatedStorage.Stoway.GUI.<SkinName>/
			StowayGui (Folder)
				Stoway (ScreenGui)  → cloned into PlayerGui
					Hotbar (Frame)      → slot container (UIListLayout, horizontal)
					Backpack (Frame)    → storage container
						ScrollingFrame   → group containers (UIListLayout, vertical)
						Weight (TextLabel)
						SearchFilter (TextBox)
					BackpackStuff (ImageButton)
				Slot (Folder)       → slot prefab
					template (Frame) → slotbutton, stackcount, slotnumber,
					                   selecticon, rarityframe
	Returns nil (with a warning) when the folder is missing — e.g. a rojo
	build without an exported GUI.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultSkin = {}

-----------------------------
-- TYPES --
-----------------------------

export type Skin = {
	Gui: ScreenGui?,
	HotbarFrame: Frame?,
	BackpackFrame: Frame?,
	ScrollingFrame: ScrollingFrame?,
	WeightLabel: TextLabel?,
	SearchFilter: TextBox?,
	BackpackStuff: ImageButton?,
	SlotTemplate: Frame?,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function DefaultSkin.load(playerGui: PlayerGui, skinName: string): DefaultSkin.Skin?
	local stowayGui = ReplicatedStorage:FindFirstChild("Stoway")
		and ReplicatedStorage.Stoway:FindFirstChild("GUI")

	local skinFolder = stowayGui and stowayGui:FindFirstChild(skinName)
	if not skinFolder then
		warn(`[StowayClientV3] skin '{skinName}' not found in {stowayGui and stowayGui:GetFullName() or "ReplicatedStorage.Stoway.GUI"}`)
		return nil
	end

	-- v1.2 layout nests the gui inside a StowayGui folder.
	local root = skinFolder:FindFirstChild("StowayGui") or skinFolder
	local guiTemplate = root:FindFirstChild("Stoway") :: ScreenGui?
	if not guiTemplate then
		warn(`[StowayClientV3] skin '{skinName}' has no Stoway ScreenGui`)
		return nil
	end

	local gui = guiTemplate:Clone()
	gui.Parent = playerGui

	local backpack = gui:FindFirstChild("Backpack") :: Frame?
	local slotFolder = root:FindFirstChild("Slot")

	return {
		Gui = gui,
		HotbarFrame = gui:FindFirstChild("Hotbar") :: Frame?,
		BackpackFrame = backpack,
		ScrollingFrame = backpack and backpack:FindFirstChild("ScrollingFrame") :: ScrollingFrame?,
		WeightLabel = backpack and backpack:FindFirstChild("Weight") :: TextLabel?,
		SearchFilter = backpack and backpack:FindFirstChild("SearchFilter") :: TextBox?,
		BackpackStuff = gui:FindFirstChild("BackpackStuff") :: ImageButton?,
		SlotTemplate = slotFolder and slotFolder:FindFirstChild("template") :: Frame?,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return DefaultSkin