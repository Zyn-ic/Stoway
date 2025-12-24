-- src/client/StowayClientV1_2/ClientInventoryService.luau

--modules
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local ClientInventoryService = {}
local HookManagerClass = require(script.Hook.HookManager)
local HookManager = HookManagerClass.new()
local DragHandler = require(script.DragFunctions.DragHandler)
local InventoryController = require(script.Operations.InventoryController)
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Binds = require(ReplicatedStorage.Shared.Binds)
local RarityValues = require(ReplicatedStorage.Shared.RarityValues)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Store = require(script.CoreState.InventoryStore)
local SlotFactory = require(script.SlotCreation.SlotFactory)
local NetworkHandler = require(script.NetworkFunctions.NetworkHandler)


-- BindableEvents
local GetStowayFromServer = ReplicatedStorage:WaitForChild("Remotes").AskForStoway :: RemoteFunction

-- CONSTANTS
local HotbarScope = nil 
local StorageScope = nil 
local Player = Players.LocalPlayer :: Player 
local GUISTORAGE = ReplicatedStorage:FindFirstChild("Gui") -- change to your folder name
local GUIFOLDER : Folder

-- Others
local InventoryGui       --= Player.PlayerGui:WaitForChild("StowayGui", 20).Stoway :: ScreenGui
local DraggingGui        --= Player.PlayerGui:WaitForChild("StowayGui").DraggingGui :: ScreenGui
local BackpackFrame      --= InventoryGui.Backpack :: Frame
local HotbarFrame        --= InventoryGui.Hotbar :: Frame
local ScrollingBackpack : ScrollingFrame --= BackpackFrame.ScrollingFrame :: ScrollingFrame
local SearchFilter      : TextBox --= BackpackFrame.SearchFilter :: TextBox
local WeightLabel       : TextLabel --= BackpackFrame.Weight :: TextLabel


function SetUpBinds()
	ContextActionService:BindAction("toggle_backpack", ClientInventoryService.ToggleBackpack, false, unpack(Binds.BackpackBinds))
	ClientInventoryService.BindKeyBinds("HotbarSlot", nil)
end

function ClientInventoryService.ToggleBackpack(_actionName, inputState, _inputObject)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
    BackpackFrame.Visible = not BackpackFrame.Visible 
end

function ClientInventoryService.BindKeyBinds(actionNamePrefix, _slotfolder)
	local currentSettings = Fusion.peek(Store.Settings)
	if not currentSettings or not currentSettings.MaxHotbarSlots then return end
	
	for i = 1, currentSettings.MaxHotbarSlots do
		local bindData = Binds.KeyBinds[i]
		if not bindData then break end

		local function EquipThisSlot(_actionName, inputState, _inputObject)
			if inputState ~= Enum.UserInputState.Begin then return end
			InventoryController.HandleEquipped(Store:GetUUidFromIndex(i, "Hotbar"), true)
		end

		local actionName = actionNamePrefix .. tostring(i)
		ContextActionService:BindAction(actionName, EquipThisSlot, false, unpack(bindData.Keys))
	end
end

local function GetKeybindDisplay(slotIndex: number): string?
	local bindData = Binds.KeyBinds[slotIndex]
	if not bindData then return nil end
	return "[" .. bindData.Display .. "]"
end

local function GetSortedIndices(storage: { string }, items: { [string]: any }, sortOrder: string): { number }
	local indices = {}
	for i = 1, #storage do
		table.insert(indices, i)
	end
	
	if not sortOrder or sortOrder == "None" then
		return indices
	end
	
	table.sort(indices, function(a, b)
		local itemA = items[storage[a]]
		local itemB = items[storage[b]]
		if not itemA or not itemB then return a < b end
		
		if sortOrder == "Name" then
			return itemA.Id < itemB.Id
		elseif sortOrder == "Rarity" then
			local priorityA = RarityValues.RaritySortOrder[itemA.Metadata and itemA.Metadata.Rarity] or 99
			local priorityB = RarityValues.RaritySortOrder[itemB.Metadata and itemB.Metadata.Rarity] or 99
			if priorityA == priorityB then return itemA.Id < itemB.Id end
			return priorityA < priorityB
		elseif sortOrder == "ItemType" then
			local typeA = itemA.Metadata and itemA.Metadata.Type or ""
			local typeB = itemB.Metadata and itemB.Metadata.Type or ""
			local priorityA = RarityValues.ItemTypeSortOrder[typeA] or 99
			local priorityB = RarityValues.ItemTypeSortOrder[typeB] or 99
			if priorityA == priorityB then return itemA.Id < itemB.Id end
			return priorityA < priorityB
		end
		return a < b
	end)
	
	return indices
end

function BuildHooks(HookPresetName: string?)
    print(HookManager)
    HookManager:ClearAll()
    if HookPresetName then
        local hookFolder = GUIFOLDER and GUIFOLDER:FindFirstChild("HookFuncs")
        if hookFolder then
            local module = hookFolder:FindFirstChild(HookPresetName)
            if module and module:IsA("ModuleScript") then
                local preset = require(module)
                HookManager:LoadPreset(preset)
            else
                warn("[Stoway] Hook preset module not found:", HookPresetName)
            end
        else
            warn(`[Stoway] {GUIFOLDER}.HookFuncs folder missing!`)
        end
    end
end

function BuildGui(UIVersion, FolderName, GuiName)
    if not GuiName then return {success = false, reason = `GUI NAME IS BLANK`} end
    

    GUIFOLDER = GUISTORAGE[UIVersion]:FindFirstChild(FolderName) and GUISTORAGE[UIVersion]:FindFirstChild(FolderName):Clone()
    print(GUIFOLDER, GUISTORAGE)
    if not GUIFOLDER then return {success = false, reason = `No Folder by the name {FolderName}`} end 

    InventoryGui = GUIFOLDER:FindFirstChild(GuiName); 
    if not InventoryGui then return {success = false, reason = `No GUI BY THAT NAME -> {GuiName}`} end

    return xpcall(
        function ()
            DraggingGui = GUIFOLDER:FindFirstChild("DraggingGui")
            BackpackFrame = InventoryGui.Backpack
            HotbarFrame = InventoryGui.Hotbar
            ScrollingBackpack = BackpackFrame.ScrollingFrame
            SearchFilter = BackpackFrame.SearchFilter
            WeightLabel = BackpackFrame.Weight

            GUIFOLDER.Parent = Player.PlayerGui
            return {success = true, reason = ""}
        end, 

        function (err)
            return {success = false, reason = err}
        end)
   
end

function BuildHotbar()
	if HotbarScope then
		HotbarScope:doCleanup()
		HotbarScope = nil
	end

    HotbarScope = Store.Scope:deriveScope()
    for i = 1, Fusion.peek(Store.Settings).MaxHotbarSlots do
        SlotFactory.Create(HotbarScope, {
            SlotIndex = i,
            SlotType = "Hotbar",
            Parent = HotbarFrame,
            GuiFOLDER = GUIFOLDER,
            KeybindDisplay = GetKeybindDisplay(i),
            OnDrag = DragHandler.StartDrag, -- Hook up drag handler here for passing scopes
            hookManager = HookManager -- hook manager should refresh or be reloaded per interface refresh
        })
    end
end

function BuildStorage()
    if StorageScope then
		StorageScope:doCleanup()
		StorageScope = nil
	end

    StorageScope = Store.Scope:deriveScope()

    -- 1. Create a Search Value
    local SearchText = nil
    if SearchFilter then
        SearchText = StorageScope:Value("")
        SearchFilter:GetPropertyChangedSignal("Text"):Connect(function()
            SearchText:set(SearchFilter.Text:lower())
        end)
    end

	if WeightLabel then
		if Settings.Storage.Limit and Settings.Storage.Limit > 0 then 
			StorageScope:Hydrate(WeightLabel) {
				Text = StorageScope:Computed(function(use)
					local weight = use(Store.Weight)
					return weight .. "/" .. use(Store.Settings).Limit
				end),
				Visible = true
			}
		else
			WeightLabel.Visible = false
		end
	end

    -- if you want the storage to be updated and have infinity you have to change it to the below
    -- if WeightLabel then
	-- 	StorageScope:Hydrate(WeightLabel) {
	-- 		Text = StorageScope:Computed(function(use)
	-- 			local weight = use(Store.Weight)
	-- 			local settings = use(Store.Settings)
	-- 			if settings and settings.Limit and settings.Limit > 0 then
	-- 				return weight .. "/" .. settings.Limit
	-- 			else
	-- 				return weight .. "/∞"
	-- 			end
	-- 		end),
	-- 	}
	-- end

    -- 2. Master Sort Calculation (Runs once per update)
    -- This creates a lookup table: {[OriginalIndex] = Rank}
    local SortLookup = nil
    if Settings.Storage.Sorting then
        SortLookup = StorageScope:Computed(function(use)
            local storage = use(Store.Storage)
            local items = use(Store.Items)
            local sortOrder = Settings.Storage.SortOrder or "None"
            
            local lookup = {}
            local sortedIndices = GetSortedIndices(storage, items, sortOrder)
            
            for rank, originalIndex in ipairs(sortedIndices) do
                lookup[originalIndex] = rank
            end
            return lookup
        end)
    end

    -- 3. Static Slot Creation
    -- We track raw Storage so slots are only created/deleted on Add/Remove

    
    StorageScope:ForPairs(Store.Storage, function(_use, scope, storageIndex, uuid)
                                          
        local slotFrame = SlotFactory.Create(scope, {
            SlotIndex = storageIndex,
            SlotType = "Storage",
            Parent = ScrollingBackpack,
            GuiFOLDER = GUIFOLDER,
			KeybindDisplay = nil,
            OnDrag = DragHandler.StartDrag,
            hookManager = HookManager
        })


        if SortLookup ~= nil then
        -- 4. Reactive Updates (Filtering and Sorting)
            scope:Hydrate(slotFrame) {
            -- FILTERING
                Visible = scope:Computed(function(use)
                    local search = use(SearchText)
                    if search == "" then return true end
                    
                    local item = use(Store.Items)[uuid]
                    if not item then return false end
                    
                    return item.Id:lower():find(search, 1, true) ~= nil
                end),

            -- SORTING (Lookup is O(1) here, very fast!)
                LayoutOrder = scope:Computed(function(use)
                    local lookup = use(SortLookup)
                    return lookup[storageIndex] or storageIndex
                end)
            }
        end

        return storageIndex, slotFrame
    end)

end

function ClientInventoryService.Reload(config: {UiType: string?, Data: any?}?)
    if not config then return {success = false, reason = "No CONFIG SENT"} end
    local uiType : {FolderName: string, GuiName: string, HookPresetName: string} | nil = config.UiType and Settings.DifferentUIs[config.UiType] 
    if not uiType then return {success = false, reason = "Cannot load data without the type of ui to show"} end

    print("[Stoway] Reloading inventory system...")
    
    -- 1. DESTROY: Unbind all hotkey actions
    for i = 1, 10 do
        ContextActionService:UnbindAction("HotbarSlot" .. tostring(i))
    end
    ContextActionService:UnbindAction("toggle_backpack")
    
    -- 2. CLEANUP: Destroy Fusion scopes (UI cleanup)
    if HotbarScope then
        HotbarScope:doCleanup()
        HotbarScope = nil
    end
    if StorageScope then
        StorageScope:doCleanup()
        StorageScope = nil
    end
    

    -- 3. GUI REFERENCES: Reload UI references (new GUI if provided)
    if GUIFOLDER then GUIFOLDER:Destroy() end
    BuildGui(config.UiType, uiType.FolderName, uiType.GuiName)

    -- 4. HOOKS: Clear old hooks and load new preset (from Name)
    BuildHooks(uiType.HookPresetName)
    
    -- 5. DATA: Re-initialize store if new data provided
    if config ~= nil and config.Data ~= nil then
        Store.Init(config.Data)
    end
    
    -- 6. REBUILD: Reinitialize DragHandler with new references
    DragHandler.Init(DraggingGui, HotbarFrame, BackpackFrame, HookManager, SlotFactory.CloneForGhost)
    
    -- 7. BUILD UI
    BuildHotbar()
    BuildStorage()
    
    -- 8. REBIND: Set up keybinds again
    SetUpBinds()
    
    return {success = true, reason = "[Stoway] Reload complete!"}
end

local NetworkHandlers = {
    Init = function(payload)
        Store.Init(payload)
    end,
    
    Correction = function(payload)
        -- Server sent a correction, re-sync state
        Store.Init(payload)
    end,
    
    Add = function(payload)
        print(payload, (Store:GetState()))
        InventoryController.Add(payload)
    end,
    
    Remove = function(payload)
        -- Server removed an item, sync locally
        InventoryController.Remove(payload.SlotType, payload.Slot, false)
    end,
    
    Swap = function(payload)
        -- Server confirmed swap (client already applied optimistically)
        -- Could use for rollback if needed
        InventoryController.Swap(payload.From.Type, payload.From.Slot, payload.To.Type, payload.To.Slot, false)
    end,
    
    Equip = function(payload)
        InventoryController.SetEquipped(payload.UUID, false)
    end,
    
    UpdateMeta = function(payload)
        -- Update item metadata
        local items = Fusion.peek(Store.Items)
        local item = items[payload.UUID]
        if item then
            local newItems = table.clone(items)
            local newItem = table.clone(item)
            newItem.Metadata = newItem.Metadata or {}
            for k, v in pairs(payload.Updates or {}) do
                if k == "Amount" then
                    newItem.Amount = v
                else
                    newItem.Metadata[k] = v
                end
            end
            newItems[payload.UUID] = newItem
            Store.Items:set(newItems)
            Store.Weight:set(payload.NewWeight)
        end
    end,

    UpdateSettings = function(payload)
        Store.Settings:set(payload)
    end,
    
    Reload = function(payload)
        -- Server triggered reload (e.g., player became mod)
        -- payload.GuiName: Name of new GUI to load from ReplicatedStorage
        -- payload.HookPresetName: Name of ModuleScript in ReplicatedStorage.HookFuncs
        -- payload.Data: Optional new inventory data
        ClientInventoryService.Reload(payload)
    end,
}

function LoadInitialData()
    local ReturnData = GetStowayFromServer:InvokeServer()
    local uiType : {FolderName: string, GuiName: string, HookPresetName: string} | nil = ReturnData.data.Settings.UiType and Settings.DifferentUIs[ReturnData.data.Settings.UiType]
    
    if not ReturnData.success then return warn(ReturnData.reason) end
    if not uiType then return warn("Cannot load data without the type of ui to show") end
    
    Store.Init(ReturnData.data)

    BuildGui(ReturnData.data.Settings.UiType, uiType.FolderName, uiType.GuiName)
    BuildHooks(uiType.HookPresetName)
    
    -- Wire up NetworkHandler with our handlers (like server pattern)
    
    return true
end

function ClientInventoryService.Init()
    -- 1. Load Data and Build base UI
    LoadInitialData()

    -- 2. Build rest of the UI
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

    DragHandler.Init(DraggingGui, HotbarFrame, BackpackFrame, HookManager, SlotFactory.CloneForGhost)
    BuildHotbar()
    BuildStorage()
    SetUpBinds()
    NetworkHandler.Init(NetworkHandlers)
    
end

ClientInventoryService.Hooks = HookManager

return ClientInventoryService