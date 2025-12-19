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

-- Others
local Player = Players.LocalPlayer :: Player   

local InventoryGui = Player.PlayerGui:WaitForChild("StowayGui", 20).Stoway :: ScreenGui
local DraggingGui = Player.PlayerGui:WaitForChild("StowayGui").DraggingGui :: ScreenGui
local BackpackFrame = InventoryGui.Backpack :: Frame
local HotbarFrame = InventoryGui.Hotbar :: Frame
local ScrollingBackpack = BackpackFrame.ScrollingFrame :: ScrollingFrame
local SearchFilter = BackpackFrame.SearchFilter :: TextBox
local WeightLabel = BackpackFrame.Weight :: TextLabel


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
			InventoryController.HandleEquipped(Store:GetUUidFromIndex(i, "Hotbar"))
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

local HotbarScope = nil

function BuildHotbar()
	if HotbarScope then
		HotbarScope:doCleanup()
		HotbarScope = nil
	end

    HotbarScope = Store.Scope:deriveScope()
    for i = 1, 9 do
        SlotFactory.Create(HotbarScope, {
            SlotIndex = i,
            SlotType = "Hotbar",
            Parent = HotbarFrame,
            KeybindDisplay = GetKeybindDisplay(i),
            OnDrag = DragHandler.StartDrag, -- Hook up drag handler here
            hookManager = HookManager
        })
    end
end

function ClientInventoryService.ReloadHotbar()
	BuildHotbar()
end

function BuildStorage()
    local StorageScope = Store.Scope:deriveScope()

    -- 1. Create a Search Value
    local SearchText = StorageScope:Value("")
    if SearchFilter then
        SearchFilter:GetPropertyChangedSignal("Text"):Connect(function()
            SearchText:set(SearchFilter.Text:lower())
        end)
    end

	if WeightLabel then
		StorageScope:Hydrate(WeightLabel) {
			Text = StorageScope:Computed(function(use)
				local weight = use(Store.Weight)
				local settings = use(Store.Settings)
				if settings and settings.Limit and settings.Limit > 0 then
					return weight .. "/" .. settings.Limit
				else
					return weight .. "/∞"
				end
			end),
		}
	end

    -- 2. Master Sort Calculation (Runs once per update)
    -- This creates a lookup table: {[OriginalIndex] = Rank}
    local SortLookup = StorageScope:Computed(function(use)
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

    -- 3. Static Slot Creation
    -- We track raw Storage so slots are only created/deleted on Add/Remove
    StorageScope:ForPairs(Store.Storage, function(_use, scope, storageIndex, uuid)
        
        local slotFrame = SlotFactory.Create(scope, {
            SlotIndex = storageIndex,
            SlotType = "Storage",
            Parent = ScrollingBackpack,
			KeybindDisplay = nil,
            OnDrag = DragHandler.StartDrag,
            hookManager = HookManager
        })

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

        return storageIndex, slotFrame
    end)
end

function LoadInitialData()
    local ReturnData = GetStowayFromServer:InvokeServer()
    if not ReturnData.success then return warn(ReturnData.reason) end
    
    Store.Init(ReturnData.data)
    NetworkHandler.Init() -- Start listening for corrections
    return
end

function ClientInventoryService.Init()
    -- 1. Load Data
    LoadInitialData()

    -- 2. Build UI
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    DragHandler.Init(DraggingGui, HotbarFrame, BackpackFrame, HookManager, SlotFactory.CloneForGhost)
    BuildHotbar()
    BuildStorage()
    SetUpBinds()
    
end

ClientInventoryService.Hooks = HookManager

return ClientInventoryService