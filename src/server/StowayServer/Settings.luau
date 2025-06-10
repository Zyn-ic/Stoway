local Settings = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local HotbarTypes = Types.HotbarType
local CarryingTypes = Types.CarryingType

Settings.HotbarSettings = {}
Settings.BackpackSettings = {}

--// Hotbar section

-- static means the hotbar will not change and will have 9 slost visible
-- dynamic means slots will only be visible when the slots arent empty
Settings.HotbarSettings.HotbarType = HotbarTypes.Static

-- the maximum amount of slots you can have on your hotbar
Settings.HotbarSettings.MaxSlots = 10

--// Backpack section

-- this is determine if you want a backpack system or a inventory system
--backpack system will store all tools in the roblox's backpack instance
--inventory system will store hotbar tools in roblox's backpack instance and all other items will be stored as data on the server
Settings.BackpackSettings.CarryingType = CarryingTypes.Backpack

--lets you set a limit for the backpack 0 means inf
Settings.BackpackSettings.Limit = 15
Settings.BackpackSettings.Sorting = false

--// settings section

-- these functions will run when someone selects a slot in backpack/inv or hotbar
-- and presses a key
-- if you want nothing to happen then just remove the placeholder function
Settings.Bindkey = {
	[tostring(Enum.KeyCode.Delete)] = function(...)
		return print("you pressed delete on slot") -- placeholder
	end,
}

-- This function will run once you select a slot in hotbar or backpack/inv
-- should be used for cometics/visuals like tweening button
Settings.BindFunction = function(...) end

Settings.CanStack = true
Settings.MaxStackCount = 5

-- this setting will allow the code to check for rarity attribute on a tool
Settings.RarityCheck = true

-- this setting will allow the code to drop an item if it is in a drop frame
Settings.Droppable = true

-- this setting will allow the code to save all items in your hotbar so if gun is in slot1 when you die/rejoin gun will be in slot1
--it will also save all items in your backpack or if you had a sword in your backpack if you die/rejoin sword will be in your backpack
-- will also work if you only have your hotbar like say you set CarryingType to inventory or hotback it will save the items in your hotbar
Settings.SaveBackpackandSlotInfo = false

Settings.DropToolDistance = 5
return Settings
