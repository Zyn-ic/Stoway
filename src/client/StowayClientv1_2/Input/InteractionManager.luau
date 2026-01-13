local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryStore = require(script.Parent.Parent.CoreState.InventoryStore)
local InventoryController = require(script.Parent.Parent.Operations.InventoryController)
local Settings = require(ReplicatedStorage.Shared.Settings)

local InteractionManager = {}
local DragHandlerRef = nil
local HotbarFrameRef = nil

local ConsoleModeManager = require(script.Parent.ConsoleModeManager)

local connection = nil
local scrollConnection = nil

--// Helper: Zoom Management
local player = Players.LocalPlayer
local zoomResetThread = nil
local DEFAULT_MIN_ZOOM = 5 -- User provided default
local DEFAULT_MAX_ZOOM = 50 -- User provided default

local function getCameraDistance()
	local camera = workspace.CurrentCamera
	local character = player.Character
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if not head then return nil end

	return (head.Position - camera.CFrame.Position).Magnitude
end

local function lockZoom()
	local currentDist = getCameraDistance()
	if not currentDist then return end

	-- Lock to current distance
	player.CameraMinZoomDistance = currentDist
	player.CameraMaxZoomDistance = currentDist

	-- Cancel any pending reset
	if zoomResetThread then
		task.cancel(zoomResetThread)
		zoomResetThread = nil
	end

	-- Schedule reset
	zoomResetThread = task.delay(0.2, function()
		player.CameraMinZoomDistance = DEFAULT_MIN_ZOOM
		player.CameraMaxZoomDistance = DEFAULT_MAX_ZOOM
		zoomResetThread = nil
	end)
end

--// Helper: Bounds Checking
local function isMouseOverFrame(frame: GuiObject?)
    if not frame then return false end

    local mousePos = player:GetMouse()
    local absPos = frame.AbsolutePosition
    local absSize = frame.AbsoluteSize

    local xBound = (mousePos.X >= absPos.X and mousePos.X < absPos.X + absSize.X)
    local yBound = (mousePos.Y >= absPos.Y and mousePos.Y < absPos.Y + absSize.Y)

    return (xBound and yBound)
end

--// Helper: Hotbar Cycling
local function handleScroll(input)
    -- 1. Check if Mouse is over Hotbar (User Request)
    if not isMouseOverFrame(HotbarFrameRef) then return end

    -- 2. Check if Hotbar has items
    local hotbar = InventoryStore:GetHotbar()
    local hasItems = false
    for _, uuid in pairs(hotbar) do
        if uuid then hasItems = true; break end
    end

    if not hasItems then return end

    -- 3. Lock Zoom (User Request)
    lockZoom()

    -- 4. Determine Direction & Current State
    local direction = (input.Position.Z > 0) and 1 or -1 -- 1 = Up (Ascending), -1 = Down (Descending)
    local currentEquipped = InventoryStore:GetEquippedUUID()
    local currentSlotIndex = nil

    if currentEquipped then
        local slotType, slot = InventoryStore:FindSlotByUUID(currentEquipped)
        if slotType == "Hotbar" then
            currentSlotIndex = slot
        end
    end

    -- 5. Find Next Slot
    local nextSlot = nil

    if not currentSlotIndex then
        -- Nothing equipped: Find first occupied slot
        if direction == 1 then
             for i = 1, Settings.Hotbar.MaxSlots do
                if hotbar[i] then nextSlot = i; break end
             end
        else
            for i = Settings.Hotbar.MaxSlots, 1, -1 do
                if hotbar[i] then nextSlot = i; break end
            end
        end
    else
        -- Something equipped: Find next occupied slot in direction
        local checkSlot = currentSlotIndex
        for _ = 1, Settings.Hotbar.MaxSlots do
            checkSlot = checkSlot + (direction == 1 and 1 or -1)

            -- Wrap around
            if checkSlot > Settings.Hotbar.MaxSlots then checkSlot = 1 end
            if checkSlot < 1 then checkSlot = Settings.Hotbar.MaxSlots end

            if hotbar[checkSlot] then
                nextSlot = checkSlot
                break
            end
        end
    end

    -- 6. Equip
    if nextSlot then
        InventoryController.HandleEquipped(hotbar[nextSlot], true) -- Replicate = true
    end
end

local function preferredInputChanged()
    local preferredInput = UserInputService.PreferredInput
    if not DragHandlerRef then return end

    if preferredInput == Enum.PreferredInput.Gamepad then
        warn("Gamepad detected, disabling DragHandler")
        DragHandlerRef.SetEnabled(false)

        ConsoleModeManager.Init()
        ConsoleModeManager.SetMode("Combat")

        -- Disable Scroll on Console
        if scrollConnection then
            scrollConnection:Disconnect()
            scrollConnection = nil
        end
    else
        warn("Mouse/Touch detected, enabling DragHandler")
        DragHandlerRef.SetEnabled(true)

        ConsoleModeManager.Destroy()

        -- Enable Scroll on PC if setting allows
        if Settings.Gameplay.MouseScroll and not scrollConnection then
             scrollConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    handleScroll(input)
                end
            end)
        end
    end
end

function InteractionManager.Init(dragHandler, hotbarFrame)
    DragHandlerRef = dragHandler
    HotbarFrameRef = hotbarFrame

    preferredInputChanged()
    connection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(preferredInputChanged)
end

function InteractionManager.Destroy()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    if scrollConnection then
        scrollConnection:Disconnect()
        scrollConnection = nil
    end

    ConsoleModeManager.Destroy()
    DragHandlerRef = nil
    HotbarFrameRef = nil
end

return InteractionManager
