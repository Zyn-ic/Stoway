-- src/client/Inventory/Components/SlotFactory.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryController = require(script.Parent.Parent.Operations.InventoryController)
local RarityValues = require(ReplicatedStorage.Shared.RarityValues)
local Settings = require(ReplicatedStorage.Shared.Settings)
local InventoryStore = require(script.Parent.Parent.CoreState.InventoryStore)


local SlotFactory = {}

type SlotProps = {
    SlotIndex: number,
    SlotType: string, -- "Hotbar" | "Storage"
    Parent: Instance,
    KeybindDisplay: string,
    OnDrag: (...any) -> (),
    hookManager: any
}

function CreateSlotFrameName(slotnumber:number): string
    local numberstring = tostring(slotnumber) :: string
    local slotframeName = ""
    local len = numberstring:len()

    if len > 1 then
        for _=1, (len - 1) do
            slotframeName ..= "_"
        end
    end

    slotframeName..= numberstring

    return slotframeName
end

function SlotFactory.Create(Scope: any, props: SlotProps)
    local TemplateFolder = ReplicatedStorage:FindFirstChild("Gui") :: Folder
	local templateSlot = TemplateFolder.Slot.template:Clone()
	templateSlot.Name = CreateSlotFrameName(props.SlotIndex)

	local slotbutton = templateSlot:FindFirstChild("slotbutton") :: ImageButton
	local stackcount = templateSlot:FindFirstChild("stackcount") :: TextLabel
	local slotnumber = templateSlot:FindFirstChild("slotnumber") :: TextLabel
	local selecticon = templateSlot:FindFirstChild("selecticon") :: ImageLabel
	local rarityframe = templateSlot:FindFirstChild("rarityframe") :: Frame

	local scope = Scope:deriveScope()
	table.insert(scope, templateSlot)

	

	--// Computed: Get UUID from this slot's position in state
	local slotUUID = scope:Computed(function(use)
		local hotbarTable = use(InventoryStore.Hotbar) 
		local storageTable = use(InventoryStore.Storage)

		if props.SlotType == "Hotbar" then
			return hotbarTable[props.SlotIndex]
		else
			return storageTable[props.SlotIndex]
		end
	end)
	
	--// Computed: Get item data from the UUID
	local currentItem = scope:Computed(function(use)
		local uuid = use(slotUUID)
		if not uuid then return nil end

		local allItems = use(InventoryStore.Items) 
		return allItems[uuid]
	end)

	--// Computed: Is this slot's item equipped?
	local isEquipped = scope:Computed(function(use)
		local equippedVal = use(InventoryStore.EquippedUUID) 
		local myUUID = use(slotUUID)

		if not equippedVal then return false end
		return equippedVal == myUUID
	end)
	
	--// Computed: Has item (for visibility)
	local hasItem = scope:Computed(function(use)
		return use(currentItem) ~= nil
	end)

	--// Keybind display (static)
	if slotnumber then
		slotnumber.Text = props.KeybindDisplay or ""
		slotnumber.Visible = props.KeybindDisplay ~= nil
	end

	--// Hydrate slotbutton with reactive properties
	if slotbutton then
		scope:Hydrate(slotbutton) {
			Image = scope:Computed(function(use)
				local item = use(currentItem)
				if item and item.Metadata then
					return item.Metadata.Image or ""
				end
				return ""
			end),
			Visible = hasItem,
		}
		
		--[[local dragconnection =]] slotbutton.MouseButton1Down:Connect(function()
			if scope.peek(hasItem) and props.OnDrag then
				templateSlot.ZIndex = 1
				props.OnDrag(props.SlotType, props.SlotIndex, templateSlot, InventoryStore:GetState(), scope)
			end
		end)
		
		--[[local clickconnection =]] slotbutton.MouseButton1Click:Connect(function()
			InventoryController.HandleEquipped(scope.peek(slotUUID))

			if props.hookManager then
				props.hookManager:Fire("OnSlotClick", props.SlotType, props.SlotIndex, scope.peek(slotUUID))
			end
		end)

		-- scope:Hydrate(templateSlot) {
		-- 	Visible = scope:Computed(function(use)
		-- 		if props.SlotType == "Hotbar" then return true end
		-- 		return use(slotUUID) ~= nil
		-- 	end),
		-- }

		-- -- Put the "Executioner" logic in an Observer
		-- if props.SlotType == "Storage" then
		-- 	scope:Observer(slotUUID):onChange(function()
		-- 		if scope.peek(slotUUID) == nil then
		-- 			-- Wait a tiny bit to ensure the Frame hides first
		-- 			task.defer(function()
		-- 				-- Disconnect external connections first
		-- 				if clickconnection then clickconnection:Disconnect() end
		-- 				if dragconnection then dragconnection:Disconnect() end
						
		-- 				-- Now kill the scope and the frame
		-- 				scope:doCleanup()
		-- 				templateSlot:Destroy()
		-- 			end)
		-- 		end
		-- 	end)
		-- end
	
	end

	--// Hydrate stack count
	if stackcount then
		scope:Hydrate(stackcount) {
			Text = scope:Computed(function(use)
				local item = use(currentItem)
				if item and item.Amount > 1 and Settings.Storage.CanStack then
					return item.Amount .. "x"
				end
				return ""
			end),
		}
	end

	--// Hydrate equipped indicator
	if selecticon then
		scope:Hydrate(selecticon) {
			Visible = isEquipped,
		}
		
		--// Observer for equip/unequip hooks
		if props.hookManager then
			scope:Observer(isEquipped):onChange(function()
				local nowEquipped = scope.peek(isEquipped)
				local uuid = scope.peek(slotUUID)
				if nowEquipped and not scope.peek(InventoryStore.EquippedUUID) then
					props.hookManager:Fire("OnEquip", props.SlotType, props.SlotIndex, uuid)
				elseif not nowEquipped and scope.peek(InventoryStore.EquippedUUID) then
					props.hookManager:Fire("OnUnequip", props.SlotType, props.SlotIndex, uuid)
				end
			end)
		end
	end

	--// Hydrate rarity frame
	if rarityframe then
		scope:Hydrate(rarityframe) {
			BackgroundColor3 = scope:Computed(function(use)
				local item = use(currentItem)
				if item and item.Metadata and item.Metadata.Rarity then
					return RarityValues.rarityColors[item.Metadata.Rarity] or Color3.new(0.4, 0.4, 0.4)
				end
				return Color3.new(0.4, 0.4, 0.4)
			end),
			Visible = hasItem,
		}
	end

	templateSlot.Parent = props.Parent
	return templateSlot
end

function SlotFactory.CloneForGhost(originalFrame: Frame): Frame
	local ghost = originalFrame:Clone()
	ghost.Name = "DragGhost"

	--// Hide keybind on ghost
	local slotnumber = ghost:FindFirstChild("slotnumber")
	if slotnumber then
		slotnumber.Visible = false
	end

	--// Ensure all visual components show the current state
	local slotbutton = ghost:FindFirstChild("slotbutton")
	if slotbutton then
		slotbutton.ZIndex = 10
	end

	--// Ghost inherits all visual states (equipped icon, rarity, image, etc.)
	--// No need to modify - the Clone() captures current state

	return ghost
end


return SlotFactory