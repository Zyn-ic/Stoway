local UserInputService = game:GetService("UserInputService")
local InteractionManager = {}
local DragHandlerRef = nil

local ConsoleModeManager = require(script.Parent.ConsoleModeManager)

local connection = nil

local function preferredInputChanged()
    local preferredInput = UserInputService.PreferredInput
    if not DragHandlerRef then return end

    if preferredInput == Enum.PreferredInput.Gamepad then
        warn("Gamepad detected, disabling DragHandler")
        DragHandlerRef.SetEnabled(false)
        
        ConsoleModeManager.Init()
        ConsoleModeManager.SetMode("Combat") 
    else
        warn("Mouse/Touch detected, enabling DragHandler")
        DragHandlerRef.SetEnabled(true)
        
        ConsoleModeManager.Destroy()
    end
end

function InteractionManager.Init(dragHandler)
    DragHandlerRef = dragHandler
    
    preferredInputChanged()
    connection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(preferredInputChanged)
end

function InteractionManager.Destroy()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    
    ConsoleModeManager.Destroy()
    DragHandlerRef = nil
end

return InteractionManager
