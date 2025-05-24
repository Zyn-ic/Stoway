-- ServerScriptService/Stoway/StowayServer.lua
local StowayServer = {}

-- Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local Settings = require(script.Parent.Settings) -- Assuming Settings.lua is in the same folder
local Janitor = require(ReplicatedStorage.Packages.janitor) -- Verify path

-- In-memory storage
local serverJanitors: { [Player]: Janitor.Janitor } = {}
local serverInventories: { [Player]: Types.PlayerSchema } = {}
