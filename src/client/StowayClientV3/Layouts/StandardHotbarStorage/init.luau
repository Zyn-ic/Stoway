--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StandardHotbarStorage layout. Combines the hotbar and storage views.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Fusion = require(game:GetService("ReplicatedStorage").Packages.fusion)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local PointerDragService = require(script.Parent.Parent.Interactions.PointerDragService)

local HotbarView = require(script.HotbarView)
local StorageView = require(script.StorageView)

local StandardHotbarStorage = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StandardHotbarStorage.Mount(scope: Fusion.Scope<typeof(Fusion)>, skin: CoreTypes.SkinHandle, store: typeof(ClientStore))
	local existingDragging = skin.DraggingGui
		or (skin.Gui and (skin.Gui:FindFirstChild("DraggingGui") :: ScreenGui?))
	local draggingGui: ScreenGui
	if existingDragging then
		existingDragging.IgnoreGuiInset = false
		draggingGui = existingDragging
	else
		local created = Instance.new("ScreenGui")
		created.Name = "DraggingGui"
		created.DisplayOrder = 100
		created.IgnoreGuiInset = false
		created.Parent = skin.Gui and skin.Gui.Parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		table.insert(scope, created)
		draggingGui = created
	end
	local dragService = PointerDragService.new(scope, draggingGui, function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		-- Direct core write, not Signals – Signals are mock RemoteEvents for the 5s smoke test only
		ClientController.Swap(from, to)
	end, skin.SlotTemplate)

	HotbarView.Create(scope, skin, store, dragService)
	StorageView.Create(scope, skin, store, dragService)
end

-----------------------------
-- MAIN --
-----------------------------

return StandardHotbarStorage
