local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

--Modules
local Binds = require(ReplicatedStorage.Shared.Binds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local fusion = require(ReplicatedStorage.Packages.fusion)
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

local InventoryGui = Player.PlayerGui:FindFirstChild("Stoway") :: ScreenGui
local BackpackFrame = InventoryGui.Backpack :: Frame
local HotbarFrame = InventoryGui.Hotbar :: Frame
local ScrollingBackpack = BackpackFrame.ScrollingFrame :: ScrollingFrame


local stowayclient = {}


local scoped = fusion.scoped 
local peek = fusion.peek


--//HelperFuncs\\--
function stowayclient.ToggleBackpack(actionName, inputState, inputObject)
    if inputState and inputState ~= Enum.UserInputState.Begin then return end
    BackpackFrame.Visible = not BackpackFrame.Visible 
end

function stowayclient.GetToolData(toolInstance: Tool): Types.ItemData?
    if not toolInstance:IsA("Tool") or not toolInstance:GetAttribute("ItemType") then
        return nil
    end

    -- Ensure Amount attribute is a number, default to 1 if not present or not a number
    local amountAttribute = toolInstance:GetAttribute("Weight") -- Using "Weight" as per your GetToolData
    local initialAmount = math.max(1, amountAttribute) -- Ensure amount is at least 1
    

    local itemData = {
        ID = toolInstance:GetAttribute("Id"),
        Description = toolInstance.ToolTip or "No description.",
        Image = toolInstance.TextureId or "",
        Amount = initialAmount,
        IsGamepass = toolInstance:GetAttribute("IsGamepass") or false,
        Rarity = toolInstance:GetAttribute("Rarity"),
        Droppable = toolInstance:GetAttribute("Droppable") or Settings.Droppable, -- Default to global setting
        Type = toolInstance:GetAttribute("ItemType") :: string,
    } :: Types.ItemData

    return itemData
end


--//Setup Function\\--
function stowayclient.new()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    BackpackFrame.Visible = false

    local stowayresult = GetStowayFromServer:InvokeServer("stoway") :: Types.Stoway
    if stowayresult then
        inventoryFolder = stowayresult.InventoryFolder
        BackpackFolder = stowayresult.BackpackFolder
        HotbarFolder = stowayresult.HotBarFolder
        if stowayresult.Settings then Settings = stowayresult.Settings end
    end

    stowayclient.CreateHotBarFrames()
end

--//Core Helper Functions\\--
function stowayclient.SetSlotFrameHidden(SlotFrame)
    if not SlotFrame then return end

    SlotFrame.slotbutton.Visible = false
    SlotFrame.stackcount.Visible = false
    SlotFrame.rarityframe.Visible = false
end

function stowayclient.SetSlotFrameVisible(SlotFrame)
    if not SlotFrame then return end

    SlotFrame.slotbutton.Visible = true
    SlotFrame.stackcount.Visible = true
end

function stowayclient.UpdateSlotFrame(slotframe, tool:Tool) : any
    if not tool then return stowayclient.SetSlotFrameHidden(slotframe) end
    local data = stowayclient.GetToolData(tool)
    print(data.Rarity, data.Amount)

    slotframe.stackcount.Text = tonumber(data.Amount) > 1 and data.Amount .. "x" or data.Amount -- 1 stack count doesnt end wit "x"
    slotframe.slotbutton.Image = data.Image
    
    if Settings.RarityCheck then slotframe.rarityframe.Visible = true; slotframe.rarityframe.BackgroundColor3 = RarityValues[data.Rarity] end
    return stowayclient.SetSlotFrameVisible(slotframe)
end

function stowayclient.CreateSlotFrameName(slotnumber:number): string
    local numberstring = tostring(slotnumber) :: string
    local slotframeName = ""
    local len = numberstring:len()

    if len > 1 then
        for i=1, (len - 1) do
            slotframeName ..= "_"
        end
    end

    slotframeName..= numberstring

    return slotframeName
end

function stowayclient.getKeyName(Keybinds, slotnumber)
	if not Keybinds or slotnumber == nil then
		return -- nil, as per original behavior for missing inputs
	end
    if slotnumber == 10 then slotnumber = 0 end

	local slotKey = tostring(slotnumber)
	local keyCodeEnumList = Keybinds[slotKey]

	-- Check if the slot exists and has any keycodes
	if not keyCodeEnumList or (type(keyCodeEnumList) == "table" and #keyCodeEnumList == 0) then
		return -- nil, if slot not found or the list of keycodes is empty
	end

	local formattedKeyNames = {}
	table.insert(formattedKeyNames, "[".. slotnumber .. "]")
	for i=2, #keyCodeEnumList do
		local nameParts = string.split(tostring(keyCodeEnumList[i]), ".")
		local keyName = nameParts[3] -- Extracts "F" from "Enum.KeyCode.F"
		table.insert(formattedKeyNames, "[" .. keyName .. "]")
	end

	-- If, after processing, the list is somehow empty (e.g., malformed input not caught by basic checks, though unlikely with assumptions)
	if #formattedKeyNames == 0 then
		return -- nil
	end

	return table.concat(formattedKeyNames, "/")
end

function stowayclient.CreateSlotFrame(slotvalue:ObjectValue)
    local tool = slotvalue.Value :: Tool
    local slotnumber = tonumber(slotvalue.Name)
    local newslotframe = slotbuttontemplate:Clone()
    newslotframe.Name = stowayclient.CreateSlotFrameName(slotnumber)

    local keybindDisplay = nil
    if slotvalue.Parent == HotbarFolder then
        keybindDisplay = stowayclient.getKeyName(Binds.KeyBinds, slotnumber)
    end

    if keybindDisplay then
        newslotframe.slotnumber.Text = keybindDisplay
    else
        newslotframe.slotnumber.Visible = false
    end

    stowayclient.UpdateSlotFrame(newslotframe, tool)
    slotvalue.Destroying:Connect(function()
        newslotframe:Destroy()
    end)
    slotvalue:GetPropertyChangedSignal("Value"):Connect(function()
        local newtool = slotvalue.Value  
        if slotvalue.Parent == BackpackFolder and not newtool then
            newslotframe:Destroy()
            return
        end
        stowayclient.UpdateSlotFrame(newslotframe, newtool)
    end)

    return newslotframe
end

function stowayclient.CreateHotBarFrames()
    for i=1, Settings.HotbarSettings.MaxSlots do
        local hotbarvalue = HotbarFolder[i]
        local slotframe = stowayclient.CreateSlotFrame(hotbarvalue)
        slotframe.Parent = HotbarFrame
    end 
end

stowayclient.new()
ContextActionService:BindAction("toggle_backpack", stowayclient.ToggleBackpack, false, unpack(Binds.BackpackBinds))

return stowayclient