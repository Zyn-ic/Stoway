-- InventoryManager.lua (in ServerScriptService)
local InventoryManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local Settings = require(script.Parent.Settings)
local Janitor = require(ReplicatedStorage.Packages.janitor)
-- Global registry of all player inventories
-- When a player joins: add an entry; when they leave: remove it
local serverJanitors = {} :: { Janitor.Janitor }
local serverInventories = {} :: { Player: { Types.PlayerSchema } }

-- Start: hook existing players, then connect to PlayerAdded
function InventoryManager:Start()
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(self.OnPlayerAdded, self, player)
	end

	Players.PlayerAdded:Connect(self.OnPlayerAdded)
	Players.PlayerRemoving:Connect(self.OnPlayerRemoving)

	game:BindToClose(function()
		for _, v: Player in Players:GetChildren() do
			InventoryManager.SaveData(v)
		end
	end)

	--autosaving use profile service
end

-- Default schema generator
local function MakeInventorySchema(carryingType, hotbarSize)
	local schema = {
		Hotbar = table.create(hotbarSize, nil),
		-- Only create Backpack or Inventory if needed
		Backpack = carryingType == "Backpack" and {} or nil,
		Inventory = carryingType == "Inventory" and {} or nil,
	}
	return schema
end

-- Called per-player; loads starter-pack tools into Backpack, builds schema, prints it
function InventoryManager.OnPlayerAdded(player: Player)
	local janitor = Janitor.new()
	serverJanitors[player] = janitor

	--create a stowayData
	serverInventories[player] =
		MakeInventorySchema(Settings.BackpackSettings.CarryingType, Settings.HotbarSettings.MaxSlots)

	local starter = game:GetService("StarterPack")
	for _, tool in starter:GetChildren() do
		while
			not player.Backpack:FindFirstChild(tool.Name)
			and #player.Backpack:GetChildren() < #starter:GetChildren()
		do
			task.wait()
		end
	end

	if not player.Character then
		player.CharacterAdded:Wait()
	end

	InventoryManager.LoadData(player)

	janitor:Add(function()
		if serverInventories[player] then
			serverInventories[player] = nil
		end
	end)
end

function InventoryManager.LoadData(player: Player)
	--data store logic here
end

function InventoryManager.GetTools(backpack: Backpack, character: Model): { Tool }
	local tools = backpack:GetChildren()

	if character then
		for i, tool in character:GetChildren() do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	return tools
end

function InventoryManager.GetValueFromTool(tool: Tool) end

function InventoryManager.GetToolData(Tool: Tool): { Types.ItemData }?
	if not Tool:HasTag("ItemTool") then
		return nil
	end

	local ItemData: Types.ItemData = {
		ID = Tool:GetAttribute("Id") or game:GetService("HttpService"):GenerateGUID(false),
		Description = Tool.ToolTip,
		Image = Tool.TextureId,
		Amount = Tool:GetAttribute("Weight"),
		IsGamepass = Tool:GetAttribute("IsGamepass"),
		Rarity = Tool:GetAttribute("Rarity"),
		Droppable = Tool:GetAttribute("IsDroppable"),
		Type = Tool:GetAttribute("ItemType"),
	}

	return ItemData
end

function InventoryManager.AddNewBackpackItem(Player: Player, tool: Tool)
	local data = serverInventories[Player]

	if InventoryManager.CheckBackpackWeight(Player) > Settings.BackpackSettings.Limit then
		return
	end
	if not data then
		return
	end

	local stash: { Types.ItemData } = (data.Backpack == nil and data.Inventory) or data.Backpack

	local itemdata = InventoryManager.GetToolData(tool)
	if not itemdata then
		return
	end

	for i, v: Types.ItemData in stash do
		if v.Type == tool:GetAttribute("ItemType") then
			if v.Amount > Settings.MaxStackCount then
				v.Amount += 1
			end
		else
			table.insert(stash, itemdata)
		end
	end
end

function InventoryManager.FindFreeHotBarSlot(Player: Player): number?
	local data = serverInventories[Player] :: Types.PlayerSchema
	local hotbar = data.Hotbar

	local freeslot = table.find(hotbar, nil, 1) -- find a nil or empty slot
	return freeslot
end

function InventoryManager.ShiftBackpackDown(startingValue: string?, Player: Player)
	local data = serverInventories[Player] :: Types.PlayerSchema
	local currentinventorynumber = tonumber(startingValue.Name) + 1

	local stash: { Types.ItemData } = (data.Backpack == nil and data.Inventory) or data.Backpack

	while stash[currentinventorynumber] do
		stash[currentinventorynumber - 1].Value = stash[currentinventorynumber].Value
		currentinventorynumber += 1
	end

	stash[currentinventorynumber - 1] = nil
end

-- Swap two slots between any two containers
function InventoryManager.Swap(containerA, idxA, containerB, idxB)
	containerA[idxA], containerB[idxB] = containerB[idxB], containerA[idxA]
end

-- Split a stack from one slot into another
function InventoryManager.Split(container, fromIdx, toIdx, amount)
	local item = container[fromIdx]
	if item and item.Amount >= amount then
		item.Amount -= amount
		container[toIdx] = {
			ID = item.ID,
			Amount = amount,
			IsGamepass = item.IsGamepass,
			Rarity = item.Rarity,
			Droppable = item.Droppable,
			Type = item.Type,
		}
	end
end

function InventoryManager.CheckBackpackWeight(player: Player): number?
	local data = serverInventories[player] :: Types.PlayerSchema
	if not data then
		return nil
	end

	local weightcount = 0

	--add weight from hotbar
	for i, v: Types.ItemData in data.Hotbar do
		weightcount += v.Amount
	end

	--add weight from backpack/inv
	local stash: { Types.ItemData } = (data.Backpack == nil and data.Inventory) or data.Backpack
	for i, v: Types.ItemData in stash do
		weightcount += v.Amount
	end

	return weightcount
end

function InventoryManager.UpdatePlayerTools(Player: Player)
	local playertools = InventoryManager.GetTools(Player.Backpack, Player.Character)
end

function InventoryManager.SaveData(player: Player)
	-- if the user wants to save slot data and backpack data
	if Settings.SaveBackpackandSlotInfo then
		print("data saved")
	end

	-- your own inventory saving mechanizism
end

function InventoryManager.OnPlayerRemoving(player: Player)
	InventoryManager.SaveData(player)

	-- clean memory attached to player
	serverJanitors[player]:Destroy()
	serverJanitors[player] = nil
end

return InventoryManager

--InventoryManager serverside step by step

-- start

--[[
in the start function we need to run the playeradded function for all exsiting players
and bind the playeradded and playerremoving events to our functions and bind the game close
to a function that saves all the player's data for the players still in the game
]]

-- playeradded

--[[
wait until all the tools in starterpack is in the players backpack
wait for the players character, once we have that then
we bind the character added event to a local function that will
register all the tools in the players backpack
then we task.spawn the local function with the players character and bind the function at the end like this:
	task.spawn(charAdded, player.Character)
	janitor:Add(player.CharacterAdded:Connect(charAdded))
	janitor:Add(function() if serverInventories[player] then serverInventories[player] = nil end end)
]]

-- playerremoving

--[[
save the players data then clean up the janitor object
which will run the function with this code : if serverInventories[player] then serverInventories[player] = nil end
which removes all connections to the backpack and the character
then we remove the playe from the global janitor list
]]

-- loaddata

-- save data

-- register tools

--[[
 -- check if its a tool
 -- check if it has the attribute "ItemType"
 -- check if it has the attribture "Registered"
 -- if none of the above then
 
 -- adding it to the hotbar
 -- check if theres a item in the hotbar with the same itemtype
 --- if so then check if we are at max weight/backpack limits
 --- if not then check if the slot already has maxstack
 -- if not at limit or max stack
 -- do some math so we can add the weight value but it not going over the max stack or max limit
 -- example the weight is 5 and we are at 11/15 on weight/max items and the items stackcount is 1/2
 -- then we would add 1 to the slots stack count making it 2/2 and since there are left overs we should
    remove 1 weight from the tool attribute make it 4 now and run the register function recursively so it can
    create/disreguard the tool based on carryingtype
    
-- if there is a tool with the type in the hotbar but at maxstack count or there isnt a tool with that type in the hotbar
-- check if the hotbar is full
-- if so then depending on the carrying type;
-- hotbar carrying type: we need to disreguard any extra tools that dont have a type that is alr in the hotbar
-- backpack carrying type: we need to check the backpack for the same tool type if so then we add stacks to that
   item until we hit the bacpack limit and disreguard the rest or the weight of the tool is 0 example since we 
   now are registering a item with 4 stacks and we are at 12/15 we'll add a item with 1 stack and it
  
]]

-- unregister tools
