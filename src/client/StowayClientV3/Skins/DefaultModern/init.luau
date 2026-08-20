--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	UiSkin loader for the StandardHotbarStorage layout. Resolves an asset
	folder at ReplicatedStorage.Stoway.GUI.<skinAssetName>, clones its Stoway
	ScreenGui into the player's PlayerGui, and returns a SkinHandle pointing
	at the named pieces StandardHotbarStorage's views expect.

	Prefab contract (matches the GUI already placed under
	ReplicatedStorage.Stoway.GUI.Default in this project):

		ReplicatedStorage.Stoway.GUI.<skinAssetName>/
			StowayGui (Folder)
				Stoway (ScreenGui)      -> cloned into PlayerGui
					Hotbar (Frame)         -> slot container (UIListLayout, horizontal)
					Backpack (Frame)       -> storage container
						ScrollingFrame (ScrollingFrame) -> group containers' parent
						Weight (TextLabel)
						SearchFilter (TextBox)
					BackpackStuff (ImageButton)
				Slot (Folder)            -> slot prefab
					template (Frame)         -> slotbutton, stackcount, slotnumber,
					                            selecticon, rarityframe

	Any UiSkin swapped in for this same layout (DarkModern, FantasyWood, ...)
	must satisfy this same contract under its own GUI.<name> folder — only
	the visuals inside change, never the names the views look up.

	Returns nil (with a warning) if the asset or a required piece is
	missing — e.g. a build without the GUI folder exported/synced yet.
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

-- scope: the LayoutScope owning this mount. The cloned ScreenGui is
-- registered on it, so LayoutManager tearing down the layout also destroys
-- the GUI instance — no separate cleanup path needed.
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

	return {
		Gui = gui,
		HotbarFrame = gui:FindFirstChild("Hotbar") :: Frame?,
		BackpackFrame = backpack,
		ScrollingFrame = backpack and (backpack:FindFirstChild("ScrollingFrame") :: ScrollingFrame?),
		WeightLabel = backpack and (backpack:FindFirstChild("Weight") :: TextLabel?),
		SearchFilter = backpack and (backpack:FindFirstChild("SearchFilter") :: TextBox?),
		BackpackStuff = gui:FindFirstChild("BackpackStuff") :: ImageButton?,
		SlotTemplate = slotFolder and (slotFolder:FindFirstChild("template") :: Frame?),
	}
end

-----------------------------
-- MAIN --
-----------------------------

return DefaultModern
