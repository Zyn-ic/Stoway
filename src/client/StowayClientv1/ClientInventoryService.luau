-- src/client/StowayClientV2/ClientInventoryService.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.fusion)
local scoped = Fusion.scoped
local peek = Fusion.peek

local ClientInventoryService = {}

function ClientInventoryService.Init()
	print("ClientInventoryService Initialized")
end

return ClientInventoryService
