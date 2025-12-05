-- src/client/StowayClientV2/ClientInventoryService.luau
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

--modules
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Binds = require(ReplicatedStorage.Shared.Binds)
local Types = require(ReplicatedStorage.Shared.Types)
local RarityValues = require(ReplicatedStorage.Shared.RarityValues)

-- RemoteEvents
local dropTool = ReplicatedStorage:WaitForChild("Remotes").DropTool :: RemoteEvent
local equipTool = ReplicatedStorage:WaitForChild("Remotes").EquipTool :: RemoteEvent
local unequipTool = ReplicatedStorage:WaitForChild("Remotes").UnEquipTool :: RemoteEvent
local swapSlots = ReplicatedStorage:WaitForChild("Remotes").SwapSlots :: RemoteEvent
local movetoendofback = ReplicatedStorage:WaitForChild("Remotes").MoveToEndofBackpack :: RemoteEvent


-- BindableEvents
local GetStowayFromServer = ReplicatedStorage:WaitForChild("Remotes").AskForStoway :: RemoteFunction

-- Others
local guis = ReplicatedStorage:WaitForChild("Gui") :: Folder
local slotbuttontemplate = guis.Slot.template :: Frame
local Player = Players.LocalPlayer :: Player
local Character = Player.Character or Player.CharacterAdded:Wait() :: Model
local inventoryFolder : Folder
local BackpackFolder : Folder
local HotbarFolder : Folder

local Settings : Types.Settings

local InventoryGui = Player.PlayerGui:FindFirstChild("StowayGui").Stoway :: ScreenGui
local DraggingGui = Player.PlayerGui:FindFirstChild("StowayGui").DraggingGui :: ScreenGui
local BackpackFrame = InventoryGui.Backpack :: Frame
local HotbarFrame = InventoryGui.Hotbar :: Frame
local ScrollingBackpack = BackpackFrame.ScrollingFrame :: ScrollingFrame
local WeightLabel = BackpackFrame.Weight :: TextLabel

-- Constants
local scoped = Fusion.scoped
local peek = Fusion.peek

local Scope = scoped(Fusion)

local EquippedSlot = Scope:Value(nil)
local Backpack = Scope:Value({})
local Hotbar = Scope:Value({})
local DragState = Scope:Value({} :: Types.DragStateTable) 


local ClientInventoryService = {}

function ClientInventoryService.BindKeyBinds(actionNamePrefix, slotfolder)
	-- Loop from 1 up to the max number of slots defined in settings.
	for i = 1, Settings.HotbarSettings.MaxSlots do
		-- Get the bind data for the current slot index from our ordered array.
		local bindData = Binds.KeyBinds[i]
		
		-- If we have more slots than defined keybinds, stop.
		if not bindData then
			break
		end

		-- The slot in the HotbarFolder is now directly referenced by the loop index 'i'.
		local slotNumberString = tostring(i)

		local function EquipThisSlot(actionName, inputState, inputObject)
			if inputState ~= Enum.UserInputState.Begin then return end

			local slotValue = slotfolder:FindFirstChild(slotNumberString)
			if not slotValue or not slotValue.Value then
				unequipTool:FireServer()
				return
			end
			--stowayclient.EquipUnequipTool(slotValue)
		end

		-- Create a unique action name for each slot.
		local actionName = actionNamePrefix .. slotNumberString
		ContextActionService:BindAction(actionName, EquipThisSlot, false, unpack(bindData.Keys))
	end
end

function ClientInventoryService.Init()
	print("ClientInventoryService Initialized")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end

return ClientInventoryService
