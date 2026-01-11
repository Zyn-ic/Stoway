local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local InventoryController = require(script.Parent.Parent.Operations.InventoryController)
local fusion = require(ReplicatedStorage.Packages.fusion)
--local Settings = require(ReplicatedStorage.Shared.Settings)

local peek = fusion.peek

local DragHandler = {}
local CloneForGhost = nil

local DragState = {
	isDragging = false,
	enabled = false,
	sourceType = nil,
	sourceSlot = nil,
	originalFrame = nil,
	ghostFrame = nil,
}

local DragThreshold = 5

local dragConnection = nil
local releaseConnection = nil
local checkConnection = nil

local DraggingGui = nil
local HotbarFrame = nil
local BackpackFrame = nil
local hookManager = nil

--// Utility: GUI-space mouse position (FIXES OFFSET)
local function GetGuiMousePosition(): Vector2
	local mousePos = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	return Vector2.new(mousePos.X - inset.X, mousePos.Y - inset.Y)
end

--// Initialize
function DragHandler.Init(draggingGui: ScreenGui, hotbar: Frame, backpack: Frame, hooks: any?, _CloneForGhost)
	DraggingGui = draggingGui
	HotbarFrame = hotbar
	BackpackFrame = backpack
	hookManager = hooks
	CloneForGhost = _CloneForGhost
end


function DragHandler.GetDragState() : {isDragging : boolean,sourceType :any ,sourceSlot : any,originalFrame : any, ghostFrame : any}
	return DragState
end

function DragHandler.SetEnabled(state: boolean)
	DragState.enabled = state
	if not state and DragState.isDragging then
		DragHandler.Destroy()
	end
end

--// Start drag
function DragHandler.StartDrag(slotType: string, slotIndex: number, originalFrame: Frame, FullData--[[, Scope]])
    if not DragState.enabled then return end
    if DragState.isDragging then return end

	-- Validate slot has item
	local uuid
	if slotType == "Hotbar" then
		uuid = peek(FullData).Hotbar[slotIndex]
	else
		uuid = peek(FullData).Storage[slotIndex]
	end

	if not uuid then return end

	local items = peek(FullData).Items
	if not items[uuid] then return end

    DragState.originalFrame = originalFrame
    DragState.sourceType = slotType
    DragState.sourceSlot = slotIndex

    -- Store the starting position to check threshold
    local startPosition = GetGuiMousePosition()

    -- Clone ghost immediately but don't parent yet
    local ghost = CloneForGhost(originalFrame)

    checkConnection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local currentPosition = GetGuiMousePosition()
        local distance = (currentPosition - startPosition).Magnitude

        if distance >= DragThreshold then
            if checkConnection then
                checkConnection:Disconnect()
                checkConnection = nil
            end
            -- Pass the current position to init the ghost
            DragHandler.CreateGhost(originalFrame, currentPosition, ghost)
        end
    end)

    releaseConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
             DragHandler.EndDrag(--[[, Scope]])
        end
    end)
end

--// Create ghost frame for dragging
function DragHandler.CreateGhost(originalFrame: Frame, currentMousePos: Vector2, ghost: Frame)
    if not DraggingGui then return end
    if DragState.ghostFrame then return end

    DragState.isDragging = true

    local screenSize = DraggingGui.AbsoluteSize
    local frameSize = originalFrame.AbsoluteSize
    local framePos = originalFrame.AbsolutePosition

    -- 1. CALCULATE OFFSET: How far is the mouse from the top-left of the button?
    -- We use currentMousePos (where the mouse is NOW) vs the Frame's static position
    DragState.mouseOffset = currentMousePos - framePos

    -- 2. SETUP GHOST SIZE
    ghost.Size = UDim2.fromScale(frameSize.X / screenSize.X, frameSize.Y / screenSize.Y)
    ghost.AnchorPoint = Vector2.new(0, 0) -- Ensure AnchorPoint is TopLeft for this math to work

    -- 3. INITIAL POSITION
    -- Target Pixel X = Mouse X - Offset X
    local targetX = currentMousePos.X - DragState.mouseOffset.X
    local targetY = currentMousePos.Y - DragState.mouseOffset.Y

    ghost.Position = UDim2.fromScale(targetX / screenSize.X, targetY / screenSize.Y)
    ghost.Parent = DraggingGui

    DragState.ghostFrame = ghost

    DragHandler.HideOriginalVisuals()

    if hookManager then
        hookManager:Fire("OnDragStart", DragState.sourceType, DragState.sourceSlot)
    end

    -- 4. UPDATE LOOP (RunService is smoother than InputChanged for dragging)
    dragConnection = RunService.RenderStepped:Connect(function()
        if not DragState.ghostFrame then
            DragHandler.EndDrag()
            return
        end

        local mousePos = GetGuiMousePosition()
        local scrSize = DraggingGui.AbsoluteSize

        -- Apply the offset we calculated earlier
        local newX = mousePos.X - DragState.mouseOffset.X
        local newY = mousePos.Y - DragState.mouseOffset.Y

        DragState.ghostFrame.Position = UDim2.fromScale(
            newX / scrSize.X,
            newY / scrSize.Y
        )
    end)
end

--// Hide visuals
function DragHandler.HideOriginalVisuals()
	local frame = DragState.originalFrame
	if not frame then return end

	-- if Settings.Hotbar.Type == "Dynamic" then frame.Visible = false end -- Need access to settings for this?
	-- For now keeping it simple as before
	frame.BackgroundTransparency = 0.95

	local function fade(obj, prop, value)
		if obj then obj[prop] = value end
	end

	if DragState.originalFrame:IsA("ImageLabel") then
		fade(frame:FindFirstChild("slotbutton"), "ImageTransparency", 1)
		fade(frame:FindFirstChild("slotbutton"), "BackgroundTransparency", 1)
		fade(frame:FindFirstChild("stackcount"), "TextTransparency", 0.7)
		fade(frame:FindFirstChild("selecticon"), "ImageTransparency", 1)
		fade(frame:FindFirstChild("rarityframe"), "ImageTransparency", 1)
	end

	fade(frame:FindFirstChild("slotbutton"), "ImageTransparency", 1)
	fade(frame:FindFirstChild("slotbutton"), "BackgroundTransparency", 1)
	fade(frame:FindFirstChild("stackcount"), "TextTransparency", 0.7)
	fade(frame:FindFirstChild("selecticon"), "ImageTransparency", 1)
	fade(frame:FindFirstChild("rarityframe"), "BackgroundTransparency", 1)
end

--// Restore visuals
function DragHandler.RestoreOriginalVisuals()
	local frame = DragState.originalFrame
	if not frame then return end

	-- if Settings.Hotbar.Type == "Dynamic" then frame.Visible = true end
	frame.BackgroundTransparency = 0.8

	local function restore(obj, prop, value)
		if obj then obj[prop] = value end
	end

	if DragState.originalFrame:IsA("Frame") then
		restore(frame:FindFirstChild("slotbutton"), "ImageTransparency", 0)
		restore(frame:FindFirstChild("slotbutton"), "BackgroundTransparency", 0)
		restore(frame:FindFirstChild("stackcount"), "TextTransparency", 0)
		restore(frame:FindFirstChild("selecticon"), "ImageTransparency", 0)
		restore(frame:FindFirstChild("rarityframe"), "BackgroundTransparency", 1)
	end

	if DragState.originalFrame:IsA("ImageLabel") then
		restore(frame:FindFirstChild("slotbutton"), "ImageTransparency", 0)
		restore(frame:FindFirstChild("stackcount"), "TextTransparency", 0)
		restore(frame:FindFirstChild("selecticon"), "ImageTransparency", 0)
		restore(frame:FindFirstChild("rarityframe"), "BackgroundTransparency", 1)
	end
end

--// Hit detection
local function IsMouseInside(gui1, gui2): boolean
    local gui1_topLeft,gui1_bottomRight = gui1.AbsolutePosition, gui1.AbsolutePosition + gui1.AbsoluteSize
	local gui2_topLeft,gui2_bottomRight = gui2.AbsolutePosition, gui2.AbsolutePosition + gui2.AbsoluteSize
	return ((gui1_topLeft.x < gui2_bottomRight.x and gui1_bottomRight.x > gui2_topLeft.x) and (gui1_topLeft.y < gui2_bottomRight.y and gui1_bottomRight.y > gui2_topLeft.y))
end

local function GetHotbarSlotUnderMouse()
	for _, child in ipairs(HotbarFrame:GetChildren()) do
		if child:IsA("Frame") and IsMouseInside(DragState.ghostFrame, child) then
			local slotindex = child.Name:gsub("_", "")
			return child, tonumber(slotindex)
		end

		if child:IsA("ImageLabel") and IsMouseInside(DragState.ghostFrame, child) then
			local slotindex = child.Name:gsub("_", "")
			return child, tonumber(slotindex)
		end
	end

	return nil, nil
end

local function GetBackpackSlotUnderMouse()
	local scrolling = BackpackFrame:FindFirstChild("ScrollingFrame")
	if not scrolling then return end

	for _, child in ipairs(scrolling:GetChildren()) do
		if child:IsA("Frame") and IsMouseInside(DragState.ghostFrame, child) then
			return child, tonumber(child.Name)
		end

		if child:IsA("ImageLabel") and IsMouseInside(DragState.ghostFrame, child) then
			return child, tonumber(child.Name)
		end
	end

	return nil, nil
end

--// End drag
function DragHandler.EndDrag(--[[, Scope]])
	if checkConnection then checkConnection:Disconnect() end
	if dragConnection then dragConnection:Disconnect() end
	if releaseConnection then releaseConnection:Disconnect() end

	if not DragState.isDragging then
		DragHandler.Reset()
		return
	end


	local hotbarSlot, hotbarIndex = GetHotbarSlotUnderMouse()
	local backpackSlot, backpackIndex = GetBackpackSlotUnderMouse()
	local OverBackpack = IsMouseInside(DragState.ghostFrame, BackpackFrame)
	local OverHotbar = IsMouseInside(DragState.ghostFrame, HotbarFrame)


	-- Logic Execution
	local targetType
	local targetSlot
	local FromType =  DragState.originalFrame.Parent.Name == "Hotbar" and "Hotbar" or "Storage"
	local FromSlot: Frame = DragState.originalFrame
	local index
	-- local index2

	if FromSlot then FromSlot.Name:gsub("_", ""); index = tonumber(FromSlot.Name) end
	-- if targetSlot then targetSlot.Name:gsub("_", ""); index2 = tonumber(targetSlot.Name) end



	if hotbarSlot and hotbarIndex and hotbarSlot ~= FromSlot then
		--swap
		targetType = "Hotbar"
		targetSlot = hotbarSlot

		if FromType == "Hotbar" and FromSlot then
			warn("from hotbar to hotbar swapping ".. FromSlot.Name .. " with " .. hotbarIndex)
			InventoryController.Swap(FromType, index, targetType, hotbarIndex, true)
		else
			warn("from backpack to hotbar swapping ".. FromSlot.Name .. " with " .. hotbarIndex)
			InventoryController.Swap(FromType, index, targetType, hotbarIndex, true)
		end
	end

	if backpackSlot and backpackIndex and backpackSlot ~= FromSlot then
		--swap
		targetType = "Storage"
		targetSlot = backpackSlot

		if FromType == "Hotbar" then
			warn("from hotbar to backpack swapping ".. FromSlot.Name .. " with " .. backpackIndex)
			InventoryController.Swap(FromType, index, targetType, backpackIndex, true)
		else
			warn("from backpack to backpack swapping ".. FromSlot.Name .. " with " .. backpackIndex)
			InventoryController.Swap(FromType, index, targetType, backpackIndex, true)
		end
	end

	if OverBackpack and not backpackSlot and FromType == "Hotbar" then
		if  BackpackFrame.Visible then
			warn("append to backpack")
			InventoryController.AddToBackpack(FromType, index, true)
		else
			InventoryController.Drop(FromType, index, nil, true)
			warn("drop")
		end
	end

	if not OverHotbar and not OverBackpack then
		InventoryController.Drop(FromType, index, nil, true)
		warn("drop")
	end


	if hookManager then
		hookManager:Fire(
			"OnDragEnd",
			DragState.sourceType,
			DragState.sourceSlot,
			targetType,
			targetSlot
		)
	end

	DragHandler.Reset()
end

--// Reset
function DragHandler.Reset()
	DragHandler.RestoreOriginalVisuals()

	if DragState.ghostFrame then
		DragState.ghostFrame:Destroy()
	end
    
    local currentEnabled = DragState.enabled

	DragState = {
		isDragging = false,
		enabled = currentEnabled,
		sourceType = nil,
		sourceSlot = nil,
		originalFrame = nil,
		ghostFrame = nil,
	}
end

--// Cleanup
function DragHandler.Destroy()
	DragHandler.Reset()
	if dragConnection then dragConnection:Disconnect() end
	if releaseConnection then releaseConnection:Disconnect() end
	if checkConnection then checkConnection:Disconnect() end
end

return DragHandler
