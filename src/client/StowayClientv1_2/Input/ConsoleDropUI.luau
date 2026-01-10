local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local ConsoleDropUI = {}
local container = nil
local currentAmount = 1
local maxAmount = 1
local dropMenuTemplate = nil

-- References
local numberIndicator = nil
local titleLabel = nil
local increaseButton = nil

-- Callbacks (set by SelectionManager)
ConsoleDropUI.OnDrop = nil     -- function(amount)
ConsoleDropUI.OnDropAll = nil  -- function()
ConsoleDropUI.OnCancel = nil   -- function()

function ConsoleDropUI.SetTemplate(template)
    dropMenuTemplate = template
end

function ConsoleDropUI.Create()
    if container then return container end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "StowayDropUI"
    gui.ResetOnSpawn = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    gui.Enabled = false
    
    local DropMenu
    local Drop, Dropall, Cancel, Decrease, Increase, NumberIndicator, Title

    if dropMenuTemplate then
        DropMenu = dropMenuTemplate:Clone()
        DropMenu.Parent = gui
        
        -- Find children in template (assuming names match)
        NumberIndicator = DropMenu:FindFirstChild("NumberIndicator")
        Drop = DropMenu:FindFirstChild("Drop")
        Dropall = DropMenu:FindFirstChild("Dropall")
        Cancel = DropMenu:FindFirstChild("Cancel")
        Decrease = DropMenu:FindFirstChild("Decrease")
        Increase = DropMenu:FindFirstChild("Increase")
        Title = DropMenu:FindFirstChild("Title")
    else
        DropMenu = Instance.new("Frame")
        DropMenu.Name = "DropMenu"
        DropMenu.Size = UDim2.new(0.37, 0, 0.49, 0)
        DropMenu.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        DropMenu.Position = UDim2.new(0.32, 0, 0.25, 0)
        DropMenu.BorderSizePixel = 0
        DropMenu.BackgroundColor3 = Color3.new(1.00, 1.00, 1.00)
        DropMenu.SelectionGroup = true
        DropMenu.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
        DropMenu.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
        DropMenu.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
        DropMenu.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
        DropMenu.Parent = gui
    
        local UICorner = Instance.new("UICorner")
        UICorner.Parent = DropMenu
    
        local UIGradient = Instance.new("UIGradient")
        UIGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.new(0.10, 0.31, 1.00)), 
            ColorSequenceKeypoint.new(0.56, Color3.new(0.33, 1.00, 1.00)), 
            ColorSequenceKeypoint.new(1.00, Color3.new(0.08, 0.14, 1.00))
        })
        UIGradient.Parent = DropMenu
    
        NumberIndicator = Instance.new("TextLabel")
        NumberIndicator.Name = "NumberIndicator"
        NumberIndicator.TextWrapped = true
        NumberIndicator.BorderSizePixel = 0
        NumberIndicator.TextScaled = true
        NumberIndicator.BackgroundColor3 = Color3.new(0.19, 0.19, 0.19)
        NumberIndicator.FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        NumberIndicator.TextSize = 14
        NumberIndicator.Size = UDim2.new(0.42, 0.00, 0.26, 0.00)
        NumberIndicator.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        NumberIndicator.Text = "1"
        NumberIndicator.TextColor3 = Color3.new(1.00, 1.00, 1.00)
        NumberIndicator.Position = UDim2.new(0.06, 0.00, 0.43, 0.00)
        NumberIndicator.Parent = DropMenu
    
        local UICorner_1 = Instance.new("UICorner")
        UICorner_1.Parent = NumberIndicator
        
        Drop = Instance.new("TextButton")
        Drop.Name = "Drop"
        Drop.TextWrapped = true
        Drop.BorderSizePixel = 0
        Drop.BackgroundColor3 = Color3.new(0.16, 0.16, 0.16)
        Drop.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Drop.TextSize = 25
        Drop.Size = UDim2.new(0.30, 0.00, 0.26, 0.00)
        Drop.TextColor3 = Color3.new(1.00, 1.00, 1.00)
        Drop.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Drop.Text = "Drop"
        Drop.Position = UDim2.new(0.64, 0.00, 0.17, 0.00)
        Drop.Parent = DropMenu
    
        local UICorner_2 = Instance.new("UICorner")
        UICorner_2.Parent = Drop
    
        Dropall = Instance.new("TextButton")
        Dropall.Name = "Dropall"
        Dropall.TextWrapped = true
        Dropall.BorderSizePixel = 0
        Dropall.BackgroundColor3 = Color3.new(0.16, 0.16, 0.16)
        Dropall.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Dropall.TextSize = 25
        Dropall.Size = UDim2.new(0.30, 0.00, 0.26, 0.00)
        Dropall.TextColor3 = Color3.new(1.00, 1.00, 1.00)
        Dropall.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Dropall.Text = "DropAll"
        Dropall.Position = UDim2.new(0.64, 0.00, 0.43, 0.00)
        Dropall.Parent = DropMenu
    
        local UICorner_3 = Instance.new("UICorner")
        UICorner_3.Parent = Dropall
    
        Cancel = Instance.new("TextButton")
        Cancel.Name = "Cancel"
        Cancel.TextWrapped = true
        Cancel.BorderSizePixel = 0
        Cancel.BackgroundColor3 = Color3.new(0.16, 0.16, 0.16)
        Cancel.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Cancel.TextSize = 25
        Cancel.Size = UDim2.new(0.30, 0.00, 0.26, 0.00)
        Cancel.TextColor3 = Color3.new(1.00, 1.00, 1.00)
        Cancel.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Cancel.Text = "Cancel"
        Cancel.Position = UDim2.new(0.64, 0.00, 0.70, 0.00)
        Cancel.Parent = DropMenu
    
        local UICorner_4 = Instance.new("UICorner")
        UICorner_4.Parent = Cancel
    
        Decrease = Instance.new("ImageButton")
        Decrease.Name = "Decrease"
        Decrease.BorderSizePixel = 0
        Decrease.BackgroundColor3 = Color3.new(0.16, 0.16, 0.16)
        Decrease.Image = "rbxassetid://878102417"
        Decrease.Size = UDim2.new(0.17, 0.00, 0.21, 0.00)
        Decrease.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Decrease.Position = UDim2.new(0.18, 0.00, 0.72, 0.00)
        Decrease.Parent = DropMenu
    
        local UICorner_5 = Instance.new("UICorner")
        UICorner_5.Parent = Decrease
    
        Increase = Instance.new("ImageButton")
        Increase.Name = "Increase"
        Increase.BorderSizePixel = 0
        Increase.BackgroundColor3 = Color3.new(0.16, 0.16, 0.16)
        Increase.Image = "rbxassetid://16844851226"
        Increase.Size = UDim2.new(0.17, 0.00, 0.21, 0.00)
        Increase.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Increase.Position = UDim2.new(0.18, 0.00, 0.19, 0.00)
        Increase.Parent = DropMenu
        
        local UICorner_6 = Instance.new("UICorner")
        UICorner_6.Parent = Increase
    
        Title = Instance.new("TextLabel")
        Title.Name = "Title"
        Title.TextWrapped = true
        Title.BorderSizePixel = 0
        Title.BackgroundColor3 = Color3.new(0.26, 0.26, 0.26)
        Title.FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        Title.TextSize = 20
        Title.Size = UDim2.new(1.00, 0.00, 0.14, 0.00)
        Title.BorderColor3 = Color3.new(0.00, 0.00, 0.00)
        Title.Text = "Destroying Item:"
        Title.TextColor3 = Color3.new(1.00, 1.00, 1.00)
        Title.BackgroundTransparency = 0.5
        Title.Parent = DropMenu
        
        local UIStroke = Instance.new("UIStroke")
        UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStroke.LineJoinMode = Enum.LineJoinMode.Miter
        UIStroke.Thickness = 2
        UIStroke.Parent = Title
    
        local UIStroke_1 = Instance.new("UIStroke")
        UIStroke_1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStroke_1.Thickness = 2
        UIStroke_1.Parent = DropMenu
    end

    -- Assign references
    numberIndicator = NumberIndicator
    titleLabel = Title
    increaseButton = Increase
    
    -- Button Click Connections
    if Drop then
        Drop.Activated:Connect(function()
            if ConsoleDropUI.OnDrop then
                ConsoleDropUI.OnDrop(currentAmount)
            end
        end)
    end
    
    if Dropall then
        Dropall.Activated:Connect(function()
            if ConsoleDropUI.OnDropAll then
                ConsoleDropUI.OnDropAll()
            end
        end)
    end
    
    if Cancel then
        Cancel.Activated:Connect(function()
            if ConsoleDropUI.OnCancel then
                ConsoleDropUI.OnCancel()
            end
        end)
    end
    
    if Increase then
        Increase.Activated:Connect(function()
            ConsoleDropUI.ChangeAmount(1)
        end)
    end
    
    if Decrease then
        Decrease.Activated:Connect(function()
            ConsoleDropUI.ChangeAmount(-1)
        end)
    end
    
    container = gui
    return gui
end

function ConsoleDropUI.UpdateAmount(amount)
    currentAmount = math.clamp(amount, 1, maxAmount)
    if numberIndicator then
        numberIndicator.Text = tostring(currentAmount)
    end
end

function ConsoleDropUI.Show(itemData, startAmount)
    local gui = ConsoleDropUI.Create()
    gui.Enabled = true
    
    maxAmount = itemData.Amount or 1
    currentAmount = math.clamp(startAmount or 1, 1, maxAmount)
    
    if titleLabel then
        titleLabel.Text = "Destroying Item: " .. (itemData.Id or "Unknown")
    end
    
    ConsoleDropUI.UpdateAmount(currentAmount)
    
    -- Set gamepad focus to Increase button, then release after 1 second
    -- so D-Pad controls amount instead of navigation
    if increaseButton then
        GuiService.SelectedObject = increaseButton
        task.delay(1, function()
            if container and container.Enabled then
                GuiService.SelectedObject = nil
            end
        end)
    end
end

function ConsoleDropUI.Hide()
    if container then
        container.Enabled = false
    end
end

function ConsoleDropUI.ChangeAmount(delta)
    ConsoleDropUI.UpdateAmount(currentAmount + delta)
    return currentAmount
end

function ConsoleDropUI.GetAmount()
    return currentAmount
end

function ConsoleDropUI.Destroy()
    if container then
        container:Destroy()
        container = nil
    end
    
    -- Clear all references
    numberIndicator = nil
    titleLabel = nil
    increaseButton = nil
    
    -- Clear callbacks
    ConsoleDropUI.OnDrop = nil
    ConsoleDropUI.OnDropAll = nil
    ConsoleDropUI.OnCancel = nil
    
    -- Reset state
    currentAmount = 1
    maxAmount = 1
end

return ConsoleDropUI
