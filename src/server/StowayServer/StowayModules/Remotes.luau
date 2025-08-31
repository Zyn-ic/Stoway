-- src/server/StowayServer/stowayserver_modules/Remotes.lua
local Remotes = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

-- Dependencies
local API
local PlayerStoways
local Utils

function Remotes.OnAskForStoway(player:Player, arg:string)
	if player.Parent == nil or not player then return end
	if typeof(arg) ~= "string" then return nil end

	if arg == "stoway" then
		return API.GetStoway(player)
	elseif arg == "settings" then
		return API.GetSettings(player)
	end

	return nil
end

function Remotes.OnUnEquip(Player:Player)
	local character = Player.Character or Player.CharacterAdded:Wait()
	if not character then return end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool then return end
	tool.Parent = Player.Backpack
end

function Remotes.OnEquipTool(Player:Player, Tool:Tool)
	local character = Player.Character or Player.CharacterAdded:Wait()
	if not character then return end
	if not Tool or not Utils.ValidateTool(Player, Tool) or Tool.Parent == character then return end

	Remotes.OnUnEquip(Player)
	local primarytool = Tool.PrimaryPart or Tool:FindFirstChild("Handle")
	if primarytool and character.PrimaryPart then
		primarytool:PivotTo(character.PrimaryPart.CFrame)
	end
	Tool.Parent = Player.Character
end

function Remotes.OnDropTool(Player:Player, Tool:Tool)
	if not Utils.ValidateTool(Player, Tool) then return end
	local PlayerStowy = PlayerStoways[Player]
	local slot = Utils.FindValueFromTool(Tool, Player)
	if not slot then return end

	if PlayerStowy.Settings.Droppable then
		local canDrop = Tool:GetAttribute("IsDroppable")
		if Tool:GetAttribute("IsGamepass") == true then canDrop = false end
		if not canDrop then return end
	else
		return
	end

	local character = Player.Character or Player.CharacterAdded:Wait()
	local root = character.PrimaryPart
	if not root then return end

	local rootCframe = root.CFrame
	local positionOffset = (rootCframe.LookVector * Vector3.new(1, 0, 1)) * PlayerStowy.Settings.DropToolDistance
	local ToolCframe = rootCframe + positionOffset
	local handle = Tool:FindFirstChild("Handle") or Tool.PrimaryPart
	if handle then handle.CFrame = ToolCframe end
	Tool.Parent = workspace
end

function Remotes.Init(context:Types.Context)
	API = context.API
	PlayerStoways = context.PlayerStoways
	Utils = context.Utils
end

return Remotes