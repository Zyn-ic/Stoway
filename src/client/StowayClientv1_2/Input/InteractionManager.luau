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
local hotbarEnterConnection = nil
local hotbarLeaveConnection = nil

--// Helper: Zoom Management
local player = Players.LocalPlayer
local DefaultMinZoom = player.CameraMinZoomDistance
local DefaultMaxZoom = player.CameraMaxZoomDistance
local IsZoomLocked = false

local function getCameraDistance()
	local camera = workspace.CurrentCamera
	local character = player.Character; if not character then return nil end
	local CamPos = camera.CFrame.Position
	local CharPos = character:GetPivot().Position

	--this is the best I can do there is still some zooming in/out ;((
	return math.floor((CamPos - CharPos).Magnitude)
end

local function lockZoomAtCurrentDistance(): boolean
	if IsZoomLocked then return true end

	local currentDist = getCameraDistance()
	if not currentDist then return false end

	-- Snapshot current defaults so external changes are restored correctly.
	DefaultMinZoom = player.CameraMinZoomDistance
	DefaultMaxZoom = player.CameraMaxZoomDistance

	-- Lock to current distance
	player.CameraMinZoomDistance = currentDist
	player.CameraMaxZoomDistance = currentDist
	IsZoomLocked = true

	return true
end

local function unlockZoom()
	if not IsZoomLocked then return end
	player.CameraMinZoomDistance = DefaultMinZoom
	player.CameraMaxZoomDistance = DefaultMaxZoom
	IsZoomLocked = false
end

local function disconnectHotbarHoverConnections()
	if hotbarEnterConnection then
		hotbarEnterConnection:Disconnect()
		hotbarEnterConnection = nil
	end
	if hotbarLeaveConnection then
		hotbarLeaveConnection:Disconnect()
		hotbarLeaveConnection = nil
	end
end

local function hotbarHasItems(): boolean
	local hotbar = InventoryStore:GetHotbar()
	for _, uuid in pairs(hotbar) do
		if uuid then
			return true
		end
	end
	return false
end

local function connectHotbarHoverConnections()
	disconnectHotbarHoverConnections()
	if not HotbarFrameRef then return end

	hotbarEnterConnection = HotbarFrameRef.MouseEnter:Connect(function()
		if hotbarHasItems() then
			lockZoomAtCurrentDistance()
		end
	end)

	hotbarLeaveConnection = HotbarFrameRef.MouseLeave:Connect(function()
		unlockZoom()
	end)
end

--// Helper: Hotbar Cycling
local function handleScroll(input)
    -- 1. Check if Mouse is over Hotbar (User Request)
    if not IsZoomLocked then return end

    -- 2. Check if Hotbar has items
    local hotbar = InventoryStore:GetHotbar()
    local hasItems = false
    for _, uuid in pairs(hotbar) do
        if uuid then hasItems = true; break end
    end

    if not hasItems then return end

    -- 3. Ensure zoom is locked while cycling.
    lockZoomAtCurrentDistance()

    -- 4. Determine Direction & Current State
    local direction = (input.Position.Z > 0) and 1 or -1 -- 1 = Up (Ascending), -1 = Down (Descending)
    local currentEquipped = InventoryStore:GetEquippedUUID()
    local currentSlotIndex = nil
	local maxSlots = InventoryStore:GetMaxHotbarSlots()

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
             for i = 1, maxSlots do
                if hotbar[i] then nextSlot = i; break end
             end
        else
            for i = maxSlots, 1, -1 do
                if hotbar[i] then nextSlot = i; break end
            end
        end
    else
        -- Something equipped: Find next occupied slot in direction
        local checkSlot = currentSlotIndex
        for _ = 1, maxSlots do
            checkSlot = checkSlot + (direction == 1 and 1 or -1)

            -- Wrap around
            if checkSlot > maxSlots then checkSlot = 1 end
            if checkSlot < 1 then checkSlot = maxSlots end

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

    local isGamepad = preferredInput == Enum.PreferredInput.Gamepad
    local isMouseKeyboard = preferredInput == Enum.PreferredInput.KeyboardAndMouse

    if isGamepad then
        warn("Gamepad detected, disabling DragHandler")
        DragHandlerRef.SetEnabled(false)

        ConsoleModeManager.Init()
        ConsoleModeManager.SetMode("Combat")

        -- Disable Scroll on Console
        if scrollConnection then
            scrollConnection:Disconnect()
            scrollConnection = nil
        end
		disconnectHotbarHoverConnections()
		unlockZoom()
    else
        warn("Mouse/Touch detected, enabling DragHandler")
        DragHandlerRef.SetEnabled(true)

        ConsoleModeManager.Destroy()

        -- Enable mouse-wheel behavior only on mouse+keyboard.
        if isMouseKeyboard and Settings.Gameplay.MouseScroll and not scrollConnection then
             scrollConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    handleScroll(input)
                end
            end)
        end

        if (not isMouseKeyboard) and scrollConnection then
            scrollConnection:Disconnect()
            scrollConnection = nil
        end

        -- Hover-based zoom lock only applies to mouse+keyboard.
        if isMouseKeyboard then
		    connectHotbarHoverConnections()
        else
            disconnectHotbarHoverConnections()
            unlockZoom()
        end
    end
end

function InteractionManager.Init(dragHandler, hotbarFrame)
    DragHandlerRef = dragHandler
    HotbarFrameRef = hotbarFrame
	DefaultMinZoom = player.CameraMinZoomDistance
	DefaultMaxZoom = player.CameraMaxZoomDistance
	IsZoomLocked = false

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
	disconnectHotbarHoverConnections()
	unlockZoom()

	ConsoleModeManager.Destroy()
	DragHandlerRef = nil
    HotbarFrameRef = nil
end

return InteractionManager
