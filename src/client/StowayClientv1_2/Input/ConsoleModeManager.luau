local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionManager = require(script.Parent.SelectionManager)
local InputManager = require(script.Parent.InputManager)
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)
local Binds = require(ReplicatedStorage.Shared.Binds)

local ConsoleModeManager = {}
local CurrentMode = "" -- "Combat" | "Inventory"

-- Long Press Configuration
local LONG_PRESS_DURATION = 0.5
local isPressed = false
local switchAction = nil
local _backpackAction = nil

local modeIndicatorGui = nil
local modeTextLabel = nil

function ConsoleModeManager.Init()
    if switchAction then return end -- Prevent double-init

    switchAction = IllusionIAS.new("SwitchModeAction")
    _backpackAction = InputManager.BackpackAction

    local switchBinds = Binds.Global.SwitchMode
    if switchBinds then
        if switchBinds.Console then
             for _, b in ipairs(switchBinds.Console) do
                switchAction:AddBind(b.Main, unpack(b.Modifiers or {}))
             end
        end
        if switchBinds.PC then
             for _, b in ipairs(switchBinds.PC) do
                switchAction:AddBind(b.Main, unpack(b.Modifiers or {}))
             end
        end
    end

    IllusionIAS.addContext(InputManager.ContextGlobal, switchAction)

    CreateModeIndicator()

    local longPressTask = nil

    switchAction.Activated:Connect(function(active, pressed)
        if pressed then
            isPressed = true
            
            -- Schedule the toggle action
            longPressTask = task.delay(LONG_PRESS_DURATION, function()
                if isPressed then
                    ConsoleModeManager.ToggleMode()
                    isPressed = false -- Reset state after successful toggle
                    longPressTask = nil
                end
            end)
        else
            isPressed = false
            -- Cancel the scheduled toggle if button is released early
            if longPressTask then
                task.cancel(longPressTask)
                longPressTask = nil
            end
        end
    end)
end

function CreateModeIndicator()
    if modeIndicatorGui then return end

    local player = game:GetService("Players").LocalPlayer
    modeIndicatorGui = Instance.new("ScreenGui")
    modeIndicatorGui.Name = "StowayConsoleHUD"
    modeIndicatorGui.ResetOnSpawn = false
    modeIndicatorGui.Parent = player:WaitForChild("PlayerGui")

    local bg = Instance.new("Frame")
    bg.Name = "ModeBadge"
    bg.Size = UDim2.fromOffset(150, 40)
    bg.Position = UDim2.new(0.95, -160, 0.85, 0) -- Bottom Right
    bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Parent = modeIndicatorGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = bg

    modeTextLabel = Instance.new("TextLabel")
    modeTextLabel.Name = "ModeText"
    modeTextLabel.Size = UDim2.fromScale(1, 1)
    modeTextLabel.BackgroundTransparency = 1
    modeTextLabel.Font = Enum.Font.GothamBold
    modeTextLabel.TextSize = 18
    modeTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    modeTextLabel.Text = "COMBAT"
    modeTextLabel.Parent = bg
end


function ConsoleModeManager.SetMode(modeName)
    if CurrentMode == modeName then return end
    CurrentMode = modeName

    print(`[ConsoleModeManager] Switching to {modeName} Mode`)

    if modeName == "Combat" then
        InputManager.SetCombatEnabled(true)
        InputManager.SetInventoryEnabled(false)
        SelectionManager.SetEnabled(false)
        GuiService.GuiNavigationEnabled = false
        GuiService.SelectedObject = nil

        if modeTextLabel then
             modeTextLabel.Text = "⚔️ COMBAT"
             modeTextLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Reddish
        end

    elseif modeName == "Inventory" then
        InputManager.SetCombatEnabled(false)
        InputManager.SetInventoryEnabled(true)
        SelectionManager.SetEnabled(true)
        GuiService.GuiNavigationEnabled = true

        if modeTextLabel then
             local initialDesc = SelectionManager.GetStateDescription and SelectionManager.GetStateDescription() or "SELECTING"
             modeTextLabel.Text = "🎒 " .. initialDesc
             modeTextLabel.TextColor3 = Color3.fromRGB(100, 255, 150) -- Greenish
        end

        -- Connect to State Changes to update UI
        SelectionManager.OnStateChanged = function(newDesc)
            if modeTextLabel then
                modeTextLabel.Text = "🎒 " .. newDesc
            end
        end
    end
end

function ConsoleModeManager.ToggleMode()
    if CurrentMode == "Combat" then
        ConsoleModeManager.SetMode("Inventory")
    else
        ConsoleModeManager.SetMode("Combat")
    end
end

function ConsoleModeManager.Destroy()
    isPressed = false
    if switchAction then
        switchAction:Destroy()
        switchAction = nil
    end

    if modeIndicatorGui then
        modeIndicatorGui:Destroy()
        modeIndicatorGui = nil
        modeTextLabel = nil
    end

    -- Reset to default state
    CurrentMode = ""
    InputManager.SetCombatEnabled(true)
    InputManager.SetInventoryEnabled(false)
    SelectionManager.SetEnabled(false)
    SelectionManager.OnStateChanged = nil
end

return ConsoleModeManager
