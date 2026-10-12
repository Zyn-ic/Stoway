--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Client entry LocalScript. Plain (non-init) file so Rojo syncs it as
	a regular child named "Start", sibling of StowayClientV3 — never
	fused with the directory (see init.client.luau removal).
]]

-- WaitForChild: siblings replicate separately, so Start can win the
-- race against the StowayClientV3 module on join. Never index directly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Untyped boundary (intentional): the Conch package ships without Luau
-- declarations, so one any-binding covers the seam.
local conch: any = require(ReplicatedStorage.Packages.conch)

-- Conch console (client half, single owner): Studio only, mirroring the
-- server gate. Without this, net.client.init would hang forever on
-- WaitForChild "conch_networking" (the server never creates remotes).
if game:GetService("RunService"):IsStudio() then
	-- Lifecycle first so the user/handshake never races the mount,
	-- default commands so server logs have somewhere to render,
	-- Backquote to toggle.
	conch.initiate_default_lifecycle()
	conch.register_default_commands()
	conch.ui.bind_to(Enum.KeyCode.Backquote)
end

local StowayClient = require(script.Parent:WaitForChild("StowayClientV3"))

StowayClient.Init()
